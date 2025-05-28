function out = imadjust(varargin) %#codegen

coder.extrinsic('warning');

% Copyright 2014-2024 The MathWorks, Inc.

% Parse inputs and initialize variables
narginchk(1,4);
img = varargin{1};

if nargin == 1
    % IMADJUST(I)
    coder.internal.errorIf(~ismatrix(img) && (ndims(img)==3 && size(img,3)==3),...
        'images:imadjust:oneArgOnlyGrayscale');
    coder.internal.errorIf(~ismatrix(img) && (ndims(img)>3 || size(img,3)~=3),...
        'images:imadjust:invalidImage');
    
    validateattributes(img, {'double' 'uint8' 'uint16' 'int16' 'single'}, ...
        {'2d'}, mfilename, 'I', 1);
    
    % Turn off warning 'images:imhistc:inputHasNans' before calling STRETCHLIM and
    % restore afterwards. STRETCHLIM calls IMHIST/IMHISTC and the warning confuses
    % a user who calls IMADJUST with NaNs when creating a mex file only
    s = warning('off','images:imhistc:inputHasNaNs');
    lowhigh_in = stretchlim(img);
    warning(s)
    
    lowhigh_out = [0; 1];
    gammaIn = 1;
    
else
    isRGB = ndims(img) == 3 && size(img,3) == 3;
    isGray = ismatrix(img);
    coder.internal.assert(isRGB || isGray, 'images:imadjust:invalidImage');
    
    if isRGB
        % RGB image
        coder.internal.errorIf(~(size(img,3)==3), ...
            'images:imadjust:invalidImage');
        validateattributes(img, {'double' 'uint8' 'uint16' 'int16' 'single'}, ...
            {}, mfilename, 'RGB', 1);
    else
        % Grayscale image
        validateattributes(img, {'double' 'uint8' 'uint16' 'int16' 'single'}, ...
            {'2d'}, mfilename, 'I', 1);
    end
    
    if nargin == 2
        % IMADJUST(I,[LOW_IN HIGH_IN])
        % IMADJUST(RGB,[LOW_IN HIGH_IN])
        lowhigh_out = [0; 1];
        gamma = 1;
        if ~isempty(varargin{2})
            lowhigh_in = double(varargin{2});
        else
            lowhigh_in  = [0; 1];
        end
        
        
    elseif nargin == 3
        % IMADJUST(I,[LOW_IN HIGH_IN],[LOW_OUT HIGH_OUT])
        % IMADJUST(RGB,[LOW_IN HIGH_IN],[LOW_OUT HIGH_OUT])
        gamma = 1;
        if ~isempty(varargin{2})
            lowhigh_in = double(varargin{2});
        else
            lowhigh_in = [0; 1];
        end
        if ~isempty(varargin{3})
            lowhigh_out = double(varargin{3});
        else
            lowhigh_out = [0; 1];
        end
    else
        % IMADJUST(I,[LOW_IN HIGH_IN],[LOW_OUT HIGH_OUT],GAMMA)
        % IMADJUST(RGB,[LOW_IN HIGH_IN],[LOW_OUT HIGH_OUT],GAMMA)
        if ~isempty(varargin{2})
            lowhigh_in = double(varargin{2});
        else
            lowhigh_in = [0; 1];
        end
        if ~isempty(varargin{3})
            lowhigh_out = double(varargin{3});
        else
            lowhigh_out = [0; 1];
        end
        if ~isempty(varargin{4})
            gamma = varargin{4};
        else
            gamma = 1;
        end
    end
    
    if (size(img,3)==3)
        
        % Compile time errors
        coder.internal.errorIf(~(numel(lowhigh_in) == 2 || isequal(size(lowhigh_in), [2 3])), ...
            'images:imadjust:InputMustBe2ElVecOr2by3Matrix', '[LOW_IN; HIGH_IN]');
        
        coder.internal.errorIf(~(numel(lowhigh_out) == 2 || isequal(size(lowhigh_out), [2 3])), ...
            'images:imadjust:InputMustBe2ElVecOr2by3Matrix', '[LOW_OUT; HIGH_OUT]');
        
        validateattributes(gamma,{'double'},{'nonnegative','2d'},...
            mfilename, 'GAMMA', 4)
        if numel(gamma) == 1
            gammaIn = gamma*ones(1,3);
        elseif numel(gamma) == 3
            gammaIn = gamma;
        else
            %Invalid gamma
            coder.internal.errorIf(true, 'images:imadjust:invalidGamma');
        end
        
    else
        % Compile time errors
        coder.internal.errorIf(~(isequal(size(lowhigh_in),[2 1]) || isequal(size(lowhigh_in),[1 2])), ...
            'images:imadjust:InputMustBe2ElVec', '[LOW_IN; HIGH_IN]');
        
        coder.internal.errorIf(~(isequal(size(lowhigh_out),[2 1]) || isequal(size(lowhigh_out),[1 2])), ...
            'images:imadjust:InputMustBe2ElVec', '[LOW_OUT; HIGH_OUT]');
        
        validateattributes(gamma,{'double'},{'scalar', 'nonnegative'}, ...
            mfilename, 'GAMMA', 4)
        gammaIn = gamma;
    end
end


if numel(lowhigh_in) == 2
    if size(img,3)~=3
        lowIn = lowhigh_in(1);
        highIn = lowhigh_in(2);
    else
        % Create triples for RGB image or Colormap
        lowIn = lowhigh_in(1) * ones(1,3);
        highIn = lowhigh_in(2) * ones(1,3);
    end
else
    % range is a 2 by 3 array
    lowIn = lowhigh_in(1,:);
    highIn = lowhigh_in(2,:);
end

if numel(lowhigh_out) == 2
    if size(img,3)~=3
        lowOut = lowhigh_out(1);
        highOut = lowhigh_out(2);
    else
        % Create triples for RGB image or Colormap
        lowOut = lowhigh_out(1) * ones(1,3);
        highOut = lowhigh_out(2) * ones(1,3);
    end
else
    % range is a 2 by 3 array
    lowOut = lowhigh_out(1,:);
    highOut = lowhigh_out(2,:);
end

coder.internal.errorIf(any(lowIn>=highIn), 'images:imadjust:lowMustBeSmallerThanHigh')

coder.internal.errorIf(isInvalidRange(lowIn) || isInvalidRange(highIn) ...
    || isInvalidRange(lowOut) || isInvalidRange(highOut), 'images:imadjust:parametersAreOutOfRange');

% GPU codegen implementation of imadjust
if coder.gpu.internal.isGpuEnabled
    
    % Checking VarDims and issuing warning
    if ~coder.internal.isConst(size(img))
        coder.gpu.internal.diagnostic('gpucoder:diagnostic:ImadjustInputVardims');
    end
    
    % Call for gpu_imadjust containing GPU implementation imadjust
    out = images.internal.coder.gpu.imadjustGPUImpl(img, lowIn, highIn, lowOut, highOut,...
        gammaIn, class(img));
    return
end

if ~isfloat(img) && numel(img) > 65536
    % integer data type image with more than 65536 elements
    imgClass = class(img);
    out = coder.nullcopy(zeros(size(img),imgClass));
    
    %initialize for lut
    
    switch imgClass
        case 'uint8'
            lutLength = 256;
            conversionFcn = @im2uint8;
        case 'uint16'
            lutLength = 65536;
            conversionFcn = @im2uint16;
        case 'int16'
            lutLength = 65536;
            conversionFcn = @im2int16;
        otherwise
            coder.internal.errorIf(true,'images:imadjust:internalError');
    end
    
    if coder.isColumnMajor
        for p = coder.unroll(1:size(img,3),coder.internal.isConst(size(img,3)))
            lutIn = linspace(0,1,lutLength);
            lutIn = adjustArray(lutIn,lowIn(p),highIn(p),lowOut(p),highOut(p), ...
                gammaIn(p));
            lut = conversionFcn(lutIn);
            out(:,:,p) = intlut(img(:,:,p),lut);
        end
    else % Row-major
        lut = coder.nullcopy(zeros(1,lutLength,size(img,3),imgClass));
        if numel(size(img)) == 2
            lutIn = linspace(0,1,lutLength);
            lutIn = adjustArray(lutIn,lowIn(1),highIn(1),lowOut(1),highOut(1), ...
                gammaIn(1));
            lut = conversionFcn(lutIn);
			if ~coder.internal.isInParallelRegion
                imgSize2 = size(img,2);
                parfor i = 1:size(img,1)
                    for j = 1:imgSize2
                        out(i,j) = intlut(img(i,j),lut);
                    end
                end
            else
                for i = 1:size(img,1)
                    for j = 1:size(img,2)
                        out(i,j) = intlut(img(i,j),lut);
                    end
                end
			end
        else % 3-D
            for k = 1:size(img,3)
                lutIn = linspace(0,1,lutLength);
                lutIn = adjustArray(lutIn,lowIn(k),highIn(k),lowOut(k),highOut(k), ...
                    gammaIn(k));
                lut(1,1:lutLength,k) = conversionFcn(lutIn);
            end
            if isa(img,'int16')
                offset = coder.const(coder.internal.indexInt(32769));
            else
                offset = coder.const(coder.internal.indexInt(1));
            end
            if ~coder.internal.isInParallelRegion
                imgSize2 = size(img,2);
                imgSize3 = size(img,3);
                parfor i = 1:size(img,1)
                    for j = 1:imgSize2
                        for k = 1:imgSize3
                            % Use optimized code instead of calling intlut
                            % directly
                            idx = coder.internal.indexPlus(img(i,j,k),offset);
                            out(i,j,k) = lut(1,idx,k);
                        end
                    end
                end
            else
                for i = 1:size(img,1)
                    for j = 1:size(img,2)
                        for k = 1:size(img,3)
                            % Use optimized code instead of calling intlut
                            % directly
                            idx = coder.internal.indexPlus(img(i,j,k),offset);
                            out(i,j,k) = lut(1,idx,k);
                        end
                    end
                end
            end
        end
    end
    
else
    classin = class(img);
    if ~isa(img,'double')
        imgIn = im2double(img);
    else
        imgIn = img;
    end
    
    outImg = adjustImage(imgIn,lowIn,highIn,lowOut,highOut,gammaIn);
    
    if ~isa(img,'double')
        out = images.internal.changeClass(classin,outImg);
    else
        out = outImg;
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = adjustImage(rgb,lIn,hIn,lOut,hOut,g)

coder.inline('always');
out = coder.nullcopy(zeros(size(rgb), 'like', rgb));


if coder.isColumnMajor
    for p = 1 : size(rgb,3)
        out(:,:,p) = adjustArray(rgb(:,:,p), lIn(p),hIn(p), lOut(p), ...
            hOut(p), g(p));
    end
else % Row-major
    if ~coder.internal.isInParallelRegion
        rgbSize2 = size(rgb,2);
        rgbSize3 = size(rgb,3);
        parfor i = 1:size(rgb,1)
            for j = 1:rgbSize2
                for p = 1:rgbSize3
                    out(i,j,p) = adjustArray(rgb(i,j,p), lIn(p),hIn(p), lOut(p), ...
                        hOut(p), g(p));
                end
            end
        end
    else
        for i = 1:size(rgb,1)
            for j = 1:size(rgb,2)
                for p = 1:size(rgb,3)
                    out(i,j,p) = adjustArray(rgb(i,j,p), lIn(p),hIn(p), lOut(p), ...
                        hOut(p), g(p));
                end
            end
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = adjustArray(img,lIn,hIn,lOut,hOut,g)

coder.inline('always');
out = coder.nullcopy(img);

if ~coder.internal.isInParallelRegion
    parfor i = 1:numel(img)
        out(i) = ((max(lIn(1),min(hIn(1),img(i))) - lIn(1)) / (hIn(1) - lIn(1))) ...
                 ^ g(1) * (hOut(1) - lOut(1)) + lOut(1);
    end
else
    for i = 1:numel(img)
        out(i) = ((max(lIn(1),min(hIn(1),img(i))) - lIn(1)) / (hIn(1) - lIn(1))) ...
                 ^ g(1) * (hOut(1) - lOut(1)) + lOut(1);
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function isInvalid = isInvalidRange(fullRange)

coder.inline('always');
isInvalid = min(fullRange) < 0 || max(fullRange) > 1;