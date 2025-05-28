function [B,L,N,A] = bwboundaries(BW,optionalArg1,optionalArg2,options)
%BWBOUNDARIES Trace region boundaries in binary image.
%   B = BWBOUNDARIES(BW) traces the exterior boundary of objects, as well
%   as boundaries of holes inside these objects. It also descends into the
%   outermost objects (parents) and traces their children (objects
%   completely enclosed by the parents). BW must be a binary image where
%   nonzero pixels belong to an object and 0-pixels constitute the
%   background. B is a P-by-1 cell array, where P is the number of objects
%   and holes. Each cell contains a Q-by-2 matrix, where Q is the number of
%   boundary pixels for the corresponding region. Each row of these Q-by-2
%   matrices contains the row and column coordinates of a boundary pixel.
%   The coordinates are ordered in a clockwise direction.
%
%   B = BWBOUNDARIES(BW,CONN) specifies the connectivity to use when
%   tracing parent and child boundaries. CONN may be either 8 or 4. The
%   default value for CONN is 8.
%
%   B = BWBOUNDARIES(...,OPTIONS) provides an optional string or character
%   vector input and 2 name-value pairs. Character vector 'noholes' speeds
%   up the operation of the algorithm by having it search only for object
%   (parent and child) boundaries. By default, or when 'holes' character
%   vector is specified, the algorithm searches for both object and hole
%   boundaries. The details of the 2 name-value pairs supported are as
%   follows:
%
%    'TraceStyle'           Takes the values 'pixelcenter' or 'pixeledge'
%                           where 'pixelcenter' is the default value. If
%                           'pixelcenter' is selected, boundary pixels are
%                           identified, and the boundary is drawn through
%                           these pixels' center coordinates. If
%                           'pixeledge' is selected, boundary pixels are
%                           identified and the boundary is drawn through
%                           these pixels' edges.
%    
%    'CoordinateOrder'      Defines the order of vertex coordinates to be
%                           outputted by taking either of the values 'xy'
%                           or 'yx'. If 'xy' is selected, each polygon
%                           vertex is of the format (x,y). If 'yx' is
%                           selected, the format of each polygon vertex is
%                           (y,x). The default value is 'yx'.
%
%   [B,L] = BWBOUNDARIES(...) returns the label matrix, L, as the second
%   output argument. Objects and holes are labeled. L is a two-dimensional
%   array of nonnegative integers that represent contiguous regions. The
%   k-th region includes all elements in L that have value k. The number of
%   objects and holes represented by L is equal to max(L(:)). The
%   zero-valued elements of L make up the background.
%
%   [B,L,N,A] = BWBOUNDARIES(...) returns N, the number of objects found,
%   and A, the adjacency matrix. The first N cells in B are object
%   boundaries and the remaining cells are hole boundaries. A represents
%   the parent-child dependencies between object boundaries and hole
%   boundaries. A is a square, sparse, logical matrix with side of length
%   length(B), the total number of boundaries, whose rows and columns
%   correspond to the position of boundaries stored in B. A(i,j)=1 means
%   that boundary i is enclosed by (or a child of) boundary j.
%
%   The boundaries that enclose or are enclosed by the k-th boundary can be
%   found using A as follows:
%
%      enclosing_boundary  = find(A(k,:));
%      enclosed_boundaries = find(A(:,k));
%
%   Class Support
%   -------------
%   BW can be logical or numeric and it must be real, 2-D, and nonsparse.
%   L, and N are double. A is sparse logical.
%
%   Example 1
%   ---------
%   % Read in and threshold the rice.png image. Display the labeled
%   % objects using the jet colormap, on a gray background, with region
%   % boundaries outlined in white.
%
%      I = imread('rice.png');
%      BW = imbinarize(I);
%      [B,L] = bwboundaries(BW,'noholes');
%      imshow(label2rgb(L, @jet, [.5 .5 .5]))
%      hold on
%      for k = 1:length(B)
%          boundary = B{k};
%          plot(boundary(:,2), boundary(:,1), 'w', 'LineWidth', 2)
%      end
%
%   Example 2
%   ---------
%   % Read in and display binary image blobs.png. Overlay the region
%   % boundaries on the image. Display text showing the region number
%   % (based on the label matrix), next to every boundary. Additionally,
%   % display the adjacency matrix using SPY.
%
%   % HINT: After the image is displayed, use the zoom tool in order to
%   % read individual labels.
%
%      BW = imread('blobs.png');
%      [B,L,N,A] = bwboundaries(BW);
%      figure;
%      imshow(BW);
%      hold on;
%      colors = ['b' 'g' 'r' 'c' 'm' 'y'];
%      for k = 1:length(B),
%          boundary = B{k};
%          cidx = mod(k,length(colors))+1;
%          plot(boundary(:,2), boundary(:,1), colors(cidx), 'LineWidth',2);
%          % Randomize text position for better visibility
%          rndRow = ceil(length(boundary)/(mod(rand*k,7)+1));
%          col = boundary(rndRow,2); row = boundary(rndRow,1);
%          h = text(col+1, row-1, num2str(L(row,col)));
%          set(h,'Color',colors(cidx),'FontSize',14,'FontWeight','bold');
%      end
%      figure;
%      spy(A);
%
%   Example 3
%   ---------
%   % Display all object boundaries in red and all hole boundaries in green.
%
%      BW = imread('blobs.png');
%      [B,L,N] = bwboundaries(BW);
%      figure;
%      imshow(BW);
%      hold on;
%      for k = 1:length(B),
%          boundary = B{k};
%          if(k > N)
%              plot(boundary(:,2), boundary(:,1), 'g', 'LineWidth', 2);
%          else
%              plot(boundary(:,2), boundary(:,1), 'r', 'LineWidth', 2);
%          end
%      end
%
%   Example 4
%   ---------
%   % Display parent boundaries in red and their holes in green.
%
%      BW = imread('blobs.png');
%      [B,L,N,A] = bwboundaries(BW);
%      figure;
%      imshow(BW);
%      hold on;
%      % Loop through object boundaries
%      for k = 1:N
%          % Boundary k is the parent of a hole if the k-th column
%          % of the adjacency matrix A contains a non-zero element
%          if nnz(A(:,k)) > 0
%              boundary = B{k};
%              plot(boundary(:,2), boundary(:,1), 'r', 'LineWidth', 2);
%              % Loop through the children of boundary k
%              for l = find(A(:,k))'
%                  boundary = B{l};
%                  plot(boundary(:,2), boundary(:,1), 'g', 'LineWidth', 2);
%              end
%          end
%      end
%
%   See also BWLABEL, BWLABELN, BWPERIM, BWTRACEBOUNDARY.

%   Copyright 1993-2022 The MathWorks, Inc.

arguments
    BW          
    optionalArg1         = 8
    optionalArg2    {mustBeNonzeroLengthText} = 'holes'
    options.TraceStyle {mustBeNonzeroLengthText} = 'PixelCenter'
    options.CoordinateOrder {mustBeNonzeroLengthText} = 'yx'
end

% raise error if gpu array input
matlab.images.internal.errorIfgpuArray(BW);
matlab.images.internal.errorIfgpuArray(optionalArg1);

% convert to string
parsedArgs = matlab.images.internal.stringToChar({BW, optionalArg1, optionalArg2});
BW = parsedArgs{1};
optionalArg1 = parsedArgs{2};
optionalArg2 = parsedArgs{3};

% parse connectivity, holeFlag arguments
if nargin == 2
    if ischar(optionalArg1)
        holeFlag = optionalArg1;
        conn = 8; % default
    else
        conn = optionalArg1;
        holeFlag = 'holes'; % default
    end
else
    % default arguments assigned in arguments block
    % if nargin == 1, default args assigned here
    % if nargin == 3, user args assigned here
    conn = optionalArg1;
    holeFlag = optionalArg2;
end

% validate BW
validateattributes(BW, {'numeric','logical'}, {'real','2d','nonsparse'}, ...
    mfilename, 'BW', 1);

% validate connectivity
coder.internal.errorIf(conn~=4 && conn ~= 8, ...
    'images:bwboundaries:badScalarConn');

% validate hole flags
validHoleFlags = ["holes", "noholes"];
holeFlag = validatestring(holeFlag, validHoleFlags);

% validate trace style
validTraceStyles = ["PixelCenter", "PixelEdge"];
options.TraceStyle = validatestring(options.TraceStyle, validTraceStyles);

% validate coordinate order
validCoordOrders = ["xy", "yx"];
options.CoordinateOrder = validatestring(options.CoordinateOrder, validCoordOrders);

if ~islogical(BW)
    BW = (BW ~= 0); % handle NaN's as 1's
end

findHoles = strcmp(holeFlag,'holes');

L = bwlabel(BW, conn);
if strcmp(options.TraceStyle,'PixelEdge')
    objs = images.internal.builtins.bwborders(L, conn);
else
    objs = images.internal.builtins.bwboundaries(L, conn);
end

if (findHoles)
    [holes, labeledHoles] = findHoleBoundariesSim(BW, conn, options);
    if (nargout > 1)
        % Generate combined holes+objects label matrix
        L = L + (labeledHoles~=0)*length(objs) + labeledHoles;
    end
    % Concatenate cells vertically
    B = vertConcatenateCells(objs,holes);
else
    B = objs;
end
N = length(objs);

if(nargout > 3)
    % Produce an adjacency matrix showing parent-hole-child relationships
    if (length(B)*length(B) > intmax('int32'))
        % Array size limitations in MATLAB Coder
        % force us to use slower MATLAB code.
        % Display a warning message to say it's gonna be a while.
        warning(message('images:bwboundaries:largeNumberOfObjects', ...
            'BW',num2str(length(B))))
        A = CreateAdjMatrix(B,N);
    else
        % Call the MEX auto-generated with MATLAB Coder
        A = sparse(cg_adjacencyMatrix_double(B,N));
    end
end

% change coordinate order to xy if prompted so
if strcmp(options.CoordinateOrder, 'xy')
    B = cellfun(@(x) x(:,[2,1]), B, 'UniformOutput', false);
end

%--------------------------------------------------------------------------
function [B, L] = findHoleBoundariesSim(BW, conn, options)

% Avoid topological errors.  If objects are 8 connected, then holes
% must be 4 connected and vice versa.
if (conn == 4)
    backgroundConn = 8;
else
    backgroundConn = 4;
end

% Turn holes into objects
BWcomplement = imcomplement(BW);

% clear unwanted "hole" objects from the border
BWholes = imclearborder(BWcomplement, backgroundConn);

% get the holes!
L = bwlabel(BWholes, backgroundConn);

% boundary tracing based on pixel edge or pixel center
if strcmp(options.TraceStyle,'PixelEdge')
    B = images.internal.builtins.bwborders(L, backgroundConn);
else
    B = images.internal.builtins.bwboundaries(L, backgroundConn);
end
% %--------------------------------------------------------------------------
function C = vertConcatenateCells(A,B)

if coder.target('MATLAB')
    C = [A;B];
else
    % Workaround for g1134623
    N = size(A,1);
    M = size(B,1);
    P = size(A,2);

    C = coder.nullcopy(cell(N+M,P));
    for k = 1:N
        C{k} = A{k};
    end
    for k = 1:M
        C{k+N} = B{k};
    end
end

%--------------------------------------------------------------------------
function A = CreateAdjMatrix(B, numObjs)

A = sparse(false(length(B)));

levelCellArray = GroupBoundariesByTreeLevel(B, numObjs);

% scan through all the level pairs
for k = 1:length(levelCellArray)-1

    parentsIdx = levelCellArray{k};     % outside boundaries
    childrenIdx = levelCellArray{k+1};  % inside boundaries

    parents  = B(parentsIdx);
    children = B(childrenIdx);

    sampChildren = GetSamplePointsFromBoundaries(children);

    for m = 1:length(parents)
        parent = parents{m};
        inside = inpolygon(sampChildren(:,2), sampChildren(:,1),...
            parent(:,2), parent(:,1));
        % casting to logical is necessary because of the bug, see GECK #137394
        inside = logical(inside);
        A(childrenIdx(inside), parentsIdx(m)) = true;
    end

end

%--------------------------------------------------------------------------
% Produces a cell array of indices into the boundaries cell array B.  The
% first element of the output cell array holds a double array of indices
% of boundaries which are the outermost (first layer of an onion), the
% second holds the second layer, and so on.
function idxGroupedByLevel = GroupBoundariesByTreeLevel(B, numObjs)

processHoles = ~(length(B) == numObjs);

% parse the input
objIdx  = 1:numObjs;
objs  = B(objIdx);

if processHoles
    holeIdx = numObjs+1:length(B);
    holes = B(holeIdx);
else
    holes = {};
end

% initialize output and loop control variables
idxGroupedByLevel = {};
done     = false;
findHole = false; % start with an object boundary

while ~done
    if findHole
        I = FindOutermostBoundaries(holes);
        holes = holes(~I); % remove processed boundaries

        idxGroupedByLevel = [ idxGroupedByLevel, {holeIdx(I)} ]; %#ok<AGROW>
        holeIdx = holeIdx(~I);   % remove indices of processed boundaries
    else
        I = FindOutermostBoundaries(objs);
        objs = objs(~I);

        idxGroupedByLevel = [ idxGroupedByLevel, {objIdx(I)} ]; %#ok<AGROW>
        objIdx = objIdx(~I);
    end

    if processHoles
        findHole = ~findHole;
    end

    if (isempty(holes) && isempty(objs))
        done = true;
    end
end

%--------------------------------------------------------------------------
% Returns a logical vector showing the locations of outermost boundaries
% in the input vector (ie 1 for the boundaries that are outermost and
% 0 for all other boundaries)
function I = FindOutermostBoundaries(B)

% Look for parent boundaries
I = false(1,length(B));

for m = 1:length(B)

    boundary = B{m};
    x = boundary(1,2); % grab a sample point for testing
    y = boundary(1,1);

    surrounded = false;
    for n = [1:(m-1), (m+1):length(B)] % exclude boundary under test
        boundary = B{n};
        if inpolygon(x, y, boundary(:,2), boundary(:,1))
            surrounded = true;
            break;
        end
    end
    I(m) = ~surrounded;
end

%--------------------------------------------------------------------------
function points = GetSamplePointsFromBoundaries(B)

points = zeros(length(B),2);

for m = 1:length(B)
    boundary = B{m};
    points(m,:) = boundary(1,:);
end

% LocalWords:  BW noholes th nonsparse imbinarize cidx rndRow conn
