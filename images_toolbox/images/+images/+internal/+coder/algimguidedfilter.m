function outI = algimguidedfilter(A, G, filtSize, inversionEpsilon, subsampleFactor)
% This is an EML version of images.internal.algimguidedfilter function.

% The syntax algimguidedfilter(A, G, filtSize, inversionEpsilon, subsampleFactor)
% exposes the "Fast Guided Filter" algorithm by Kaiming He and Jian Sun.
% http://arxiv.org/abs/1505.00996. This is an approximate guided filter
% with improved computational speed.

% No input validation is done in this function.

% Copyright 2021-2024 The MathWorks, Inc.

%#codegen

sizeA = [size(A) 1];
sizeG = [size(G) 1];

% Represents condition when color covariance guided filter is required. 
% Also, at this point, A and G have same number of channels or if not that, then only 1 or 3 channels.
doMultiChannelCovProcessing  = sizeG(3) > sizeA(3); 
isGuidanceChannelReuseNeeded = sizeG(3) < sizeA(3);

approximateGuidedFilter = coder.const(nargin >= 5);
if approximateGuidedFilter
    % Adjust filtSize according to subsampleFactor
    % Note: This will have the effect of always returning an odd kernel
    % length in each dimension. The choice to use approximate guided
    % filtering always results in an odd sized kernel.
    filterRadius = (filtSize-1)/2;
    oddFiltDim = all(mod(filtSize,2) == 1);
    assert(oddFiltDim,'Fast guided filter is not well defined for even filter dimensions');
    goodApproximation = all(filterRadius/subsampleFactor >= 1);
    assert(goodApproximation,'subsampleFactor is too large for filter radius.');
    filterRadius = round(filterRadius/subsampleFactor);
    filtSize = 2*filterRadius+1;
else
    subsampleFactor = 1; % Make the sampling code fall through
end

% Use integral filtering for integer types if the filter kernel is big
% enough. Don't use integral images for floating point inputs to preserve
% NaN/Inf behavior for compatibility reasons. For approximate guided
% filter, go ahead and allow NaN/Inf to propagate in integral domain.
useIntegralFiltering = chooseFilterRegime(filtSize) &&...
    (~isfloat(A) || approximateGuidedFilter) && ~islogical(A);

orignalClassA = class(A);

% Cast A and G to double-precision floating point for computation
Ain = cast(A,'double'); % No-op when A is double
Gin = cast(G,'double');

B = coder.nullcopy(zeros(size(Ain), 'like', Ain));

if ~doMultiChannelCovProcessing
    for k = 1:sizeA(3)

        P = Ain(1:subsampleFactor:end,1:subsampleFactor:end,k);

        if isGuidanceChannelReuseNeeded
            I = Gin(:,:,1);
        else
            I = Gin(:,:,k);
        end

        Iprime = I(1:subsampleFactor:end,1:subsampleFactor:end);

        % From [1] - Algorithm 1: Equation Group 1
        meanI  = meanBoxFilter(Iprime, filtSize, useIntegralFiltering);
        meanP  = meanBoxFilter(P, filtSize, useIntegralFiltering);
        corrI  = meanBoxFilter(Iprime.*Iprime, filtSize, useIntegralFiltering);
        corrIP = meanBoxFilter(Iprime.*P, filtSize, useIntegralFiltering);

        % From [1] - Algorithm 1: Equation Group 2
        varI  = corrI - meanI.*meanI;
        covIP = corrIP - meanI.*meanP;

        % From [1] - Algorithm 1: Equation Group 3
        a = covIP ./ (varI + inversionEpsilon);
        b = meanP - a.*meanI;

        % From [1] - Algorithm 1: Equation Group 4
        meana = meanBoxFilter(a, filtSize, useIntegralFiltering);
        meanb = meanBoxFilter(b, filtSize, useIntegralFiltering);

        if approximateGuidedFilter
            meanaIn = imresize(meana,size(I),'bilinear');
            meanbIn = imresize(meanb,size(I),'bilinear');
        else
            meanaIn = meana;
            meanbIn = meanb;
        end

        % From [1] - Algorithm 1: Equation Group 5
        B(:,:,k) = meanaIn.*I + meanbIn;
    end

else % Do color covariance-based filtering
    % Computing Eqn. 19 from [1].
    % Note that the system of equations in Eqn. 19 is solved using Cramer's
    % rule using closed-form 3x3 matrix inversion.

    Iprime = Gin(1:subsampleFactor:end,1:subsampleFactor:end,:);
    meanIrgb = meanBoxFilter(Iprime,filtSize,useIntegralFiltering);

    meanIr = meanIrgb(:,:,1);
    meanIg = meanIrgb(:,:,2);
    meanIb = meanIrgb(:,:,3);

    P = Ain(1:subsampleFactor:end,1:subsampleFactor:end,:);
    meanP  = meanBoxFilter(P,filtSize, useIntegralFiltering);

    IP = bsxfun(@times, Iprime, P);
    corrIrP = meanBoxFilter(IP(:,:,1),filtSize, useIntegralFiltering);
    corrIgP = meanBoxFilter(IP(:,:,2),filtSize, useIntegralFiltering);
    corrIbP = meanBoxFilter(IP(:,:,3),filtSize, useIntegralFiltering);

    varIrr = meanBoxFilter(Iprime(:,:,1).*Iprime(:,:,1),filtSize, useIntegralFiltering) - meanIr .* meanIr ...
        + inversionEpsilon;
    varIrg = meanBoxFilter(Iprime(:,:,1).*Iprime(:,:,2),filtSize, useIntegralFiltering) - meanIr .* meanIg;
    varIrb = meanBoxFilter(Iprime(:,:,1).*Iprime(:,:,3),filtSize, useIntegralFiltering) - meanIr .* meanIb;
    varIgg = meanBoxFilter(Iprime(:,:,2).*Iprime(:,:,2),filtSize, useIntegralFiltering) - meanIg .* meanIg ...
        + inversionEpsilon;
    varIgb = meanBoxFilter(Iprime(:,:,2).*Iprime(:,:,3),filtSize, useIntegralFiltering) - meanIg .* meanIb;
    varIbb = meanBoxFilter(Iprime(:,:,3).*Iprime(:,:,3),filtSize, useIntegralFiltering) - meanIb .* meanIb ...
        + inversionEpsilon;

    covIrP = corrIrP - meanIr .* meanP;
    covIgP = corrIgP - meanIg .* meanP;
    covIbP = corrIbP - meanIb .* meanP;

    invMatEntry11 = varIgg.*varIbb - varIgb.*varIgb;
    invMatEntry12 = varIgb.*varIrb - varIrg.*varIbb;
    invMatEntry13 = varIrg.*varIgb - varIgg.*varIrb;

    covDet = (invMatEntry11.*varIrr)+(invMatEntry12.*varIrg)+ ...
        (invMatEntry13.*varIrb);
    
    % Variable 'a' in Eqn. 19 in [1]
    a = coder.nullcopy(zeros(size(P,1),size(P,2),3, 'like', P)); 

    a(:,:,1) = ((invMatEntry11.*covIrP) + ...
        ((varIrb.*varIgb - varIrg.*varIbb).*covIgP) + ...
        ((varIrg.*varIgb - varIrb.*varIgg).*covIbP))./covDet;

    a(:,:,2) = ((invMatEntry12.*covIrP) + ...
        ((varIrr.*varIbb - varIrb.*varIrb).*covIgP) + ...
        ((varIrb.*varIrg - varIrr.*varIgb).*covIbP))./covDet;

    a(:,:,3) = ((invMatEntry13.*covIrP) + ...
        ((varIrg.*varIrb - varIrr.*varIgb).*covIgP) + ...
        ((varIrr.*varIgg - varIrg.*varIrg).*covIbP))./covDet;

    % From [1] - Equation 20
    b = meanP - (a(:, :, 1).*meanIr) - (a(:, :, 2).*meanIg) ...
        - (a(:, :, 3).*meanIb);

    % From [1] - Equation 21
    a = meanBoxFilter(a, filtSize, useIntegralFiltering);
    b = meanBoxFilter(b, filtSize, useIntegralFiltering);

    if approximateGuidedFilter
        ain = imresize(a,[size(G,1),size(G,2)],'bilinear');
        bin = imresize(b,[size(G,1),size(G,2)],'bilinear');
    else
        ain = a;
        bin = b;
    end

    B = sum(ain.*Gin, 3) + bin;

end

if strcmp(orignalClassA,'logical') %#ok<ISLOG>
    b = isnan(B); % Re-using variable 'b' to save memory
    B(b) = Ain(b);  % Do not filter pixels with NaN values
end


if strcmp(orignalClassA, 'single') || strcmp(orignalClassA, 'double') || ...
        strcmp(orignalClassA, 'logical') %#ok
    outI = cast(B, orignalClassA);
else
    outI = coder.nullcopy(zeros(size(B),orignalClassA));
    outI = convertToOrignalClass(outI, B, orignalClassA);
end
end

%--------------------------------------------------------------------------
function useIntegralFiltering = chooseFilterRegime(filtSize)
coder.inline('always');
coder.internal.prefer_const(filtSize);

minKernelElementsForIntegralFiltering = images.internal.getBoxFilterThreshold();
useIntegralFiltering = prod(filtSize) >= minKernelElementsForIntegralFiltering;
end

%--------------------------------------------------------------------------
function I = meanBoxFilter(Iin, filtSize, useIntegralFiltering)
coder.inline('always');
coder.internal.prefer_const(Iin, filtSize, useIntegralFiltering);

numKernelElements = prod(filtSize);

if useIntegralFiltering
    Ipad = replicatePadImage(Iin,filtSize);
    intI = integralImage(Ipad);
    I = boxfilterPortable(intI, filtSize, 1/numKernelElements);
else
    h = ones(filtSize)/numKernelElements;
    I = imfilter(Iin, h, 'replicate');
end

end


%--------------------------------------------------------------------------
function out = boxfilterPortable(intA, filterSize, normFactor)
coder.inline('always');
coder.internal.prefer_const(intA, filterSize, normFactor)

% OutSize of Image = size(integralImage) - size(filter)
outSize = size(intA) - [filterSize(1:2),zeros(1,numel(size(intA))-2)];

out = coder.nullcopy(zeros(outSize,'like',intA));

nPlanes = coder.internal.indexInt(coder.internal.prodsize(out,'above',2));
nRows = coder.internal.indexInt(outSize(1));
nCols = coder.internal.indexInt(outSize(2));
if coder.isColumnMajor()
    coder.internal.treatAsParfor
    for p = 1:nPlanes
        for n = 1:nCols
            sC = n;
            eC = coder.internal.indexPlus(sC, coder.internal.indexInt(filterSize(2)));
            for m = 1:nRows
                sR = m;
                eR = coder.internal.indexPlus(sR, coder.internal.indexInt(filterSize(1)));

                firstTerm  = intA(eR,eC,p);
                secondTerm = intA(sR,sC,p);
                thirdTerm  = intA(sR,eC,p);
                fourthTerm = intA(eR,sC,p);

                regionSum = firstTerm + secondTerm - thirdTerm - fourthTerm;

                out(m,n,p) = normFactor * regionSum;
            end
        end
    end
else % Row-major
    coder.internal.treatAsParfor
    for m = 1:nRows
        sR = m;
        eR = coder.internal.indexPlus(sR, coder.internal.indexInt(filterSize(1)));
        for n = 1:nCols
            sC = n;
            eC = coder.internal.indexPlus(sC, coder.internal.indexInt(filterSize(2)));
            for p = 1:nPlanes
                firstTerm  = intA(eR,eC,p);
                secondTerm = intA(sR,sC,p);
                thirdTerm  = intA(sR,eC,p);
                fourthTerm = intA(eR,sC,p);

                regionSum = firstTerm + secondTerm - thirdTerm - fourthTerm;

                out(m,n,p) = normFactor * regionSum;
            end
        end
    end
end
end

%--------------------------------------------------------------------------
function I = replicatePadImage(Iin,filtSize)
coder.inline('always');
coder.internal.prefer_const(Iin,filtSize);

filtCenter = floor((filtSize + 1)/2);
padSize = filtSize - filtCenter;

method = 'replicate';

nonSymmetricPadShift = 1 - mod(filtSize,2);
prePadSize = padSize;
prePadSize(1:2) = padSize(1:2) - nonSymmetricPadShift;

if any(nonSymmetricPadShift==1)
    I1 = padarray(Iin, prePadSize, method, 'pre');
    I = padarray(I1, padSize, method, 'post');
else
    I = padarray(Iin, padSize, method, 'both');
end
end

%--------------------------------------------------------------------------
function outI = convertToOrignalClass(outI, B, orignalClassA)
coder.inline('always')
coder.internal.prefer_const(outI, B, orignalClassA);

high = intmax(orignalClassA);
low = intmin(orignalClassA);
if coder.isColumnMajor
    parfor i=1:numel(B)
        if B(i) > double(high)
            outI(i) = high;
        elseif B(i) < double(low)
            outI(i) = low;
        else
            outI(i) = eml_cast(B(i),orignalClassA);
        end
    end
else % Row-major
    if numel(size(B)) == 2
        nRows = coder.internal.indexInt(size(B,1));
        nCols = coder.internal.indexInt(size(B,2));
        parfor i = 1:nRows
            for j = 1:nCols
                if B(i,j) > double(high)
                    outI(i,j) = high;
                elseif B(i,j) < double(low)
                    outI(i,j) = low;
                else
                    outI(i,j) = eml_cast(B(i,j),orignalClassA);
                end
            end
        end
    elseif numel(size(B)) == 3
        nRows = coder.internal.indexInt(size(B,1));
        nCols = coder.internal.indexInt(size(B,2));
        nPlanes = coder.internal.indexInt(size(B,3));
        parfor i = 1:nRows
            for j = 1:nCols
                for k=1:nPlanes
                    if B(i,j,k) > double(high)
                        outI(i,j,k) = high;
                    elseif B(i,j,k) < double(low)
                        outI(i,j,k) = low;
                    else
                        outI(i,j,k) = eml_cast(B(i,j,k),orignalClassA);
                    end
                end
            end
        end
    else
        assert(false,'Unsupported');
    end
end
end