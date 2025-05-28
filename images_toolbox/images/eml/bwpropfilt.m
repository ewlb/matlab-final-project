function out = bwpropfilt(varargin)%#codegen

%#ok<*EMCA>


[arg1, arg2, attrib, p, direction, conn] = parse_inputs(varargin{:});

if isstruct(arg1)
    % CC is a user input. It can be generated in SIM (for MEX workflows) or
    % Codegen. This SIM version does not contain RegionIndices and
    % RegionLengths fields. This has to be handled in the code below.
    CC = arg1;
else
    % CC will always contain RegionIndices and RegionLengths fields.
    CC = bwconncomp(arg1, conn);
end

if isempty(arg2)
    props = regionprops(CC, attrib);
else
    % arg2 will be the Marker Image
    props = regionprops(CC, arg2, attrib);
end

% Allowing the empty case to fall through unlike in SIM. This is to ensure
% OUT is assigned only once for the CC input case. Otherwise, doing the
% short circuit out = arg1 fixes the size of out.PixelIdxList during
% Codegen. This short circuit path is codegened because the empty condition
% can be detected only at runtime. Once the initial assignment is done,
% further assignments to PixelIdxList result in errors.
if isempty(props)
    switch(numel(p))
        case 1
            regionsToKeep = coder.ignoreConst([]);
        case 2
            regionsToKeep = coder.ignoreConst(false(1, CC.NumObjects));
        otherwise
            % Property value already validated. Code cannot reach here.
            coder.internal.assertIf( numel(p)>2, "Invalid Size" );
    end
else
    % get the attrib property
    fields = fieldnames(props);
    tf = zeros(1,numel(props));
    for q = 1:numel(props)
        tf(1,q) = props(q).(fields{1});
    end

    allValues = tf;
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
                coder.internal.warning('images:bwfilt:tie');
            end
            % Keep the first p regions. (linear indices)
            regionsToKeep = idx(1:p);
    
        case 2
            % Find regions within the range. (logical indices)
            regionsToKeep = (allValues >= p(1)) & (allValues <= p(2));

        otherwise
            % Property value already validated. Code cannot reach here.
            coder.internal.assertIf( numel(p)>2, "Invalid Size" );
    end
end

if isstruct(arg1)

    % Calculate the number of regions to keep based on the linear or
    % logical indices determined earlier.
    if ~islogical(regionsToKeep)
        numRegionsToKeep = numel(regionsToKeep);
    else
        numRegionsToKeep = numel(find(regionsToKeep));
    end

    out.Connectivity = CC.Connectivity;
    out.ImageSize = CC.ImageSize;
    out.NumObjects = numRegionsToKeep;

    % Codegen DOES NOT support () indexing of cell arrays i.e. syntax
    % below:
    % out.PixelIdxList = out.PixelIdxList(regionsToKeep);
    % The code below is to get the equivalent functionality

    outPixelIdxList = cell(1, numRegionsToKeep);
    if ~islogical(regionsToKeep)
        % Copy the PixelIdxList value for only the regions that are to be
        % preserved
        for cnt = 1:numRegionsToKeep
            outPixelIdxList{cnt} = CC.PixelIdxList{regionsToKeep(cnt)};
        end
    else
        % For logical indexing, the code pattern below ensures that MATLAB
        % Coder is able to determine at compile time that all elements of
        % the output cell array are being assigned. Running a loop over all
        % input objects instead results in the error "Unable to determine
        % that every element of 'out{:}' is assigned before exiting the
        % function."
        inRegionCnt = 1;
        for cnt = 1:numRegionsToKeep
            while ~regionsToKeep(inRegionCnt)
                inRegionCnt = inRegionCnt + 1;
            end

            outPixelIdxList{cnt} = CC.PixelIdxList{inRegionCnt};
            inRegionCnt = inRegionCnt + 1;
        end
    end

    % If CC struct has RegionLengths and RegionIndices fields, these have
    % to be updated as well. 
    if isfield(CC, "RegionLengths")
        [out.RegionIndices, out.RegionLengths] = ...
                    images.internal.coder.pixIdxList2RegionInfo(outPixelIdxList);

    end

    out.PixelIdxList = outPixelIdxList;

else
    % The output is an logical matrix. The CC struct is for internal use
    % only.

    pixelsToKeep = [];

    % The CC is generated within this function and is guaranteed to have
    % the RegionLengths and RegionIndices fields.
    idxCount = [0;cumsum(CC.RegionLengths)];
    if ~islogical(regionsToKeep)
        % Keep the first p regions. (linear indices)
        for i = 1:length(regionsToKeep)
            k = regionsToKeep(i);
            pixelsToKeep = [pixelsToKeep;CC.RegionIndices(idxCount(k)+1:idxCount(k+1),1)];
        end
    else
        % Find regions within the range. (logical indices) 
        for k = 1:CC.NumObjects
            if regionsToKeep(k) == true
                pixelsToKeep = [pixelsToKeep;CC.RegionIndices(idxCount(k)+1:idxCount(k+1),1)];
            end
        end
    end

    out = false(size(arg1));
    out(pixelsToKeep) = true;
end

end

%--------------------------------------------------------------------------
function [arg1, arg2, attrib, p, direction, conn] = parse_inputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

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
    'Perimeter'}, ...
    mfilename, 'ATTRIB', 2 + argOffset);

% [min max] range or "top n"
pOne = varargin{3 + argOffset};
pLength = numel(pOne);
if pLength == 1
    validateattributes(pOne, {'double'}, {'finite', 'row', 'nonsparse', 'integer', 'positive'}, ...
        mfilename, 'P', 3 + argOffset);
elseif pLength == 2
    validateattributes(pOne, {'numeric'}, {'row', 'nonsparse', 'real', 'nondecreasing'}, ...
        mfilename, 'P', 3 + argOffset);
end
coder.internal.errorIf(pLength ~= 1 && pLength ~= 2,'images:bwfilt:wrongNumelForP');


p = double(pOne);

% End of required arguments.
direction = 'largest';
fourPlusArgOffset = coder.internal.indexInt(4 + argOffset);
fivePlusArgOffset = coder.internal.indexInt(5 + argOffset);
% Ensure KEEP and CONN are in the right order if they're both specified.
if ((nargin - argOffset) < 4)
    conn = conndef(numel(size(arg1)),'maximal');
    return
elseif ((nargin - argOffset) == 5)
    validateattributes(varargin{fourPlusArgOffset}, {'char'}, {'nonsparse'}, ...
        mfilename, 'KEEP', fourPlusArgOffset); % Nonsparse because we have to put something.
    validateattributes(varargin{fivePlusArgOffset}, {'numeric'}, {'real'}, ...
        mfilename, 'CONN', fivePlusArgOffset);

    % Connectivity input not allowed with Connected Component Struct
    coder.internal.errorIf( isstruct(arg1), ...
                            'images:bwfilt:connNotAllowedWithCC' );
end

% Largest/smallest flag (optional)
if ischar(varargin{fourPlusArgOffset})
    direction = varargin{fourPlusArgOffset};

    if (~isempty(direction))
        direction = validatestring(direction, ...
            {'largest', 'smallest'}, ...
            mfilename, 'ATTRIB', fourPlusArgOffset);

        coder.internal.errorIf(numel(p) > 1, 'images:bwfilt:directionRequiresScalarN');

    end

    argOffset = argOffset + 1;
    fourPlusArgOffset = coder.internal.indexInt(4 + argOffset);
    if(nargin < fourPlusArgOffset)
        conn = conndef(numel(size(arg1)),'maximal');
    end
end

% Connectivity (optional)
if (nargin >= fourPlusArgOffset)
    conn = varargin{fourPlusArgOffset};
    
    % Connectivity input not allowed with Connected Component Struct
    coder.internal.errorIf( isstruct(arg1), ...
                            'images:bwfilt:connNotAllowedWithCC' );
end
iptcheckconn(conn, mfilename, 'CONN', 4 + argOffset)

end

function [cc, I, argOffset] = parseConnInputs(varargin)
    cc = varargin{1};
    validateattributes( cc, {'struct'}, {}, mfilename, 'CC', 1);
    
    coder.internal.errorIf( numel(cc.ImageSize) > 2, ...
                            'images:bwfilt:CCMustBe2D' );

    [I, argOffset] = parseMarkerImage(cc.ImageSize, varargin{:});
end


function [bw, I, argOffset] = parseImageInputs(varargin)

    % Binary image
    bw = varargin{1};
    validateattributes( bw, 'logical', {'nonsparse', '2d'}, ...
                        mfilename, 'BW', 1 );

    [I, argOffset] = parseMarkerImage(size(bw), varargin{:});
end


function [I, argOffset] = parseMarkerImage(imageSize, varargin)

    % Marker image (optional)
    if isnumeric(varargin{2})
        I = varargin{2};
        validateattributes( I, { 'double', 'single', 'uint8', 'int8', ...
                                 'uint16', 'int16', 'uint32', 'int32' }, ...
                                 {'nonsparse', '2d'}, ...
                            mfilename, 'I', 2 );

        coder.internal.errorIf( ~isequal(size(I), imageSize), ...
                                'images:bwfilt:inputAndMarkerMismatch' );
        argOffset = coder.internal.indexInt(1);
    else
        I = [];
        argOffset = coder.internal.indexInt(0);
    end
end

%   Copyright 2014-2023 The MathWorks, Inc.
