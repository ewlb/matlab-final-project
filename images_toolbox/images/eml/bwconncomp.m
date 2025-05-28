function CC = bwconncomp(varargin) %#codegen
%BWCONNCOMP Find connected components in binary image.

% Copyright 2015-2023 The MathWorks, Inc.

[BW, conn] = parseInputs(varargin{:});

if coder.gpu.internal.isGpuEnabled

    %% Compute the regions
    [pixelIdxList,regionLengths,numObjs] = images.internal.coder.gpu.bwconncomp(BW, conn);

    %% Output Struct
    CC.Connectivity = conn;
    CC.ImageSize = size(BW);
    CC.NumObjects = numObjs;
    CC.RegionIndices = pixelIdxList;
    CC.RegionLengths = regionLengths;
    return;
end

CC.Connectivity = conn;
CC.ImageSize = size(BW);

if ismatrix(BW) && (isequal(conn,4) || isequal(conn,8))
    [CC.NumObjects,CC.RegionIndices,CC.RegionLengths,CC.PixelIdxList] = ...
        bwconncompTwoD(BW,conn);
else %nd or 2d image with connectivities other than 4 and 8
    [CC.NumObjects,CC.RegionIndices,CC.RegionLengths,CC.PixelIdxList] = ...
        bwconncompND(BW,conn);
end

%--------------------------------------------------------------------------
function [numObjs,regionIndices, regionLengths,pixelIdxList] = bwconncompTwoD(BW,conn)
coder.inline('always');
coder.internal.prefer_const(BW,conn);

% Get initial labels for each run
[startRow,endRow,startCol,labelForEachRun,numRuns] = ...
    images.internal.coder.intermediateLabelRuns(BW,conn);

% Early return when the image contains no connected components.
if numRuns == 0
    % No objects
    numObjs = 0;
    regionIndices = zeros(0,1);
    regionLengths = coder.internal.indexInt(0);
    pixelIdxList = cell(1,0);
    return;
end

% Buffer to store renumbered labels for each run.
labelsRenumbered = coder.nullcopy(labelForEachRun);

% Initialize counter to keep track of number of connected components.
numComponents = 0;

for k = 1:numRuns
    % Renumber labels to get consecutive label numbers.
    if (labelForEachRun(k) == k)
        numComponents = numComponents + 1;
        labelsRenumbered(k) = numComponents;
    end

    % Lookup renumbered label of the run.
    labelsRenumbered(k) = labelsRenumbered(labelForEachRun(k));
end

regionLengths = zeros(numComponents,1,coder.internal.indexIntClass());

for k = 1:numRuns
    % Floor label value by casting.
    idx = coder.internal.indexInt(labelsRenumbered(k));
    % Zero and negative label values represent the background.
    if idx > coder.internal.indexInt(0)
        regionLengths(idx,1) = regionLengths(idx,1) + endRow(k) - startRow(k) + 1;
    end
end

[M,~] = size(BW);
numObjs = numComponents;

regionIndices = coder.nullcopy(zeros(sum(regionLengths,1),1));
idxCount = coder.internal.indexInt([0;cumsum(regionLengths)]);
for k = 1:numRuns

    column_offset = coder.internal.indexTimes(coder.internal.indexMinus(startCol(k),1),M);

    % Floor label value by casting.
    idx = coder.internal.indexInt(labelsRenumbered(k));
    % Zero and negative label values represent the background.
    if idx > coder.internal.indexInt(0)
        for rowidx = startRow(k):endRow(k)
            idxCount(idx) = coder.internal.indexPlus(idxCount(idx),1);
            regionIndices(idxCount(idx),1) = rowidx + column_offset;
        end
    end
end

pixelIdxList = repmat({zeros(coder.ignoreConst(0),1)},1,numObjs);
idxCount = coder.internal.indexInt([0;cumsum(regionLengths)]);
for k = 1:numObjs
    pixelIdxList{k} = regionIndices(idxCount(k)+1:idxCount(k+1),1);
end

%--------------------------------------------------------------------------
function [numObjs,regionIndices, regionLengths,pixelIdxList] = bwconncompND(BW,conn)
coder.inline('always');
coder.internal.prefer_const(BW,conn);

connb = images.internal.getBinaryConnectivityMatrix(conn);
np = images.internal.coder.NeighborhoodProcessor(size(BW),connb);

% Compute internal properties after all the settable properties
% have been updated.
np.updateInternalProperties();

BW2 = BW;

pixelIdxList = repmat({zeros(coder.ignoreConst(0),1)},1,coder.ignoreConst(0));
regionIndices = zeros(coder.ignoreConst(0),1);

for p = 1:coder.internal.indexInt(numel(BW))
    queueOfIndices = zeros(coder.ignoreConst(0),1,coder.internal.indexIntClass);
    if BW2(p)
        % Haven't traversed pixel p yet. Push it onto the queue so we
        % remember to visit p's neighbors.
        queueOfIndices = [queueOfIndices; p]; %#ok<AGROW>

        % Don't visit p again after this scan.
        BW2(p) = false;

        regionLists = zeros(coder.ignoreConst(0),1);

        while(~isempty(queueOfIndices))
            % Set the Pixel r as origin and tranverse to its
            % connected neighbors
            r = queueOfIndices(end);

            % Update the queue removing the pixel r as we transverse
            queueOfIndices = queueOfIndices(1:end-1,1);

            % Add r to the pixelIdxList because it is connected to p.
            regionLists = [regionLists; double(r)]; %#ok<AGROW>

            % Get the Linear Indices for pixel r w.r.t input image
            imnhInds  = np.getNeighborIndices(r);

            for pixel = 1:numel(imnhInds)
                if BW2(imnhInds(pixel))
                    queueOfIndices = [queueOfIndices; imnhInds(pixel)]; %#ok<AGROW>
                    BW2(imnhInds(pixel)) = false;
                end
            end
        end

        pixelIdxList{end+1} = regionLists;
    end
end

numObjs = numel(pixelIdxList);
regionLengths = coder.nullcopy(zeros(numObjs,1));
for idx = 1:numObjs
    pixelIdxList{idx} = sort(pixelIdxList{idx});
    regionLengths(idx) = numel(pixelIdxList{idx});
    regionIndices = [regionIndices; pixelIdxList{idx}]; %#ok<AGROW>
end

%--------------------------------------------------------------------------
function [BW,conn] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(1,2);

if coder.gpu.internal.isGpuEnabled
    validateattributes(varargin{1}, {'logical' 'numeric'}, {'2d','real', 'nonsparse'}, ...
        mfilename, 'BW', 1);
else
    validateattributes(varargin{1}, {'logical' 'numeric'}, {'real', 'nonsparse'}, ...
        mfilename, 'BW', 1);
end

if ~islogical(varargin{1})
    BW = varargin{1} ~= 0;
else
    BW = varargin{1};
end

if nargin < 2
    %BWCONNCOMP(BW)
    if numel(size(BW)) > 2
        for i = coder.unroll(3:numel(size(BW)))
            coder.internal.assert(coder.internal.isConst(size(BW,i)),...
                'MATLAB:images:validate:codegenInputNotConst',...
                sprintf("Dimension %d of BW",i));
        end
    end

    if coder.const(ismatrix(BW))
        conn = 8;
    elseif numel(size(BW)) == 3
        conn = 26;
    else
        conn = conndef(numel(size(BW)), 'maximal');
    end
else
    %BWCONNCOMP(BW,CONN)
    connIn = varargin{2};

    coder.internal.assert(coder.internal.isConst(connIn), ...
        'MATLAB:images:validate:codegenInputNotConst','CONN');

    iptcheckconn(connIn,mfilename,'CONN',2);

    % special case so that we go through the 2D code path for 4 or 8
    % connectivity
    if isequal(connIn, [0 1 0;1 1 1;0 1 0])
        conn = 4;
    elseif isequal(connIn, ones(3))
        conn = 8;
    else
        conn = connIn;
    end
end