function B = morphopAlgo(A, nhood_ , height, op_type, B) %#codegen
%

%   Copyright 2014-2020 The MathWorks, Inc.

op_type = coder.const(op_type);

if(isempty(A))
    return;
end

if(isfloat(A))
    minVal = -inf('like',A);
    maxVal =  inf('like',A);
elseif(islogical(A))
    minVal = false;
    maxVal = true;
else % integer
    minVal = intmin(class(A));
    maxVal = intmax(class(A));
end

%% Edge case - handle empty nhoods
if(isempty(nhood_))
    switch(op_type)
        case 'dilate'
            val = minVal;
        case 'erode'
            val = maxVal;
        otherwise
            assert(false, 'Unknown operation');
    end
    for lind = 1:numel(A)
        B(lind) = val;
    end
    return;
end

%%  Use sum of pixel in sliding window if conditions allow
coder.extrinsic('images.internal.coder.useOptimizedFunctions');
% Use sliding window to calculate min/max for the following conditions:
% 1. Image's smaller dimension is larger than strel's larger dimension (to prevent the need for padding, for better performance)
% 2. Strel is flat (heights are 0)
% 3. If strel is a row/column of "true", handle logical 2D image
% 4. If strel is a row/column of "true", handle numeric 2D image if strel length >= 11 (performance threshold)
% 5. if strel is a diagonal of "true", handle logical 2D image if strel lenght >= 5 (performance threshold)
if(coder.const(images.internal.coder.useOptimizedFunctions()) && min(size(A))>=max(size(nhood_)) && islogical(nhood_) && ismatrix(A) && ismatrix(nhood_) && ~any(height,'all'))
    if isvector(nhood_) && all(nhood_(:))
        if islogical(A) 
            B = morphop_ver_hor_logical(A,nhood_,op_type);
            return;
        elseif numel(nhood_)>=11
            B = morphop_ver_hor_numeric(A,nhood_,op_type);
            return;
        end
    elseif (islogical(A) && size(nhood_,1)>=5) && (isequal(eye(size(nhood_,1),'logical'), nhood_) || isequal(eye(size(nhood_,1),'logical'), rot90(nhood_)))
        B = morphop_diag_logical(A,nhood_,op_type);
        return;
    end
end


%% Edge case - 3D nhood, 2D image
if ndims(nhood_)== 3 && ndims(A)==2 %#ok<ISMAT>
    % Pick central plane
    zdim = size(nhood_,3);
    nhood = nhood_(:,:,ceil(zdim/2));
else
    nhood = nhood_;
end


%% Core implementation
switch (op_type)
    case 'dilate'
        initVal = double(minVal);
        
        % Reflect nhood
        if(ismatrix(A))
            % If ndims(nhood)>2, then trailing nhood dimension don't count.
            % Effectively, reflect only the first plane. (the rest get
            % flipped, but they are 'don't-cares').
            nhood  = flip(flip(nhood,1),2);
            height = flip(flip(height,1),2);
            
        else
            nhood(1:end)  = nhood(end:-1:1);
            height(1:end) = height(end:-1:1);
        end
        
        if(all(height(:)==0))
            np = images.internal.coder.NeighborhoodProcessor(size(A),nhood);
        else
            np = images.internal.coder.NeighborhoodProcessor(size(A),nhood,...
                'NeighborhoodCenter', images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT);
        end
        
        params.initVal = initVal;
        params.height  = height;
        params.isHeightNonFlat = any(height(:)~=0);
        B = np.process(A, @dilateAlgo, B, params);
        
    case 'erode'
        initVal = double(maxVal);
        
        np = images.internal.coder.NeighborhoodProcessor(size(A),nhood,...
            'NeighborhoodCenter', images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT);
        
        params.initVal = initVal;
        params.height  = height;
        params.isHeightNonFlat = any(height(:)~=0);
        B = np.process(A, @erodeAlgo, B, params);
        
    otherwise
        assert(false,'Unknown operation');
end

end

function pixelout = dilateAlgo(imnh, params)
% Find maximum in pixel neighborhood
coder.inline('always');
if params.isHeightNonFlat
    for pind=1:numel(imnh)
        if isfloat(imnh) || islogical(imnh)
            imnh(pind)     = double(imnh(pind)) + params.height(params.nhInds(pind));
        else
            % On profiling, found muDoubleScalarRound function calls which
            % affects the performance and want to avoid rounding this way.
            % Perform efficient rounding by adding 0.5 and c-style casting.
            temp = double(imnh(pind)) + params.height(params.nhInds(pind)) + 0.5;
            imnh(pind)     = eml_cast(temp, class(imnh), 'floor');
        end
    end
end
pixelout = max([imnh(:); params.initVal]);
end

function pixelout = erodeAlgo(imnh, params)
% Find minimum in pixel neighborhood
coder.inline('always');
if params.isHeightNonFlat
    for pind=1:numel(imnh)
        if isfloat(imnh) || islogical(imnh)
            imnh(pind)     = double(imnh(pind)) - params.height(params.nhInds(pind));
        else
            % On profiling, found muDoubleScalarRound function calls which
            % affects the performance and want to avoid rounding this way.
            % Perform efficient rounding by adding 0.5 and c-style casting.
            temp = double(imnh(pind)) - params.height(params.nhInds(pind)) + 0.5;
            imnh(pind)     = eml_cast(temp, class(imnh), 'floor');
        end
    end
end
pixelout = min([imnh(:); params.initVal]);
end

function o = morphop_ver_hor_logical(in, filter, op_type)
% For binary image and binary linear filter,
% perform dilation/erosion using a horizontal/vertical sliding window.
% -------------------------------------
% Input/output
% in: a binary image
% filter: a logical row or column vector of true's
% op_type: string with value 'dilate' or 'erode'
% o: a binary image

coder.inline('always');
is_dilation = coder.const(strcmp(op_type,'dilate'));
o = coder.nullcopy(zeros(size(in),'like',in));
filter_len = max(size(filter));
[m,n] = size(in);
if is_dilation
    filter_center = ceil((filter_len+1)/2);
else
    filter_center = floor((filter_len+1)/2);
end

% filter is a col of 1s, treverse image vertically
if size(filter,2)==1
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for j = 1:n  % outter loop handles columns
        count = int32(sum(in(1:filter_len-filter_center+1,j))); % initialize count
        if is_dilation
            o(1,j) = count>0;
        else
            o(1,j) = count==filter_len-filter_center+1;
        end
        % process top border
        for i = 2:filter_center
            count = count+int32(in(i+filter_len-filter_center,j)); % count in
            if is_dilation
                o(i,j) = count>0;
            else
                o(i,j) = count==filter_len-filter_center+i;
            end
        end

        % process internal pixels
        for i = filter_center+1:m-(filter_len-filter_center)
            count = count+int32(in(i+filter_len-filter_center,j)); % count in
            count = count-int32(in(i-filter_center,j)); % count out
            if is_dilation
                o(i,j) = count>0;
            else
                o(i,j) = count==filter_len;
            end
        end

        % process bottom border
        for i = m-(filter_len-filter_center)+1:m
            count = count-int32(in(i-filter_center,j)); % count out
            if is_dilation
                o(i,j) = count>0;
            else
                o(i,j) = count==m+filter_center-i;
            end
        end
    end

% filter is a row of 1s, traverse image horizontally
else
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for i = 1:m
        count = int32(sum(in(i,1:filter_len-filter_center+1))); % initialize count
        if is_dilation
            o(i,1) = count>0;
        else
            o(i,1) = count==filter_len-filter_center+1;
        end

        % process left border
        for j = 2:filter_center
            count = count+int32(in(i,j+filter_len-filter_center)); % count in
            if is_dilation
                o(i,j) = count>0;
            else
                o(i,j) = count==filter_len-filter_center+j;
            end
        end

        % process internal pixels
        for j = filter_center+1:n-(filter_len-filter_center)
            count = count+int32(in(i,j+filter_len-filter_center)); % count in
            count = count-int32(in(i,j-filter_center)); % count out
            if is_dilation
                o(i,j) = count>0;
            else
                o(i,j) = count==filter_len;
            end
        end

        % process right border
        for j = n-(filter_len-filter_center)+1:n
            count = count-int32(in(i,j-filter_center)); % count out
            if is_dilation
                o(i,j) = count>0;
            else
                o(i,j) = count==n+filter_center-j;
            end
        end
    end
end
end

function o = morphop_ver_hor_numeric(in, filter, op_type)
% For 2D image and binary linear filter,
% perform dilation/erosion using a horizontal/vertical sliding window.
% -------------------------------------
% Input/output
% in: a 2D image
% filter: a logical row or column vector of true's
% op_type: string with value 'dilate' or 'erode'
% o: a 2D image

coder.inline('always');
is_dilation = coder.const(strcmp(op_type,'dilate'));
o = coder.nullcopy(zeros(size(in),'like',in));
filter_len = max(size(filter));
[m,n] = size(in);
if is_dilation
    filter_center = ceil((filter_len+1)/2);
else
    filter_center = floor((filter_len+1)/2);
end

% filter is a col of 1s, treverse image vertically
if size(filter,2)==1
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for j = 1:n  % outter loop handles columns
        queue = coder.nullcopy(zeros([1 size(in,1)],'uint32'));
        front = coder.internal.indexInt(1);
        back = coder.internal.indexInt(1);
        
        % initialize queue to process first pixel
        for i=1:filter_len-filter_center+1 
            if is_dilation
                while front~=back && in(i,j)>=in(queue(back-1),j)
                    back = back-1;
                end
            else
                while front~=back && in(i,j)<=in(queue(back-1),j)
                    back = back-1;
                end
            end
            queue(back) = i;
            back = back+1;
        end
        o(1,j) = in(queue(front),j);
        
        % process top border, don't need to remove out-of-window element
        for i = 2:filter_center
            if is_dilation
                while front~=back && in(i+filter_len-filter_center,j)>=in(queue(back-1),j) % remove elements smaller than the element currently being added
                    back = back-1;
                end
            else
                while front~=back && in(i+filter_len-filter_center,j)<=in(queue(back-1),j) % remove elements bigger than the element currently being added
                    back = back-1;
                end
            end
            queue(back) = i+filter_len-filter_center;
            back = back+1;
            o(i,j) = in(queue(front),j);
        end

        % process internal pixels
        for i = filter_center+1:m-(filter_len-filter_center)
            while front~=back && queue(front)<=i-filter_center % remove out-of-window elements
                front = front+1;
            end
            if is_dilation
                while front~=back && in(i+filter_len-filter_center,j)>=in(queue(back-1),j) % remove elements smaller than the element currently being added
                    back = back-1;
                end
            else
                while front~=back && in(i+filter_len-filter_center,j)<=in(queue(back-1),j) % remove elements bigger than the element currently being added
                    back = back-1;
                end
            end
            queue(back) = i+filter_len-filter_center;
            back = back+1;
            o(i,j) = in(queue(front),j);
        end

        % process bottom border
        for i = m-(filter_len-filter_center)+1:m
            while front~=back && queue(front)<=i-filter_center % remove out-of-window elements
                front = front+1;
            end
            o(i,j) = in(queue(front),j);
        end
    end

else % filter is a row of 1s, traverse image horizontally
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for i = 1:m
        queue = coder.nullcopy(zeros([1 size(in,2)],'uint32'));
        front = coder.internal.indexInt(1);
        back = coder.internal.indexInt(1);
        
        % initialize queue to process first pixel
        for j=1:filter_len-filter_center+1 
            if is_dilation
                while front~=back && in(i,j)>=in(i,queue(back-1))
                    back = back-1;
                end
            else
                while front~=back && in(i,j)<=in(i,queue(back-1))
                    back = back-1;
                end
            end
            queue(back) = j;
            back = back+1;
        end
        o(i,1) = in(i,queue(front));
        
        % process left border, don't need to remove out-of-window element
        for j = 2:filter_center
            if is_dilation
                while front~=back && in(i,j+filter_len-filter_center)>=in(i,queue(back-1)) % remove elements smaller than the element currently being added
                    back = back-1;
                end
            else
                while front~=back && in(i,j+filter_len-filter_center)<=in(i,queue(back-1)) % remove elements bigger than the element currently being added
                    back = back-1;
                end
            end
            queue(back) = j+filter_len-filter_center;
            back = back+1;
            o(i,j) = in(i,queue(front));
        end

        % process internal pixels
        for j = filter_center+1:n-(filter_len-filter_center)
            while front~=back && queue(front)<=j-filter_center % remove out-of-window elements
                front = front+1;
            end
            if is_dilation
                while front~=back && in(i,j+filter_len-filter_center)>=in(i,queue(back-1)) % remove elements smaller than the element currently being added
                    back = back-1;
                end
            else
                while front~=back && in(i,j+filter_len-filter_center)<=in(i,queue(back-1)) % remove elements bigger than the element currently being added
                    back = back-1;
                end
            end
            queue(back) = j+filter_len-filter_center;
            back = back+1;
            o(i,j) = in(i,queue(front));
        end

        % process right border
        for j = n-(filter_len-filter_center)+1:n
            while front~=back && queue(front)<=j-filter_center % remove out-of-window elements
                front = front+1;
            end
            o(i,j) = in(i,queue(front));
        end
    end
end
end

function o = morphop_diag_logical(in, filter, op_type)
% For binary image and binary linear filter,
% perform dilation/erosion using a diagonal sliding window.
% -------------------------------------
% Input/output
% in: a binary image
% filter: a logical square matrix with either diagonal set to true's
% op_type: string with value 'dilate' or 'erode'
% o: a binary image

coder.inline('always');
is_dilation = coder.const(strcmp(op_type,'dilate'));
o = coder.nullcopy(zeros(size(in),'like',in));
filter_len = size(filter,1); % filter is square
[m,n] = size(in);
if is_dilation
    filter_center = ceil((filter_len+1)/2);
else
    filter_center = floor((filter_len+1)/2);
end

% filter is downward going diagonal.
if filter(1)
    if is_dilation
        in_pad = zeros([m n]+filter_len-1,'like',in);
    else
        in_pad = ones([m n]+filter_len-1,'like',in);
    end
    in_pad(filter_center:m+filter_center-1, filter_center:n+filter_center-1) = in;

    % process top-right region from diagonal (including diagonal)
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for j = 1:n
        count = int32(sum(diag(in_pad(1:filter_len,j:j+filter_len-1)))); % initialize count
        if is_dilation
            o(1,j) = count>0;
        else
            o(1,j) = count==filter_len;
        end
        % process internal pixels
        for i = 2:min(m, n-j+1)
            count = count+int32(in_pad(i+filter_len-1,i+j-1+filter_len-1)); % count in
            count = count-int32(in_pad(i-1,i+j-1-1)); % count out
            if is_dilation
                o(i,i+j-1) = count>0;
            else
                o(i,i+j-1) = count==filter_len;
            end
        end
    end
    %process bottom-left region from diagonal (exclude diagonal)
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for i = 2:m
        count = int32(sum(diag(in_pad(i:i+filter_len-1,1:filter_len)))); % initialize count
        if is_dilation
            o(i,1) = count>0;
        else
            o(i,1) = count==filter_len;
        end
        % process internal pixels
        for j = 2:min(n, m-i+1)
            count = count+int32(in_pad(j+i-1+filter_len-1,j+filter_len-1)); % count in
            count = count-int32(in_pad(j+i-1-1,j-1)); % count out
            if is_dilation
                o(j+i-1,j) = count>0;
            else
                o(j+i-1,j) = count==filter_len;
            end
        end
    end

% filter is upward going diagonal.
else
    if is_dilation
        in_pad = zeros([m n]+filter_len-1,'like',in);
    else
        in_pad = ones([m n]+filter_len-1,'like',in);
    end
    in_pad(filter_center:m+filter_center-1, filter_center:n+filter_center-1) = in;

    % process top-left region from diagonal (including diagonal)
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for i = 1:m
        count = int32(sum(diag(flip(in_pad(i:i+filter_len-1,1:filter_len))))); % initialize count
        if is_dilation
            o(i,1) = count>0;
        else
            o(i,1) = count==filter_len;
        end
        % process internal pixels
        for j = 2:min(n, i)
            count = count+int32(in_pad(i-j+1,j+filter_len-1)); % count in
            count = count-int32(in_pad(i-j+1+filter_len,j-1)); % count out
            if is_dilation
                o(i-j+1,j) = count>0;
            else
                o(i-j+1,j) = count==filter_len;
            end
        end
    end
    %process bottom-right region from diagonal (exclude diagonal)
    coder.internal.treatAsParfor();
    coder.internal.parallelRelax();
    for j = 2:n
        count = int32(sum(diag(flip(in_pad(end-filter_len:end,j:j+filter_len-1))))); % initialize count
        if is_dilation
            o(m,j) = count>0;
        else
            o(m,j) = count==filter_len;
        end
        % process internal pixels
        for i = 2:min(m, n-j+1)
            count = count+int32(in_pad(m-i+1,j+i-1+filter_len-1)); % count in
            count = count-int32(in_pad(m-i+1+filter_len,j+i-1-1)); % count out
            if is_dilation
                o(m-i+1,j+i-1) = count>0;
            else
                o(m-i+1,j+i-1) = count==filter_len;
            end
        end
    end
end
end
