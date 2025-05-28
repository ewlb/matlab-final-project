function [out,intensityTransform] = histeq(varargin) %#codegen
%HISTEQ Enhance contrast using histogram equalization.

%   Copyright 2014-2021 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(1,3);

% Output display is not supported
coder.internal.errorIf(nargout == 0, ...
    'images:histeq:codegenNoDisplay');

% Indexed image syntaxes are not supported
% HISTEQ(X,MAP,HGRAM)
coder.internal.errorIf(nargin>2,...
    'images:validate:codegenIndexedImagesNotSupported',mfilename);

ain = varargin{1};
if(isfloat(ain))
    NPTS = 256;
else
    NPTS = diff(getrangefromclass(ain)) + 1;    
end

flatHistogram = true;

if nargin == 1
    %HISTEQ(I)
    validateattributes(ain,{'uint8','uint16','double','int16','single'}, ...
        {'nonsparse'}, mfilename,'I',1);
    histogramLength = 64; % Default n
    
else % nargin == 2
    histogramLength = varargin{2};
    
    % HISTEQ(X,map)
    coder.internal.errorIf(size(histogramLength,2) == 3 && size(histogramLength,1) > 1,...
        'images:validate:codegenIndexedImagesNotSupported',mfilename);
    
    % HISTEQ(I,N)
    validateattributes(ain,{'uint8','uint16','double','int16','single'}, ...
        {'nonsparse'}, mfilename,'I',1);
    
    % Use isscalar for a run-time switch
    if isscalar(histogramLength)
        % HISTEQ(I,N)
        validateattributes(histogramLength, {'single','double'},...
            {'nonsparse','integer','real','positive','scalar'},...
            mfilename,'N',2);
        
        % Empty input image
        if isempty(ain)
            out = ain;
            if histogramLength(1) == 1
                % N = 1
                intensityTransform = coder.internal.nan('double');
            else
                intensityTransform = zeros(1,NPTS);
            end
            return
        end
    else
        % HISTEQ(I,HGRAM)
        validateattributes(histogramLength, {'single','double'},...
            {'real','nonsparse','vector','nonempty'},...
            mfilename,'HGRAM',2);

        coder.internal.errorIf(min(size(histogramLength),[],2) > 1,...
            'images:histeq:hgramMustBeAVector');
        
        flatHistogram = false;
    end
end

if (~flatHistogram)
    % Normalize and scale histogram so that sum(histogram) = numel(I)
    hgram = histogramLength*(numel(ain)/sum(histogramLength(:)));
    cumsumInputHist = cumsum(hgram);
else
    % For default flat histogram
    % hgram = ones(histogramLength(1),1)*(numel(ain)/histogramLength(1));
    % Hence cumulative sum can be calculated as:
    cumsumInputHist = ([1:histogramLength(1)]')*(numel(ain)/histogramLength(1));
end

if isa(ain,'int16')
    classChanged = true;
    img = im2uint16(ain);
else
    classChanged = false;
    img = ain;
end

[histInputImg, cumsumImgHist] = computeCumulativeHistogram(img,NPTS);
intensityTransform = createTransformationToIntensityImage(img, cumsumInputHist, NPTS, histInputImg, cumsumImgHist);

b = grayxform(img, intensityTransform);

if classChanged
    out = im2int16(b);
else
    out = b;
end

%--------------------------------------------------------------
function [histInputImg,cumsumImgHist] = computeCumulativeHistogram(img,NPTS)

coder.inline('always');
histInputImg = imhist(img,NPTS);
cumsumImgHist = cumsum(histInputImg);

%--------------------------------------------------------------
function intensityTransform = createTransformationToIntensityImage(img, cumsumInputHist, NPTS, histInputImg, cumsumImgHist)

coder.inline('always');
hgramLength = length(cumsumInputHist);

% Create transformation to an intensity image by minimizing the error
% between desired and actual cumulative histograms.

histInputImg(1) = min(histInputImg(1),0);
histInputImg(end) = min(histInputImg(end),0);
tolerance = histInputImg/2;

% TempArray = tolerance - cumulative sum of Image histogram
tempArray =  (tolerance - cumsumImgHist);

if hgramLength == 1
    % Set T to Inf
    intensityTransform = coder.internal.inf([1,NPTS]);
else
    % The following algorithm is numerically equivalent to:
    % err = (cumsumInputHist(:)*ones(1,NPTS) - ones(hgramLength,1)*cumsumImgHist(:)') + tolerance;
    % err( err < -numel(a)*sqrt(eps) ) = numel(a);
    % [~,Transform] = min(err,[],1);
    % Transform = (Transform - 1) / (hgramLength - 1);
    
    intensityTransform = coder.nullcopy(zeros(1,NPTS));
    for j = 1:NPTS
        indexMin = 1;
        flag = true;
        for i = 1:hgramLength
            if flag && cumsumInputHist(i) + tempArray (j) >= -numel(img)*sqrt(eps)
                    indexMin = i;
                    flag = false;
            end
        end
        intensityTransform(j) = (indexMin -1)/(hgramLength-1);
    end
end
