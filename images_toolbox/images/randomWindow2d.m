function win = randomWindow2d(sz,targetSize,params)
%randomWindow2d Randomly select a rectangular region in an image.
%   win = randomWindow2d(inputSize,targetSize) takes an input image size, 
%   inputSize, and returns a rectangular region of the desired output size, 
%   targetSize. The inputs inputSize and targetSize are two-element or 
%   three-element vectors. If the sizes have three elements, then the 
%   third element is interpreted as the channel dimension and is ignored. 
%   The output, win, is an images.spatialref.Rectangle object.
%
%   win = randomWindow2d(inputSize,'Scale',scale,'DimensionRatio',dimensionRatio)
%   selects a rectangular region whose size and shape are specified 
%   according to Scale and DimensionRatio name-value arguments. Scale and 
%   DimensionRatio are described as:
%
%       'Scale'             Region area as a fraction of the input image area. 
%                           Scale can be a two-element vector that defines a
%                           minimum and maximum fractional area of the region,
%                           respectively. In this case, randomWindow2d selects
%                           a random value within the range to use as the 
%                           fractional region area. Scale can also be a
%                           handle to a function that takes no input arguments
%                           and returns a scalar specifying a valid scale 
%                           value. Values must be in the range [0, 1].
%
%       'DimensionRatio'    Range of aspect ratios of the rectangular region.
%                           You can specify DimensionRatio as a 2-by-2 matrix,
%                           where the first row defines the minimum 
%                           aspect ratio and the second row defines
%                           the maximum aspect ratio. In this case, 
%                           randomWindow2d selects a random value within the
%                           range to use as the aspect ratio. For example, 
%                           to select an aspect ratio in the range 1:8 to 1:4,
%                           specify DimensionRatio as [1 8;1 4].
%                           DimensionRatio can also be a handle to a function
%                           that takes no input arguments and returns a scalar
%                           specifying a valid aspect ratio. Values must be
%                           positive numbers.
%
%   Example: Select rectangular region using target size.
%   -----------------------------------------------------
%   % Read an image.
%   A = imread('peppers.png');
% 
%   % Select region of size 40-by-40 pixels.
%   win = randomWindow2d(size(A),[40,40]);
%
%   [r,c] = deal(win.YLimits(1):win.YLimits(2),win.XLimits(1):win.XLimits(2));
%   Acrop = A(r,c,:);
%   figure
%   montage({A,Acrop});
%
%   Example: Select rectangular region using Scale and dimension ratio.
%   -------------------------------------------------------------------
%   % Read an image.
%   A = imread('peppers.png');
%
%   % Select a region whose area is between 2% and 13% of the area of the 
%   % input image, with an aspect ratio between 1:5 and 4:3.
%   win = randomWindow2d(size(A),'Scale',[0.02,0.13],'DimensionRatio',[1 5;4 3]);
%
%   [r,c] = deal(win.YLimits(1):win.YLimits(2),win.XLimits(1):win.XLimits(2));
%   Acrop = A(r,c,:);
%   figure
%   montage({A,Acrop});
%
%   See also imerase, imwarp, affine2d, affineOutputView, 
%   images.spatialref.Rectangle, imcrop.

%   Copyright 2020-2021 The MathWorks, Inc.

    arguments
        sz {mustBevalidSize(sz),mustBeVector,mustBeNumeric,mustBeReal,mustBeInteger,mustBePositive,mustBeNonsparse}
        targetSize {mustBevalidSizeFortarget(targetSize),mustBeNumeric,mustBeReal,mustBeInteger,mustBePositive,mustBeNonsparse} = []
        params.Scale {mustBeFunctionHandleOrNumeric(params.Scale,'Scale'),mustBevalidArgument(params.Scale,'Scale')}
        params.DimensionRatio {mustBeFunctionHandleOrNumeric(params.DimensionRatio,'DimensionRatio'),...
            mustBevalidArgument(params.DimensionRatio,'DimensionRatio')}
    end
    
    % Error out when both targetSize and scale, dimension is passed.
    iaddErrorInputArgument(targetSize,params);
    
    if(isempty(targetSize))
        % Selects box according to scale and dimension ratio passed. 
        
        % Error checking for function handle.
        params = addErrorCheckingToSelectionFunctions(params);

        % Convert Scale and Aspect ratio to function handle.
        params = structfun(@iconvertInputsToSelectionFcn,params,'UniformOutput',false);

        % Extract image information
        params.h = sz(1);
        params.w = sz(2);
        params.c = 1;
        if(numel(sz)==3)
            params.c = sz(3);
        end

        imageArea = params.h * params.w;
        scaleValue = params.Scale();
        eraseArea = scaleValue*imageArea;
        eraseAspectRatio = params.DimensionRatio();

        wErased = round(sqrt(eraseArea*eraseAspectRatio));
        hErased = round(sqrt(eraseArea/eraseAspectRatio));
        
        % Prioritize scale, if scale and dimensionRatio contradict each
        % other.
        if ((hErased > params.h)||(wErased > params.w))
            scaleFactor = sqrt(scaleValue);
            hErased = round(params.h*scaleFactor);
            wErased = round(params.w*scaleFactor);
        end        

        x1 = randi([1,max(params.w-wErased,1)],1);
        y1 = randi([1,max(params.h-hErased,1)],1);

        xLimits = [x1,x1+wErased];
        yLimits = [y1,y1+hErased];

    else
        % Selects box according to target size passed.
        inputSize = sz(1:2);
        targetSize = targetSize(1:2);
        
        targetSize = cast(targetSize,'like',inputSize);
        if any(targetSize > inputSize)
            error(message('images:cropwindow:targetSizeTooBigForInputImageSize'));
        end
        maxStartPos = inputSize - targetSize + 1;

        startPos = [randi(maxStartPos(1)),randi(maxStartPos(2))];

        xLimits = [startPos(2),startPos(2)+targetSize(2)-1];
        yLimits = [startPos(1),startPos(1)+targetSize(1)-1];
    end
    win = images.spatialref.Rectangle(double(xLimits),double(yLimits));
end

%% Supporting function.

function fcnOut = iconvertInputsToSelectionFcn(valIn)
    % Convert the argument scale and dimension ratio to function handle.
    fcnOut = valIn;
    if isnumeric(valIn)
        valIn = double(valIn);
        if(isequal(size(valIn),[2,2]))
            valIn = valIn(:,1)./valIn(:,2);
            mustBeNonDecreasing(valIn,'DimensionRatio');
        end
        fcnOut = @() rand*diff(valIn) + valIn(1);
    end
end

function mustBeNonDecreasing(args,option)
    % Verify the input array is non decreasing.
    if(~issorted(args))
        if(isequal(option,'Scale'))
            error(message('images:randomWindow2d:NonDecreasingScale'))
        else
            error(message('images:randomWindow2d:NonDecreasingDimensionRatio'))
        end
    end
end

function mustBeFunctionHandleOrNumeric(args,option)
    % Check if the passed argument is function handle or numeric.
    if(~(isa(args,'function_handle') || isa(args,'numeric')))
        error(message('images:randomWindow2d:ValidDataType',option))
    end
end

function mustBevalidArgument(args,option)
    if(isa(args,'numeric'))
        mustBeReal(args);
        mustBeFinite(args);
        mustBeNonNan(args);
        if(isequal(option,'Scale'))
            mustBeInRange(args,0,1);
            mustBeSize(args,[1,2])
            mustBeNonDecreasing(args,option);
        else
            mustBeSize(args,[2,2])
            mustBeGreaterThan(args,0);
        end 
    end
    
end

function mustBeSize(args,sz)
    if(~isequal(size(args),sz))
        st = [int2str(sz(1)),'x',int2str(sz(2))];
        error(message('images:randomWindow2d:InvalidSize',st));
    end
end

function mustBevalidSize(args)
    if ~(numel(args)==3 || numel(args)==2)
        error(message('images:randomWindow2d:Size'));
    end
end

function mustBevalidSizeFortarget(args)
    if ~(numel(args)==3 || numel(args)==2 || isempty(args))
        error(message('images:randomWindow2d:Size'));
    end
end

function val = icallSelectionFcn(fcn,validationFcn,paramName)
% Check the function handle passed is valid function.
try
    val = fcn();
    if ~validationFcn(val)
       error(message('images:randomWindow2d:selectionFunctionYieldedInvalidValue',paramName));
    end
catch ME
    if strcmp(ME.identifier,'images:randomWindow2d:selectionFunctionYieldedInvalidValue')
        rethrow(ME)
    else
        error(message('images:randomWindow2d:invalidSelectionFcn',paramName));
    end
end

end

function params = addErrorCheckingToSelectionFunctions(params)
    % Error check for scale and dimension ratio function handle.
    if isa(params.Scale,'function_handle')
        params.Scale = @() icallSelectionFcn(params.Scale,@(v) standardValidation(v) && (v >= 0) && (v <= 1),'Scale');
    end

    if isa(params.DimensionRatio,'function_handle')
        params.DimensionRatio = @() icallSelectionFcn(params.DimensionRatio,@(v) standardValidation(v) && (v >= 0),'DimensionRatio');
    end
end

function TF = standardValidation(v)
    
TF = isscalar(v) && isnumeric(v) && isreal(v) && isfinite(v) && ~isempty(v);

end

function iaddErrorInputArgument(targetSize,params)
    % Throw error when both targetSize and NVP is passed or when nothing of
    % those two is passed.
    if isempty(targetSize) && isempty(fieldnames(params)) || (~isempty(targetSize) && ~isempty(fieldnames(params)))
        error(message('images:randomWindow2d:InvalidArgument'));
    end
    
    % Throw error when either of Scale or dimension ratio is not specified.
    if isempty(targetSize) && numel(fieldnames(params))<2
        error(message('images:randomWindow2d:InvalidArgumentNVP'));
    end
end
