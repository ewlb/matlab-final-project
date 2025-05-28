function outputImage_ = interp2d(inputImage__,Xin,Yin,method,fillValuesIn, varargin)%#codegen
% FOR INTERNAL USE ONLY -- This function is intentionally
% undocumented and is intended for use only within other toolbox
% classes and functions. Its behavior may change, or the feature
% itself may be removed in a future release.
%
% Vq = INTERP2D(V,XINTRINSIC,YINTRINSIC,METHOD,FILLVAL, SmoothEdges) computes 2-D
% interpolation on the input grid V at locations in the intrinsic
% coordinate system XINTRINSIC, YINTRINSIC.

% Copyright 2013-2024 The MathWorks, Inc.

narginchk(5,6);
if(nargin==5)
    % If not specified, default to NOT smoothing edges
    SmoothEdges = false;
else
    SmoothEdges = varargin{1};
end

%#ok<*EMCA>
coder.inline('always');
coder.internal.prefer_const(inputImage__,Xin,Yin,method,fillValuesIn);

coder.extrinsic('eml_try_catch');
coder.extrinsic('gpucoder.internal.getPrecisionClassType');
coder.extrinsic('gpufeature');

validateattributes(inputImage__,{'logical','numeric'},{'nonsparse'},mfilename,'inputImage');

validateattributes(Xin,{'single','double'},{'nonnan','nonsparse','real','2d'},mfilename,'X');

validateattributes(Yin,{'single','double'},{'nonnan','nonsparse','real','2d'},mfilename,'Y');

validateattributes(fillValuesIn,{'logical','numeric'},{'nonsparse'},mfilename,'fillValue');

validatestring(method,{'nearest','bilinear','bicubic','linear','cubic'},mfilename);

eml_invariant(eml_is_const(method),...
    eml_message('images:interp2d:interpStringNotConst'),...
    'IfNotConst','Fail');

coder.internal.errorIf(~isequal(size(Xin),size(Yin)),...
    'images:interp2d:inconsistentXYSize');

inputClass = class(inputImage__);

useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() && ...
    coder.const(~images.internal.coder.useSingleThread()) && ...
    coder.const(~(coder.isRowMajor && numel(size(inputImage__))>2));

if(islogical(inputImage__))
    inputImage_ = uint8(inputImage__);
else
    inputImage_ = inputImage__;
end

inputImage = inputImage_;
X_ = Xin;
Y_ = Yin;

% First cast to match the behavior of MATLAB
% Second cast to make sure fillValues is the same type of inputImage
fillValues_ = cast(fillValuesIn, 'like', inputImage__);
fillValues = cast(fillValues_, 'like', inputImage);

if ((numel(size(inputImage)) ~= 2) && isscalar(fillValues))
    % If we are doing plane at time behavior, make sure fillValues
    % always propagates through code as a matrix of size determine by
    % dimensions 3:end of inputImage.
    sizeInputImage = size(inputImage);
    if (numel(size(inputImage)) == 3)
        % This must be handled as a special case because repmat(X,N)
        % replicates a scalar X as a NxN matrix. We want a Nx1 vector.
        sizeVec = [sizeInputImage(3) 1];
    else
        sizeVec = sizeInputImage(3:end);
    end
    fill = repmat(fillValues,sizeVec);

else
    fill = fillValues;
end

if(SmoothEdges)
    [inputImagePadded,Xp,Yp] = padImage(inputImage,X_,Y_,fill);
else
    inputImagePadded = inputImage;
    Xp = X_;
    Yp = Y_;
end

if (useSharedLibrary)
    % MATLAB Host Target (PC)
    outputImage = interpolate_imterp2(inputImagePadded,Xp,Yp,method,fill);
else
    % Non-PC Target
    outputImage = interpolate_interp2(inputImagePadded,Xp,Yp,method,fill);
end

if (islogical(inputImage__))
   outputImage_ = outputImage > 0.5;
else
   outputImage_ = cast(outputImage, inputClass);
end

function outputImage = interpolate_imterp2(inputImage, X, Y, method, fillValues) %#codegen
coder.inline('always');
coder.internal.prefer_const(inputImage, X, Y, method, fillValues);

outputImageSize = size(inputImage);
outputImageSize(1) = size(X,1);
outputImageSize(2) = size(X,2);

outputImage = coder.nullcopy(zeros((outputImageSize), 'like', inputImage));


methodEnum = 1;
if (strcmp(method, 'nearest'))
    methodEnum = 1;
elseif strcmp(method, 'bilinear') || strcmp(method, 'linear')
    methodEnum = 2;
elseif strcmp(method, 'bicubic') ||strcmp(method, 'cubic')
    methodEnum = 3;
end
    if isa(X,'double')
        qType = '64f';
    else
        qType = '32f';
    end

    % e.g imterp2d32f_uint8
    fcnName = ['imterp2d', qType, '_', images.internal.coder.getCtype(inputImage)];
    if isreal(inputImage)
    outputImage = images.internal.coder.buildable.Imterp2DBuildable.imterp2d(fcnName, ...
        inputImage,  ...
        Y, ...
        X, ...
        methodEnum, ...
        fillValues, ...
        outputImage);
    else
        outputImageR = coder.nullcopy(zeros((outputImageSize), 'like', real(inputImage)));
        outputImageI = coder.nullcopy(zeros((outputImageSize), 'like', real(inputImage)));

        outputImageR = images.internal.coder.buildable.Imterp2DBuildable.imterp2d(fcnName, ...
        real(inputImage),  ...
        Y, ...
        X, ...
        methodEnum, ...
        real(fillValues), ...
        outputImageR);

        outputImageI = images.internal.coder.buildable.Imterp2DBuildable.imterp2d(fcnName, ...
        imag(inputImage),  ...
        Y, ...
        X, ...
        methodEnum, ...
        imag(fillValues), ...
        outputImageI);
        outputImage = complex(outputImageR, outputImageI);
    end

function outputImage = interpolate_interp2(inputImageIn,X_,Y_,method,fill)

% Required since we allow uint8 inputs to interp2d and interp2 in
% MATLAB does not support integer datatype inputs.
if ~isfloat(inputImageIn)
    inputImage = single(inputImageIn);
else
    inputImage = inputImageIn;
end

coder.inline('always');
coder.internal.prefer_const(inputImage,X_,Y_,method,fill);

% interp2 only accepts nearest,linear and cubic as method strings in code
% generation.
if strcmp(method,'bilinear')
    methodStr = 'linear';
elseif strcmpi(method,'bicubic')
    methodStr = 'cubic';
else
    methodStr = method;
end

% Preallocate outputImage so that we can call interp2 a plane at a time if
% the number of dimensions in the input image is greater than 2.
if ~ismatrix(inputImage)
    [~,~,P] = size(inputImage);
    sizeInputVec = size(inputImage);
    outputImage = zeros([size(X_) sizeInputVec(3:end)],'like',inputImage);
else
    P = 1;
    outputImage = zeros(size(X_),'like',inputImage);
end

% Codegen requires calling interp2 with spatial referencing information for
% the grid pixel center locations.

if ~isa(inputImage,'double')
    XIntrinsic = single(1:size(inputImage,2));
    YIntrinsic = single(1:size(inputImage,1));
else
    XIntrinsic = 1:size(inputImage,2);
    YIntrinsic = 1:size(inputImage,1);
end


for plane = 1:P
    % images.internal.coder.interp2 is similar to interp2 of MATLAB base,
    % but it also supports single dimensional input image, see geck, g1977680
    outputImage(:,:,plane) = images.internal.coder.interp2(...
        XIntrinsic,...
        YIntrinsic,...
        inputImage(:,:,plane),...
        X_,Y_,methodStr,fill(plane));
end


function [paddedImage,X,Y] = padImage(inputImage,X,Y,fillValues)
% We achieve the 'fill' pad behavior from makeresampler by prepadding our
% image with the fillValues and translating our X,Y locations to the
% corresponding locations in the padded image. We pad two elements in each
% dimension to account for the limiting case of bicubic interpolation,
% which has a interpolation kernel half-width of 2.

coder.inline('always');
coder.internal.prefer_const(inputImage,X,Y,fillValues);

pad = 3;
X = X+pad;
Y = Y+pad;

if isscalar(fillValues) && (numel(size(inputImage)) == 2)
    % fillValues must be scalar and inputImage must be compile-time 2D
    paddedImage = padarray(inputImage,[pad pad],fillValues);
else
    sizeInputImage = size(inputImage);
    sizeOutputImage = sizeInputImage;
    sizeOutputImage(1) = sizeOutputImage(1) + 2*pad;
    sizeOutputImage(2) = sizeOutputImage(2) + 2*pad;
    paddedImage = zeros(sizeOutputImage,'like',inputImage);
    [~,~,numPlanes] = size(inputImage);
    for i = 1:numPlanes
        paddedImage(:,:,i) = padarray(inputImage(:,:,i),[pad pad],fillValues(i));
    end

end
