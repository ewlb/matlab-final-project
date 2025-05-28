function h = montage(varargin)
%   Copyright 1993-2023 The MathWorks, Inc.


waitbarEnabled = true;

[ Isrc,cmap,montageSize,displayRange,displayRangeSpecified,parent,...
            indices, thumbnailSize, thumbnailInterp, borderSize, ...
            backgroundColor, interpolation ] = parse_inputs(varargin{:});

[bigImage, cmap] = images.internal.createMontage( Isrc, thumbnailSize, ...
                        thumbnailInterp, montageSize, borderSize, ...
                        backgroundColor, indices, cmap, waitbarEnabled );

% Handle cases where the image is a gpuArray
bigImage = gather(bigImage);

origWarning = warning();
warnCleaner = onCleanup(@() warning(origWarning));
warning('off', 'MATLAB:images:imshow:ignoringDisplayRange')


if isempty(bigImage)
    hh = imshow([]);
    if nargout > 0
        h = hh;
    end
    return;
end

% Define parenting arguments as cell array so that we can use comma
% separated list to form appropriate syntax in calls to imshow.
if isempty(parent)
    parentArgs = {};
else
    parentArgs = {'Parent',parent};
end
interpolationArgs = {'Interpolation',interpolation};

if ~isempty(parent)
    bigImage = iptui.internal.resizeImageToFitWithinAxes(parent,bigImage);
end

if isempty(cmap)
    if displayRangeSpecified
        hh = imshow(bigImage, displayRange, parentArgs{:},interpolationArgs{:});
        if size(bigImage,3)==3
            % DisplayRange has no impact on RGB images.
            warning(message('MATLAB:images:montage:displayRangeForRGB'));
        end
    else
        hh = imshow(bigImage ,parentArgs{:},interpolationArgs{:});
    end
else
    % Pass cmap along to IMSHOW.
    hh = imshow(bigImage,cmap,parentArgs{:},interpolationArgs{:});
end

if nargout > 0
    h = hh;
end

end

function [ I, cmap, montageSize, displayRange, displayRangeSpecified, ...
           parent, idxs, thumbnailSize, thumbnailInterp, borderSize, ...
           backgroundColor, interpolation ] = parse_inputs(varargin)

narginchk(1, 16);

% Initialize variables
thumbnailSize = "auto";
thumbnailInterp  = "bicubic";
cmap          = [];
montageSize   = [];
parent        = [];
borderSize    = [0 0];
backgroundColor = [];
interpolation = 'nearest';

I = varargin{1};
if iscell(I) || isstring(I)
    nframes = numel(I);
elseif isa(I,'matlab.io.datastore.ImageDatastore')
    nframes = numel(I.Files);
else
    validateattributes(I, ...
        {'uint8' 'double' 'uint16' 'logical' 'single' 'int16'}, {}, ...
        mfilename, 'I, BW, or RGB', 1);
    if ndims(I)==4 % MxNx{1,3}xP        
        if size(I,3)~=1 && size(I,3)~=3
            error(message('MATLAB:images:montage:notVolume'));
        end
        nframes = size(I,4);
    else
        if ndims(I)>4
            error(message('MATLAB:images:montage:notVolume'));
        end
        nframes = size(I,3);
    end
end

varargin(2:end) = matlab.images.internal.stringToChar(varargin(2:end));
charStart = find(cellfun('isclass', varargin, 'char'),1,'first');

displayRange = [];
displayRangeSpecified = false;
idxs = [];

if isempty(charStart) && nargin==2 || isequal(charStart,3)
    % MONTAGE(X,MAP)
    % MONTAGE(X,MAP,Param1,Value1,...)
    cmap = varargin{2};
end

if isempty(charStart) && (nargin > 2)
    error(message('MATLAB:images:montage:nonCharParam'))
end


paramStrings = { 'Size', 'Indices', 'DisplayRange','Parent', ...
                 'ThumbnailSize', 'ThumbnailInterpolation', ...
                 'BorderSize', 'BackgroundColor','Interpolation' };
for k = charStart:2:nargin
    param = lower(varargin{k});
    inputStr = validatestring(param, paramStrings, mfilename, 'PARAM', k);
    valueIdx = k + 1;
    if valueIdx > nargin
        error(message('MATLAB:images:montage:missingParameterValue', inputStr));
    end
    
    switch (inputStr)
        case 'Size'
            montageSize = varargin{valueIdx};
            validateattributes(montageSize,{'numeric'},...
                {'vector','positive','numel',2}, ...
                mfilename, 'Size', valueIdx);
            if all(~isfinite(montageSize))
                montageSize = [];
            else
                montageSize = double(montageSize);
                t = montageSize;
                t(~isfinite(t)) = 0;
                validateattributes(t,{'numeric'},...
                    {'vector','integer','numel',2}, ...
                    mfilename, 'Size', valueIdx);
            end
            
        case 'ThumbnailSize'
            thumbnailSize = varargin{valueIdx};
            if ~isempty(thumbnailSize)
                validateattributes(thumbnailSize,{'numeric'},...
                    {'vector','positive','numel',2}, ...
                    mfilename, 'ThumbnailSize', valueIdx);
                if all(~isfinite(thumbnailSize))
                    thumbnailSize = "auto";
                else
                    thumbnailSize = double(thumbnailSize);
                    t = thumbnailSize;
                    t(~isfinite(t)) = 0;
                    validateattributes(t,{'numeric'},...
                        {'vector','integer','numel',2}, ...
                        mfilename, 'ThumbnailSize', valueIdx);
                end
            end

        case 'ThumbnailInterpolation'
            % Not supporting custom interpolation kernels
            thumbnailInterp = varargin{valueIdx};
            validateattributes( thumbnailInterp, ["string", "char"], ...
                    "scalartext", mfilename, "ThumbnailInterpolation", ...
                    valueIdx ); 
            
        case 'Indices'
            validateattributes(varargin{valueIdx}, {'numeric'},...
                {'integer','nonnan'}, ...
                mfilename, 'Indices', valueIdx);
            idxs = varargin{valueIdx};
            idxs = idxs(:);
            invalidIdxs = ~isempty(idxs) && ...
                any(idxs < 1) || ...
                any(idxs > nframes);
            if invalidIdxs
                error(message('MATLAB:images:montage:invalidIndices'));
            end
            idxs = double(idxs(:));
            if isempty(idxs)
                % Show nothing if idxs was explicitly set to []
                I = [];
            end
            
        case 'DisplayRange'
            displayRange = varargin{valueIdx};
            displayRange = images.internal.checkDisplayRange(displayRange, mfilename);
            displayRangeSpecified = true;
            
        case 'Parent'
            parent = varargin{valueIdx};
            if ~(isscalar(parent) && ishghandle(parent) && ...
                    strcmp(get(parent,'type'),'axes'))
                error(message('MATLAB:images:montage:invalidParent'));
            end
            
        case 'BorderSize'
            borderSize = varargin{valueIdx};
            if isscalar(borderSize)
                borderSize = [borderSize, borderSize]; %#ok<AGROW>
            end
            validateattributes(borderSize, {'numeric', 'logical'},...
                {'integer', '>=',0 , 'numel', 2, 'nrows', 1}, ...
                mfilename, 'BorderSize', valueIdx);
            borderSize = double(borderSize);
            
        case 'BackgroundColor'
            backgroundColor = varargin{valueIdx};
            backgroundColor = convertColorSpec(images.internal.ColorSpecToRGBConverter,backgroundColor);
            backgroundColor = im2uint8(backgroundColor);
            backgroundColor = reshape(backgroundColor, [1 1 3]);
            
        case 'Interpolation'
            interpolation = lower(varargin{valueIdx});
            interpolation = validatestring(interpolation, {'nearest','bilinear'}, mfilename, 'PARAM', k);           
    end
end

end
