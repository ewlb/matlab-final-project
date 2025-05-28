function [thresh, metric] = multithresh(varargin) %#codegen
%

%   Copyright 2014-2024 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(1,2);

[A, N] = parse_inputs(varargin{:});

thresh = coder.nullcopy(zeros(1, N, 'like', A));

if (isempty(A))
    coder.internal.warning('images:multithresh:degenerateInput',N);
    threshout = getDegenerateThresholds(A(:)', N);
    metric = 0.0;
    for i = 1:N
        thresh(i) = threshout(i);
    end
    return;
end

coder.extrinsic('images.internal.coder.useOptimizedFunctions');

num_bins = 256;

useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() && ...
    coder.const(~images.internal.coder.useSingleThread());

if (coder.const(images.internal.coder.useOptimizedFunctions()) && ~useSharedLibrary)
    [p, minA, maxA, emptyp] = getpdfOptimized(A, num_bins);
else
    [p, minA, maxA, emptyp] = getpdf(A, num_bins);
end

if (emptyp)
    % Input image pdf could not be computed
    coder.internal.warning('images:multithresh:degenerateInput',N);
    threshout = getThreshForNoPdf(minA, maxA, N);
    for i = 1:N
        thresh(i) = threshout(i);
    end
    metric = 0.0;
    return;
end

% Variables are named similar to the formulae in Otsu's paper.
omega    = cumsum(p);
mu       = cumsum(p .* (1:num_bins)');
mu_t     = mu(end);

if (N < 3)

    sigma_b_squared = calcFullObjCriteriaMatrix(N, num_bins, omega, mu, mu_t);

    % Find the location of the maximum value of sigma_b_squared.
    if coder.isColumnMajor
        maxval = max(sigma_b_squared(:));
    else % Row-major
        maxval = max(max(sigma_b_squared,[],2),[],1);
    end
    isvalid_maxval = isfinite(maxval);

    if isvalid_maxval
        % Find the bin with maximum value. If the maximum extends over
        % several bins, average together the locations.
        if(N==1)
            % idx = find(sigma_b_squared == maxval);
            idxSum = 0;
            idxNum = 0;
            if coder.isColumnMajor
                for ind = 1:numel(sigma_b_squared)
                    if(sigma_b_squared(ind)==maxval)
                        idxSum = idxSum+ind;
                        idxNum = idxNum+1;
                    end
                end
            else % Row-major
                for i = 1:size(sigma_b_squared,1)
                    for j = 1:size(sigma_b_squared,2)
                        if(sigma_b_squared(i,j) == maxval)
                            ind = sub2ind(size(sigma_b_squared),i,j);
                            idxSum = idxSum+ind;
                            idxNum = idxNum+1;
                        end
                    end
                end
            end

            % Find the intensity associated with the bin
            % threshRaw = mean(idx) - 1;
            threshRaw = idxSum/idxNum - 1;
        else %N==2
            [maxR, maxC] = find(sigma_b_squared == maxval);
            % Find the intensity associated with the bin
            threshRaw = mean([maxR maxC],1) - 1;
        end
    else
        [isDegenerate, uniqueVals] = checkForDegenerateInput(A, N);
        if isDegenerate
            coder.internal.warning('images:multithresh:degenerateInput',N);
        else
            coder.internal.warning('images:multithresh:noConvergence');
        end
        threshRaw = double(getDegenerateThresholds(uniqueVals, N));
        metric = 0.0;
    end

else

    % For N >= 3, use search-based optimization of Otsu's objective function

    % Set initial thresholds as uniformly spaced
    initial_thresh = linspace(0, num_bins-1, N+2);
    initial_thresh = initial_thresh(2:end-1); % Retain N thresholds

    % Set optimization parameters
    options = optimset('TolX',1,'Display','off');
    objCriteriaNDParameters(num_bins, omega, mu, mu_t);

    % Find optimum using fminsearch
    [threshRaw, minval] = fminsearch(...
        @(thresh)objCriteriaND(thresh),...
        initial_thresh, options);

    maxval = -minval;

    isvalid_maxval = ~(isinf(maxval) || isnan(maxval));
    if isvalid_maxval
        threshRaw = round(threshRaw);
    end

end

% Prepare output values
if isvalid_maxval

    % Map back to original scale as input A
    threshout = map2OriginalScale(threshRaw, minA, maxA);
    if nargout > 1
        % Compute the effectiveness metric
        metric = maxval/(sum(p.*(((1:num_bins)' - mu_t).^2)));
    end

else

    [isDegenerate, uniqueVals] = checkForDegenerateInput(A, N);
    if isDegenerate
        coder.internal.warning('images:multithresh:degenerateInput',N);
        threshout = getDegenerateThresholds(uniqueVals, N);
        metric = 0.0;
    else
        coder.internal.warning('images:multithresh:noConvergence');
        % Return latest available solution
        threshout = map2OriginalScale(threshRaw, minA, maxA);
        if nargout > 1
            % Compute the effectiveness metric
            metric = maxval/(sum(p.*(((1:num_bins)' - mu_t).^2)));
        end
    end

end

for i = 1:N
    thresh(i) = threshout(i);
end

end

%--------------------------------------------------------------------------

function [A, N] = parse_inputs(varargin)
coder.inline('always');
A = varargin{1};
validateattributes(A,{'uint8','uint16','int16','double','single'}, ...
    {'nonsparse', 'real'}, mfilename,'A',1);

if (nargin == 2)
    validateattributes(varargin{2},{'numeric'},{'integer','scalar','positive','<=',20}, ...
        mfilename,'N',2);
    N = double(varargin{2});
else
    N = 1; % Default N
end
end

%--------------------------------------------------------------------------

function [p, minA, maxA, emptyp] = getpdfOptimized(A,num_bins)
coder.inline('always');
% Vectorize A for faster histogram computation
emptyp = true;

% Ensure p is not varsize
p = coder.nullcopy(zeros(num_bins,1));
isFiniteImage = isinteger(A);
Ascaled = zeros(size(A),'uint8');
nanCount = 0;
N   = numel(A);

% Threshold for using openmp
threshInteger = 500000;
threshFloat = 50000;
useParfor = false;
if (isFiniteImage && threshInteger < N) || (~isFiniteImage && threshFloat < N)
    useParfor = true;
end
coder.internal.prefer_const(useParfor);
if coder.isColumnMajor || (coder.isRowMajor && numel(size(A))>3)
    if isFiniteImage

        % Integer images 2D or 3D column major
        idx = ones(coder.internal.indexIntClass());
        minA = A(idx);
        maxA = A(idx);
        if useParfor
            parfor index = idx+1:N
                a = A(index);
                minA = min(a,minA);
                maxA = max(a,maxA);
            end
        else
            for k = idx+1:N
                a = A(k);
                minA = min(a,minA);
                maxA = max(a,maxA);
            end
        end
        if (minA == maxA)
            return;
        end
        difference = single(maxA) - single(minA);
        minATemp = single(minA);
        if useParfor
            parfor k=1:N
                Ascaled(k) = im2uint8((single(A(k)) - minATemp)/difference);
            end
        else
            for k=1:N
                Ascaled(k) = im2uint8((single(A(k)) - minATemp)/difference);
            end
        end
    else

        % Floating point images 2D or 3D column major
        idx = ones(coder.internal.indexIntClass());
        minA = cast(coder.internal.inf,'like',A);
        maxA = cast(-coder.internal.inf,'like',A);
        if useParfor
            parfor k = idx:N
                a = A(k);
                if isfinite(a)
                    minA = min(a,minA);
                    maxA = max(a,maxA);
                else
                    if isnan(a)
                        nanCount = nanCount + 1;
                    end
                end
            end
        else
            for k = idx:N
                a = A(k);
                if isfinite(a)
                    minA = min(a,minA);
                    maxA = max(a,maxA);
                else
                    if isnan(a)
                        nanCount = nanCount + 1;
                    end
                end
            end
        end

        if (minA == maxA)
            return;
        end

        if ~isfinite(minA) % only non-finites, edge case.
            minA = min(A(:));
            maxA = max(A(:));
            return;
        end

        difference = (maxA - minA);
        if useParfor
            parfor k=1:N
                Ascaled(k) = im2uint8((A(k) - minA)/difference);
            end
        else
            for k=1:N
                Ascaled(k) = im2uint8((A(k) - minA)/difference);
            end
        end
    end

else % Row-major 2-D and 3-D only
    if numel(size(A)) == 2
        if isFiniteImage

            % Integer images 2D row-major
            idx = ones(coder.internal.indexIntClass());
            minA = A(idx);
            maxA = A(idx);
            if useParfor
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        a = A(dim1,dim2);
                        minA = min(a,minA);
                        maxA = max(a,maxA);
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        a = A(dim1,dim2);
                        minA = min(a,minA);
                        maxA = max(a,maxA);
                    end
                end
            end
            if (minA == maxA)
                return;
            end
            difference = single(maxA) - single(minA);
            minATemp = single(minA);
            if useParfor
                Asize2 = size(A,2);
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:Asize2
                        Ascaled(dim1,dim2) = im2uint8((single(A(dim1,dim2)) - minATemp)/difference);
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        Ascaled(dim1,dim2) = im2uint8((single(A(dim1,dim2)) - minATemp)/difference);
                    end
                end
            end
        else

            % Floating point image 2D row-major
            minA = cast(coder.internal.inf,'like',A);
            maxA = cast(-coder.internal.inf,'like',A);
            if useParfor
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        a = A(dim1,dim2);
                        if isfinite(a)
                            minA = min(a,minA);
                            maxA = max(a,maxA);
                        else
                            if isnan(a)
                                nanCount = nanCount + 1;
                            end
                        end
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        a = A(dim1,dim2);
                        if isfinite(a)
                            minA = min(a,minA);
                            maxA = max(a,maxA);
                        else
                            if isnan(a)
                                nanCount = nanCount + 1;
                            end
                        end
                    end
                end
            end

            if (minA == maxA)
                return;
            end

            if ~isfinite(minA) % only non-finites, edge case.
                minA = min(A(:));
                maxA = max(A(:));
                return;
            end

            difference = (maxA - minA);
            if useParfor
                Asize2 = size(A,2);
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:Asize2
                        Ascaled(dim1,dim2) = im2uint8((A(dim1,dim2) - minA)/difference);
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        Ascaled(dim1,dim2) = im2uint8((A(dim1,dim2) - minA)/difference);
                    end
                end
            end
         end
    else % Row Major 3-D
        if isFiniteImage

	    % Integer image 3D row-major
            idx = ones(coder.internal.indexIntClass());
            minA = A(idx);
            maxA = A(idx);
            if useParfor
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        for dim3 = 1:size(A,3)
                            a = A(dim1,dim2,dim3);
                            minA = min(a,minA);
                            maxA = max(a,maxA);
                        end
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        for dim3 = 1:size(A,3)
                            a = A(dim1,dim2,dim3);
                            minA = min(a,minA);
                            maxA = max(a,maxA);
                        end
                    end
                end
            end
            if (minA == maxA)
                return;
            end
            difference = single(maxA) - single(minA);
            minATemp = single(minA);
            if useParfor
                Asize2 = size(A,2);
                Asize3 = size(A,3);
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:Asize2
                        for dim3 = 1:Asize3
                            Ascaled(dim1,dim2,dim3) = im2uint8((single(A(dim1,dim2,dim3)) - minATemp)/difference);
                        end
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        for dim3 = 1:size(A,3)
                            Ascaled(dim1,dim2,dim3) = im2uint8((single(A(dim1,dim2,dim3)) - minATemp)/difference);
                        end
                    end
                end
            end
        else

            % Floating point image 3D row-major
            minA = cast(coder.internal.inf,'like',A);
            maxA = cast(-coder.internal.inf,'like',A);
            if useParfor
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        for dim3 = 1:size(A,3)
                            a = A(dim1,dim2,dim3);
                            if isfinite(a)
                                minA = min(a,minA);
                                maxA = max(a,maxA);
                            else
                                if isnan(a)
                                    nanCount = nanCount + 1;
                                end
                            end
                        end
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        for dim3 = 1:size(A,3)
                            a = A(dim1,dim2,dim3);
                            if isfinite(a)
                                minA = min(a,minA);
                                maxA = max(a,maxA);
                            else
                                if isnan(a)
                                    nanCount = nanCount + 1;
                                end
                            end
                        end
                    end
                end
            end

            if (minA == maxA)
                return;
            end

            if ~isfinite(minA) % only non-finites, edge case.
                minA = min(A(:));
                maxA = max(A(:));
                return;
            end

            difference = (maxA - minA);
            if useParfor
                Asize2 = size(A,2);
                Asize3 = size(A,3);
                parfor dim1 = 1:size(A,1)
                    for dim2 = 1:Asize2
                        for dim3 = 1:Asize3
                            Ascaled(dim1,dim2,dim3) = im2uint8((A(dim1,dim2,dim3) - minA)/difference);
                        end
                    end
                end
            else
                for dim1 = 1:size(A,1)
                    for dim2 = 1:size(A,2)
                        for dim3 = 1:size(A,3)
                            Ascaled(dim1,dim2,dim3) = im2uint8((A(dim1,dim2,dim3) - minA)/difference);
                        end
                    end
                end
            end
        end
    end
end

counts = imhist(Ascaled,num_bins);

if (~isFiniteImage)
    counts(1) = counts(1) - nanCount; % subtract the number of nan's in image
    p      = counts / (N - nanCount);
else
    p      = counts / N;
end
emptyp = false;
end

%--------------------------------------------------------------------------

function [p, minA, maxA, emptyp] = getpdf(A,num_bins)
coder.inline('always');
% Vectorize A for faster histogram computation
emptyp = true;

% Ensure p is not varsize
p = coder.nullcopy(zeros(num_bins,1));
isIntegerImage = isinteger(A);
if coder.isColumnMajor || (coder.isRowMajor && numel(size(A))>3)
    idx = ones(coder.internal.indexIntClass());
    N   = numel(A);
    if (~isIntegerImage)
    while idx <= N && ~isfinite(A(idx))
        % find first finite, if any
        idx = idx+1;
    end
    end
    if idx <= N % finites exist
        minA = A(idx);
        maxA = A(idx);
        for k = idx+1:N
            a = A(k);
            if a < minA && isfinite(a)
                minA = a;
            elseif a > maxA && isfinite(a)
                maxA = a;
            end
        end

        if(minA == maxA)
            return;
        end
        if isIntegerImage
            A = (single(A) - single(minA))/(single(maxA) - single(minA));
        else
            A = (A - minA)/(maxA - minA);
        end
    else % only non-finites, edge case.
        minA = min(A(:));
        maxA = max(A(:));
        return;
    end

    % Remove NaNs from consideration.
    % A(isnan(A)) = [];
    A       = A(:);
    if (~isIntegerImage)
    nans    = isnan(A);
    Anonnan = A(~nans);
    else
        Anonnan = A;
    end
else % Row-major 2-D and 3-D only
    idx = coder.internal.indexInt(1);
    N   = numel(A);
    earlyExit = false;

    if numel(size(A)) == 2
        % Find first finite, if any
        if(~isIntegerImage)
        for dim1 = 1:size(A,1)
            for dim2 = 1:size(A,2)
                if idx <= N && ~isfinite(A(dim1,dim2))
                    idx = coder.internal.indexPlus(idx,1);
                else
                    earlyExit = true;
                    break;
                end
            end
            if earlyExit
                break;
            end
        end
        end
        % Finites exist
        if idx <= N
            [dimA1,dimA2] = ind2sub(size(A),idx);
            minA = A(dimA1,dimA2);
            maxA = A(dimA1,dimA2);
            if idx+1 <= N
                for dim1 = dimA1:size(A,1)
                    for dim2 = dimA2:size(A,2)
                        a = A(dim1,dim2);
                        if a < minA && isfinite(a)
                            minA = a;
                        elseif a > maxA && isfinite(a)
                            maxA = a;
                        end
                    end
                end
            end

            if(minA == maxA)
                return;
            end
            if isIntegerImage
                A = (single(A) - single(minA))/(single(maxA) - single(minA));
            else
                A = (A - minA)/(maxA - minA);
            end
        else % only non-finites, edge case.
            minA = min(A(:));
            maxA = max(A(:));
            return;
        end

        % Remove NaNs from consideration.
        % A(isnan(A)) = [];

        % Assign non-NaNs from A to Anonnan
        coder.varsize('Anonnan',[],[0 1]);
        Anonnan = coder.nullcopy(zeros(1,numel(A),'like',A));
        idx = coder.internal.indexInt(0);
        for dim1 = 1:size(A,1)
            for dim2 = 1:size(A,2)
                if ~isnan(A(dim1,dim2))
                    idx = coder.internal.indexPlus(idx,1);
                    Anonnan(idx) = A(dim1,dim2);
                end
            end
        end

        % Remove unassigned entries from the end of Anonnan vector
        if(~isIntegerImage)
        for idxR = numel(A):-1:coder.internal.indexPlus(idx,1)
            Anonnan(idxR) = [];
        end
        end
    else % 3-D

        % Find first finite, if any
        if(~isIntegerImage)
        for dim1 = 1:size(A,1)
            for dim2 = 1:size(A,2)
                for dim3 = 1:size(A,3)
                    if idx <= N && ~isfinite(A(dim1,dim2,dim3))
                        idx = coder.internal.indexPlus(idx,1);
                    else
                        earlyExit = true;
                        break;
                    end
                end
                if earlyExit
                    break;
                end
            end
            if earlyExit
                break;
            end
        end
        end

        % Finites exist
        if idx <= N
            [dimA1,dimA2,dimA3] = ind2sub(size(A),idx);
            minA = A(dimA1,dimA2,dimA3);
            maxA = A(dimA1,dimA2,dimA3);

            if idx+1 <= N
                [dimA1,dimA2,dimA3] = ind2sub(size(A),coder.internal.indexPlus(idx,1));
                for dim1 = dimA1:size(A,1)
                    for dim2 = dimA2:size(A,2)
                        for dim3 = dimA3:size(A,3)
                            a = A(dim1,dim2,dim3);
                            if a < minA && isfinite(a)
                                minA = a;
                            elseif a > maxA && isfinite(a)
                                maxA = a;
                            end
                        end
                    end
                end
            end

            if(minA == maxA)
                return;
            end
            if isIntegerImage
                A = (single(A) - single(minA))/(single(maxA) - single(minA));
            else
                A = (A - minA)/(maxA - minA);
            end
        else % only non-finites, edge case.
            minA = min(A(:));
            maxA = max(A(:));
            return;
        end

        % Remove NaNs from consideration.
        % A(isnan(A)) = [];

        % Assign non-NaNs from A to Anonnan
        coder.varsize('Anonnan',[],[0 1]);
        Anonnan = coder.nullcopy(zeros(1,numel(A),'like',A));
        idx = coder.internal.indexInt(0);
        for dim1 = 1:size(A,1)
            for dim2 = 1:size(A,2)
                for dim3 = 1:size(A,3)
                    if ~isnan(A(dim1,dim2,dim3))
                        idx = coder.internal.indexPlus(idx,1);
                        Anonnan(idx) = A(dim1,dim2,dim3);
                    end
                end
            end
        end

        % Remove unassigned entries from the end of Anonnan vector
        if (~isIntegerImage)
        for idxR = numel(A):-1:coder.internal.indexPlus(idx,1)
            Anonnan(idxR) = [];
        end
        end
    end
end

if(~isempty(Anonnan))
    % Convert to uint8 for fastest histogram computation.
    Auint8      = im2uint8(Anonnan);
    counts = imhist(Auint8,num_bins);
    if (~isIntegerImage)
    p      = counts / sum(counts);
    else
        p      = counts / N;
    end
    emptyp = false;
end

end

%--------------------------------------------------------------------------

function sigma_b_squared_val = objCriteriaND(thresh) %, num_bins, omega, mu, mu_t)
coder.inline('always');
% Obtain parameters
[num_bins, omega, mu, mu_t] = objCriteriaNDParameters();

% 'thresh' has intensities [0-255], but 'boundaries' are the indices [1
% 256].
boundaries = round(thresh)+1;

% Constrain 'boundaries' to:
% 1. be strictly increasing,
% 2. have the lowest value > 1 (i.e. minimum 2),
% 3. have highest value < num_bins (i.e. maximum num_bins-1).
if (~all(diff([1 boundaries num_bins]) > 0))
    sigma_b_squared_val = Inf;
    return;
end

boundaries = [boundaries num_bins];

sigma_b_squared_val = omega(boundaries(1)).*((mu(boundaries(1))./omega(boundaries(1)) - mu_t).^2);

for kk = 2:length(boundaries)
    omegaKK = omega(boundaries(kk)) - omega(boundaries(kk-1));
    muKK = (mu(boundaries(kk)) - mu(boundaries(kk-1)))/omegaKK;
    sigma_b_squared_val = sigma_b_squared_val + (omegaKK.*((muKK - mu_t).^2)); % Eqn. 14 in Otsu's paper
end

if (isfinite(sigma_b_squared_val))
    sigma_b_squared_val = -sigma_b_squared_val; % To do maximization using fminsearch.
else
    sigma_b_squared_val = Inf;
end
end


function [num_bins, omega, mu, mu_t] = objCriteriaNDParameters(num_bins, omega, mu, mu_t)
% Hold parameters required for fminsearch
coder.inline('always');
persistent num_bins_p omega_p mu_p mu_t_p;

% initialize
if(isempty(num_bins_p))
    num_bins_p = 0;
end
if(isempty(omega_p))
    omega_p    = 0;
end
if(isempty(mu_p))
    mu_p       = 0;
end
if(isempty(mu_t_p))
    mu_t_p     = 0;
end

if(nargin>0)
    % Assume set call
    num_bins_p = num_bins;
    omega_p    = omega;
    mu_p       = mu;
    mu_t_p     = mu_t;
end

num_bins = num_bins_p;
omega    = omega_p;
mu       = mu_p;
mu_t     = mu_t_p;

end

%--------------------------------------------------------------------------

function sigma_b_squared = calcFullObjCriteriaMatrix(N, num_bins, omega, mu, mu_t)
coder.inline('always');
if (N == 1)

    sigma_b_squared = (mu_t * omega - mu).^2 ./ (omega .* (1 - omega));

else  %(N == 2)

    % Rows represent thresh(1) (lower threshold) and columns represent
    % thresh(2) (higher threshold).
    omega0 = repmat(omega,1,num_bins);
    mu_0_t = repmat(bsxfun(@minus,mu_t,mu./omega),1,num_bins);
    omega1 = bsxfun(@minus, omega.', omega);
    mu_1_t = bsxfun(@minus,mu_t,(bsxfun(@minus, mu.', mu))./omega1);

    % Set entries corresponding to non-viable solutions to NaN
    [allPixR, allPixC] = ndgrid(1:num_bins,1:num_bins);
    pixNaN = allPixR >= allPixC; % Enforce thresh(1) < thresh(2)

    if coder.isColumnMajor()
        omega0(pixNaN) = coder.internal.nan(1);
        omega1(pixNaN) = coder.internal.nan(1);
    else % Row-major
        for i = 1:size(pixNaN,1)
            for j = 1:size(pixNaN,2)
                if pixNaN(i,j)
                    omega0(i,j) = coder.internal.nan(1);
                    omega1(i,j) = coder.internal.nan(1);
                end
            end
        end
    end

    term1 = omega0.*(mu_0_t.^2);

    term2 = omega1.*(mu_1_t.^2);

    omega2 = 1 - (omega0+omega1);

    if coder.isColumnMajor
        omega2(omega2 <= 0) = coder.internal.nan(1); % Avoid divide-by-zero Infs in term3
    else % Row-major
        % Avoid divide-by-zero Infs in term3
        for i = 1:size(omega2,1)
            for j = 1:size(omega2,2)
                if omega2(i,j) <= 0
                    omega2(i,j) = coder.internal.nan(1);
                end
            end
        end
    end

    term3 = ((omega0.*mu_0_t + omega1.*mu_1_t ).^2)./omega2;

    sigma_b_squared = term1 + term2 + term3;
end
end

%--------------------------------------------------------------------------

function sclThresh = map2OriginalScale(thresh, minA, maxA)
coder.inline('always');
normFactor = 255;
sclThresh = double(minA) + thresh/normFactor*(double(maxA) - double(minA));
sclThresh = cast(sclThresh, 'like', minA);

end

%--------------------------------------------------------------------------
function [isDegenerate, uniqueVals] = checkForDegenerateInput(A, N)
coder.inline('always');
if coder.isColumnMajor || (coder.isRowMajor && numel(size(A))>3)
    uniqueVals = unique(A(:))'; % Note: 'uniqueVals' is returned in sorted order.

    % Ignore NaNs because they are ignored in computation. Ignore Infs because
    % Infs are mapped to extreme bins during histogram computation and are
    % therefore not unique values.
    uniqueVals(isinf(uniqueVals) | isnan(uniqueVals)) = [];

    isDegenerate = (numel(uniqueVals) <= N);
else % Row-Major 2-D and 3-D only
    % Vectorize A (i.e. Avec)
    Avec = coder.nullcopy(zeros(1,numel(A),'like',A));
    idx = coder.internal.indexInt(1);
    if numel(size(A)) == 2
        for dim1 = 1:size(A,1)
            for dim2 = 1:size(A,2)
                Avec(idx) = A(dim1,dim2);
                idx = coder.internal.indexPlus(idx,1);
            end
        end
    else % numel(size(A)) == 3
        for dim1 = 1:size(A,1)
            for dim2 = 1:size(A,2)
                for dim3 = 1:size(A,3)
                    Avec(idx) = A(dim1,dim2,dim3);
                    idx = coder.internal.indexPlus(idx,1);
                end
            end
        end
    end

    coder.varsize('uniqueVals',[],[0 1]);
    uniqueVals = unique(Avec);

    % Ignore NaNs because they are ignored in computation. Ignore Infs because
    % Infs are mapped to extreme bins during histogram computation and are
    % therefore not unique values.
    for idx = numel(uniqueVals):-1:1
        if (isinf(uniqueVals(idx)) || isnan(uniqueVals(idx)))
            uniqueVals(idx) = [];
        end
    end

    countUniqueVals = numel(uniqueVals);
    isDegenerate = (countUniqueVals <= N);
end

end

%--------------------------------------------------------------------------
function thresh = getThreshForNoPdf(minA, maxA, N)
coder.inline('always');
if isnan(minA)
    % If minA = NaN => maxA = NaN. All NaN input condition.
    minA = ones(1,1,'like', minA);
    maxA = ones(1,1,'like', maxA);
end

if (N == 1)
    thresh = minA;
else
    if (minA == maxA)
        % Flat image, i.e. only one unique value (not counting Infs and
        % -Infs) exists
        thresh = getDegenerateThresholds(minA, N);
    else
        % Only scenario: A full of Infs and -Infs => minA = -Inf and maxA =
        % Inf
        thresh = getDegenerateThresholds([minA maxA], N);
    end
end

end

%--------------------------------------------------------------------------
function thresh = getDegenerateThresholds(uniqueVals, N)
% Notes:
% 1) 'uniqueVals' must be in sorted (ascending) order
% 2) For predictable behavior, 'uniqueVals' should not have NaNs
% 3) For predictable behavior for all datatypes including uint8, N must be < 255

coder.inline('always');

if isempty(uniqueVals)
    thresh = cast(1:N,'like', uniqueVals);
    return;
end

thNeeded1 = N - numel(uniqueVals);
if (thNeeded1 > 0)

    % More values are needed to fill 'thresh'. Start filling 'thresh' from
    % the lower end starting with 1.

    if (uniqueVals(1) > 1)
        % If uniqueVals(1) > 1, we can directly fill some (or maybe all)
        % values starting from 1, without checking for uniqueness.
        threshL = [cast(1:min(thNeeded1,ceil(uniqueVals(1))-1), 'like', uniqueVals)...
            uniqueVals];
    else
        threshL = uniqueVals;
    end

    thNeeded2 = N - numel(threshL);
    if (thNeeded2  > 0)

        % More values are needed to fill 'thresh'. Use positive integer
        % values, as small as possible, which are not in 'thresh' already.
        lenThreshOrig = length(threshL);
        thresh = [threshL zeros(1,thNeeded2)]; % Create empty entries, thresh datatype preserved
        uniqueVals_d = double(uniqueVals); % Needed to convert to double for correct uniqueness check
        threshCandidate = max(floor(uniqueVals(1)),0); % Always non-negative, threshCandidate datatype preserved
        q = 1;
        while q <= thNeeded2
            threshCandidate = threshCandidate + 1;
            threshCandidate_d = double(threshCandidate); % Needed to convert to double for correct uniqueness check
            if any(abs(uniqueVals_d(:) - threshCandidate_d(:)) ...
                    < eps(threshCandidate_d(:)))
                % The candidate value already exists, so don't use it.
                continue;
            else
                thresh(lenThreshOrig + q) = threshCandidate; % Append at the end
                q = q + 1;
            end
        end

        thresh = sort(thresh); % Arrange 'thresh' in ascending order
    else
        thresh = threshL;
    end

else
    % 'thresh' will always have all the elements of 'uniqueVals' in it.
    thresh = uniqueVals;
end

end
