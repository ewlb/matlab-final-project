function out = bwpropfilt(varargin)

matlab.images.internal.errorIfgpuArray(varargin{:});
args = matlab.images.internal.stringToChar(varargin);
[arg1, arg2, attrib, p, direction, conn] = parse_inputs(args{:});

if isstruct(arg1)
    CC = arg1;
else
    CC = bwconncomp(arg1, conn);
end

if isempty(arg2)
    props = regionprops(CC, attrib);
else
    % arg2 will be the Marker Image
    props = regionprops(CC, arg2, attrib);
end

% This can happen if the input image is empty OR if the CC struct was
% computed for an empty image.
if isempty(props)
    out = arg1;
    return;
end

allValues = [props.(attrib)];

switch numel(p)
    case 1
        % Find the top "p" regions.
        p = min(p, numel(props));
        
        switch direction
            case {'smallest'}
                [~, idx] = sort(allValues, 'ascend');
            otherwise
                [~, idx] = sort(allValues, 'descend');
        end
        
        % Take care of ties.
        minSelected = allValues(idx(p));
        switch direction
            case {'smallest'}
                regionsToKeep = allValues <= minSelected;
            otherwise
                regionsToKeep = allValues >= minSelected;
        end
        
        if (numel(find(regionsToKeep)) > p)
            warning(message('images:bwfilt:tie'))
        end
        
        % Keep the first p regions. (linear indices)
        regionsToKeep = idx(1:p);
        
    case 2
        % Find regions within the range. (logical indices)
        regionsToKeep = (allValues >= p(1)) & (allValues <= p(2));
end

if isstruct(arg1)
    out = CC;
    out.PixelIdxList = out.PixelIdxList(regionsToKeep);
    out.NumObjects = numel(out.PixelIdxList);
else
    pixelsToKeep = CC.PixelIdxList(regionsToKeep);
    pixelsToKeep = vertcat(pixelsToKeep{:});

    out = false(size(arg1));
    out(pixelsToKeep) = true;
end

end

%--------------------------------------------------------------------------
function [arg1, arg2, attrib, p, direction, conn] = parse_inputs(varargin)

narginchk(3,6)

validateattributes( varargin{1}, {'logical', 'struct'}, ...
                        {}, mfilename, 'IN', 1 );

if isstruct(varargin{1})
    [arg1, arg2, argOffset] = parseConnInputs(varargin{:});
else
    [arg1, arg2, argOffset] = parseImageInputs(varargin{:});
end

% Attribute
attrib = validatestring(varargin{2 + argOffset}, {'Area'
      'Circularity'
      'ConvexArea'
      'Eccentricity'
      'EquivDiameter'
      'EulerNumber'
      'Extent'
      'FilledArea'
      'MajorAxisLength'
      'MaxIntensity'
      'MeanIntensity'
      'MinIntensity'
      'MinorAxisLength'
      'Orientation'
      'Perimeter'
      'PerimeterOld'
      'Solidity'}, ...
    mfilename, 'ATTRIB', 2 + argOffset);

% [min max] range or "top n"
p = varargin{3 + argOffset};
switch numel(p)
case 1
    validateattributes(p, {'double'}, {'finite', 'nonsparse', 'integer', 'positive'}, ...
        mfilename, 'P', 3 + argOffset);
case 2
    validateattributes(p, {'numeric'}, {'nonsparse', 'real', 'nondecreasing'}, ...
        mfilename, 'P', 3 + argOffset);
otherwise
    error(message('images:bwfilt:wrongNumelForP'))
end
p = double(p);

% End of required arguments.
direction = 'largest';
conn = conndef(ndims(arg1),'maximal');

% Ensure KEEP and CONN are in the right order if they're both specified.
if ((nargin - argOffset) < 4)
    return
elseif ((nargin - argOffset) == 5)
    validateattributes(varargin{4 + argOffset}, {'char'}, {'nonsparse'}, ...
        mfilename, 'KEEP', 4 + argOffset); % Nonsparse because we have to put something.
    validateattributes(varargin{5 + argOffset}, {'numeric'}, {'real'}, ...
        mfilename, 'CONN', 5 + argOffset);

    % Connectivity input not allowed with Connected Component Struct
    if isstruct(arg1)
        error(message("images:bwfilt:connNotAllowedWithCC"));
    end
end

% Largest/smallest flag (optional)
if ischar(varargin{4 + argOffset})
    direction = varargin{4 + argOffset};
    
    if (~isempty(direction))
        direction = validatestring(direction, ...
            {'largest', 'smallest'}, ...
            mfilename, 'ATTRIB', 4 + argOffset);
        
        if (numel(p) > 1)
            error(message('images:bwfilt:directionRequiresScalarN'))
        end
    end
    
    argOffset = argOffset + 1;
end

% Connectivity (optional)
if (nargin >= 4 + argOffset)
    conn = varargin{4 + argOffset};
    % Connectivity input not allowed with Connected Component Struct
    if isstruct(arg1)
        error(message("images:bwfilt:connNotAllowedWithCC"));
    end
end
iptcheckconn(conn, mfilename, 'CONN', 4 + argOffset)
end

function [cc, I, argOffset] = parseConnInputs(varargin)
    cc = varargin{1};
    validateattributes( cc, {'struct'}, {}, mfilename, 'CC', 1);
    
    if numel(cc.ImageSize) > 2
        error(message('images:bwfilt:CCMustBe2D'));
    end

    [I, argOffset] = parseIntensityImage(cc.ImageSize, varargin{:});
end

function [bw, I, argOffset] = parseImageInputs(varargin)

    % Binary image
    bw = varargin{1};
    validateattributes( bw, 'logical', {'nonsparse', '2d'}, ...
                        mfilename, 'BW', 1 );

    [I, argOffset] = parseIntensityImage(size(bw), varargin{:});
end

function [I, argOffset] = parseIntensityImage(imageSize, varargin)

    % Intensity image (optional)
    if isnumeric(varargin{2})
        I = varargin{2};
        validateattributes( I, { 'double', 'single', 'uint8', 'int8', ...
                                 'uint16', 'int16', 'uint32', 'int32' }, ...
                                 {'nonsparse', '2d'}, ...
                            mfilename, 'I', 2 );

        if ~isequal(size(I), imageSize)
            error(message('images:bwfilt:inputAndMarkerMismatch'));
        end
        argOffset = 1;
    else
        I = [];
        argOffset = 0;
    end
end

%   Copyright 2014-2023 The MathWorks, Inc.
