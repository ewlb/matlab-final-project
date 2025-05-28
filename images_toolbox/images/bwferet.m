function varargout = bwferet(I, properties)
%BWFERET Measure Feret diameters and angles of image regions.
%
%  OUT = BWFERET(I) measures the maximum Feret Properties of each
%  component (object) in the image. I can be a binary image, connected 
%  component or labeled matrix.
%
%  OUT = BWFERET(BW, PROPERTIES) measures a set of Feret properties of each
%  connected component (object) in the binary image BW, which is a logical
%  array.
%
%  OUT = BWFERET(CC, PROPERTIES) measures a set of Feret properties of each
%  connected component (object) in CC, which is a struct returned by
%  BWCONNCOMP.
%
%  OUT = BWFERET(L, PROPERTIES) measures a set of Feret properties of
%  each labeled component (object) in the label matrix L. Positive integer
%  elements of L correspond to different regions. For example, the set of
%  elements of L equal to 1 corresponds to region 1; the set of elements of
%  L equal to 2 corresponds to region 2; and so on.
%
%  [OUT, L] = BWFERET(...) measures a set of Feret properties of each
%  component (object) in the binary image, connected component or labeled
%  matrix.  This also returns the corresponding label matrix L such that
%  the first value in the table OUT corresponds to the labeled region
%  1, the second value with the labeled region 2 and so on.
%
%  PROPERTIES can be an array of strings, a single character vector, a cell
%  array of character vectors, or 'all'. If PROPERTIES is set to 'all' it
%  returns all the Feret properties mentioned below. If no argument is
%  provided, all maximum Feret properties are given as outputs. The set of
%  valid measurement strings or character vectors includes
%  'MaxFeretProperties', 'MinFeretProperties' and 'all'.
%
%  'MaxFeretProperties' - Outputs all the properties related to maximum 
%                         Feret Diameter.
%      These properties are:
%      MaxDiameter    - Maximum Feret diameter length.
%      MaxAngle       - Angle of maximum Feret diameter with respect to X
%                       axis in degrees. The value lies between 180 to -180
%                       degrees.
%      MaxCoordinates - Endpoint coordinates of maximum Feret diameter.
%
%  'MinFeretProperties' - Outputs all the properties related to minimum 
%                         Feret Diameter.
%      These properties are:
%      MinDiameter    - Minimum Feret diameter length.
%      MinAngle       - Angle of minimum Feret diameter with respect to X
%                       axis in degrees. The value lies between 180 to -180
%                       degrees.
%      MinCoordinates - Endpoint coordinates of minimum Feret diameter.
%
%  Class Support
%  -------------
%  If the first input is BW, BW must be a logical array and it should be 2D.
%  If the first input is CC, CC must be a structure returned by BWCONNCOMP.
%  If the first input is L, L must be real, nonsparse and 2D. L can have 
%  any numeric class. The output OUT is returned as a table.
%
%  Example 1
%  ---------
%  % Calculate the minimum Feret diameter for objects in image
%  
%   I = imread('toyobjects.png');
%   bw = imbinarize(I, 'adaptive');
%   % Retain the two biggest objects in the image
%   bw = bwareafilt(bw, 2);
%   bw = imfill(bw, 'holes');
%   % Calculate the Feret properties of the objects in the image along with
%   % the label matrix
%   [out, L] = bwferet(bw, 'MinFeretProperties');
%
%  Example 2
%  ---------
%  % Plot the maximum Feret diameter for objects in the image
%  
%   % Read an image
%   I = imread('toyobjects.png');
%   % Binarize the image
%   B = imbinarize(I, 'adaptive');
%   % Fill in the holes in the binary image
%   B = imfill(B, 'holes');
%   % Show the image
%   h = imshow(B)
%   ax = h.Parent;
%   % Convert to connected component struct using bwconncomp
%   C = bwconncomp(B);
%   % Calculate Feret Properties
%   F = bwferet(C, 'MaxFeretProperties');
%   hold on 
%   % Display maximum Feret Diameters with their values for each object
%   imdistline(ax, F.MaxCoordinates{1}(:,1), F.MaxCoordinates{1}(:,2)); 
%   imdistline(ax, F.MaxCoordinates{2}(:,1), F.MaxCoordinates{2}(:,2)); 
%   imdistline(ax, F.MaxCoordinates{3}(:,1), F.MaxCoordinates{3}(:,2)); 
%   imdistline(ax, F.MaxCoordinates{4}(:,1), F.MaxCoordinates{4}(:,2)); 
%  
%  See also BWCONNCOMP, BWLABEL, BWLABELN, LABELMATRIX, REGIONPROPS.
 
%  Copyright 2018-2020 The MathWorks, Inc.
 
nargoutchk(0,2);
narginchk(1,2);
 
%Default value
if nargin==1
    properties = 'MaxFeretProperties';
end
matlab.images.internal.errorIfgpuArray(I, properties);  
[CC, L, RequestedProperties, numObjs, numProps] = ParseInputs(I, properties);
 
imageSize = size(L);
 
%Initialize output structures
out = initializeOutput(RequestedProperties, numObjs);
 
% Calculate pixel index list
PixelIdxList = calculateIndexList(CC, L, numObjs);
 
In = cell(1,2);
for i = 1:numObjs
    if ~isempty(PixelIdxList{i})
        [In{:}] = ind2sub(imageSize, PixelIdxList{i});
        pixels = [In{:}];
        pixels = pixels(:,[2 1 3:end]);
        % Adding offsets to calculate the pixel corners
        offsets = [ ...
            0.5  -0.5
            0.5   0.5
            -0.5   0.5
            -0.5  -0.5 ];
        offsets = offsets';
        offsets = reshape(offsets,1,2,[]);
        corners = pixels + offsets;
        corners = permute(corners,[1 3 2]);
        corners = reshape(corners,[],2);
        % Convex Hull
        k = convhull(corners,'Simplify',true);
        hullCorners = corners(k,:);
        % Finding out the antipodal pairs
        apPairs = antipodalPairs(hullCorners);
        
        
        for k = 1 : numProps
            switch RequestedProperties{k}
                case 'MaxFeretProperties'
                    [out.MaxDiameter(i), out.MaxAngle(i), out.MaxCoordinates(i)] = maxFeretDiameter(hullCorners,apPairs);
                case 'MinFeretProperties'
                    [out.MinDiameter(i), out.MinAngle(i), out.MinCoordinates(i)] = minFeretDiameter(hullCorners,apPairs);
            end
        end
    end
end
varargout{1} = out;
if (nargout == 2)
    varargout{2} = L;
end
end
 
function [maxDiameter, maxAngle, maxCoordinates] = maxFeretDiameter(hullCorners, apPairs)
% Calculate maximum Feret Features - MaxDiameter, MaxAngle, MaxCoordinates
point1 = hullCorners(apPairs(:,1),:);
point2 = hullCorners(apPairs(:,2),:);
v = point1 - point2;
distance = hypot(v(:,1),v(:,2));
[maxDiameter,idx] = max(distance, [], 1);
point1_max = point1(idx,:);
point2_max = point2(idx,:);
maxCoordinates = {[point1_max; point2_max]};
e = point2_max - point1_max;
maxAngle = atan2d(e(2),e(1));
end
 
function [minDiameter, minAngle, minCoordinates] = minFeretDiameter(hull_corners, apPairs)
% Calculate minimum Feret Features - MinDiameter, MinAngle, MinCoordinates
N = size(apPairs,1);
P = apPairs(:,1);
Q = apPairs(:,2);
minDiameter = Inf;
 
trianglePoints = [];
 
for k = 1:N
    if k == N
        k1 = 1;
    else
        k1 = k+1;
    end
    
    pt1 = [];
    pt2 = [];
    pt3 = [];
    
    if (P(k) ~= P(k1)) && (Q(k) == Q(k1))
        pt1 = hull_corners(P(k),:);
        pt2 = hull_corners(P(k1),:);
        pt3 = hull_corners(Q(k),:);
        
    elseif (P(k) == P(k1)) && (Q(k) ~= Q(k1))
        pt1 = hull_corners(Q(k),:);
        pt2 = hull_corners(Q(k1),:);
        pt3 = hull_corners(P(k),:);
    end
    
    if ~isempty(pt1)
        % Points pt1, pt2, and pt3 form a possible minimum Feret diameter.
        % Points pt1 and pt2 form an edge parallel to caliper direction.
        % The Feret diameter orthogonal to the pt1-pt2 edge is the height
        % of the triangle with base pt1-pt2.
        area = ((pt2(1) - pt1(1)) * (pt3(2) - pt1(2)) -(pt2(2) - pt1(2)) * (pt3(1) - pt1(1)) ) / 2;
        d_k =  2 * abs(area) / norm(pt1 - pt2);
        
        if d_k < minDiameter
            minDiameter = d_k;
            trianglePoints = [pt1; pt2; pt3];
        end
    end
end
e = trianglePoints(2,:) - trianglePoints(1,:);
thetad = atan2d(e(2),e(1));
minAngle = mod(thetad + 180 + 90,360) - 180;
point1 = trianglePoints(3,:);
x = minDiameter*cosd(minAngle+180)+point1(1);
y = minDiameter*sind(minAngle+180)+point1(2);
point2 = [x y];
minCoordinates = {[point1;point2]};
 
end
 
function pq = antipodalPairs(S)
% For a convex polygon, an antipodal pair of vertices is one where you
% can draw distinct lines of support through each vertex such that the
% lines of support are parallel.
% A line of support is a line that goes through a polygon vertex such
% that the interior of the polygon lies entirely on one side of the line.
 
% This function uses the "ANTIPODAL PAIRS" algorithm, Preparata and
% Shamos, Computational Geometry: An Introduction, Springer-Verlag, 1985,
% p. 174.
 
n = size(S,1);
 
if isequal(S(1,:),S(n,:))
    % The input polygon is closed. Remove the duplicate vertex from the
    % end.
    S(n,:) = [];
    n = n - 1;
end
 
% area calculates the area of the triangle enclosed by S(i,:), S(j,:) &
% S(k,:)
area = @(i,j,k) signedTriangleArea(S(i,:),S(j,:),S(k,:));
% next(p) returns the index of the next vertex of S.
next = @(i) mod(i,n) + 1; p = n;
p0 = next(p);
q = next(p);
 
% The list of antipodal vertices will be stored in the vectors pp and qq.
% Initialise with number of maximum possible combinations
pp = zeros(n*n,1);
qq = zeros(n*n,1);
 
while (area(p,next(p),next(q)) > area(p,next(p),q))
    q = next(q);
end
q0 = q;
i = 1;
while (q ~= p0)
    p = next(p);
    % (p,q) is an antipodal pair.
    pp(i) = p;
    qq(i) = q;
    i = i+1;
    
    while (area(p,next(p),next(q)) > area(p,next(p),q))
        q = next(q);
        if ~isequal([p q],[q0,p0])
            pp(i) = p;
            qq(i) = q;
            i = i+1;
        else
            break
        end
    end
    % Check for parallel edges.
    if (area(p,next(p),next(q)) == area(p,next(p),q))
        if ~isequal([p q],[q0 n])
            % (p,next(q)) is an antipodal pair.
            pp(i) = p;
            qq(i) = next(q);
            i = i +1;
        else
            break
        end
    end
end
% Remove unused part of the array pp & qq
pp = pp(pp~=0);
qq = qq(qq~=0);
% pq are the antipodal pairs
pq = [pp qq];
end
 
function area = signedTriangleArea(A,B,C)
% Function to calculate the area of triangle formed by A, B & C as vertices
area = ( (B(1) - A(1)) * (C(2) - A(2)) - ...
    (B(2) - A(2)) * (C(1) - A(1)) ) / 2;
end
 
%Parsing function
function [CC, L, RequestedProperties, numObjs, numProps] = ParseInputs(I, properties)
 
if islogical(I) || isstruct(I)
    if islogical(I)
        %bwferet(BW,...)
        CC = bwconncomp(I);
    else
        %bwferet(CC,...)
        CC = I;
        checkCC(CC);
    end
    L = labelmatrix(CC);
else
    %bwferet(L,...)
    CC = [];
    L = I;
    
end
supportedTypes = {'uint8','uint16','uint32','int8','int16','int32','single','double'};
supportedAttributes = {'real','nonsparse','finite', '2d'};
validateattributes(L, supportedTypes, supportedAttributes, ...
    mfilename, 'Image');
if isempty(L)
    numObjs = 0;
else
    numObjs = max( 0, floor(double(max(L(:)))) );
end
 
allStats = {
    'MaxFeretProperties'
    'MinFeretProperties'};
numProperties = numel(properties);
propList = cell(1, numProperties);
validateattributes(properties, {'cell','string','char'}, {'nonempty'}, mfilename, 'PROPERTIES');
    %BWFERET(I,PROPERTIES)
    if iscell(properties)
        %BWFERET(...,PROPERTIES)
        if strcmp(properties{1}, 'all')
            propList = allStats;
        else
            propList = properties;
        end
    elseif strcmpi(properties, 'all')
        %BWFERET(...,'all')
        propList = allStats;
    elseif ischar(properties)
        propList = {properties};
    elseif isstring(properties)
        for i=1:numProperties
            propList{1,i} = properties(i);
        end
    else
        propList = {};
    end
 
numProps = length(propList);
RequestedProperties = cell(1, numProps);
for k = 1 : numProps
    if ischar(propList{k})||isstring(propList{k})
        prop = validatestring(propList{k}, allStats, mfilename, ...
            'PROPERTIES', k+1);
        RequestedProperties{k} = prop;
    end
end
RequestedProperties = unique(RequestedProperties);
numProps = length(RequestedProperties);
end
 
function out = initializeOutput(RequestedProperties, numObjs)
if any(strcmp(RequestedProperties, 'MaxFeretProperties'))
    MaxDiameter = zeros(numObjs,1);
    MaxAngle = zeros(numObjs,1);
    MaxCoordinates = cell(numObjs,1);
    for x=1:numObjs
        MaxCoordinates{x} = [0,0;0,0];
    end
end
if any(strcmp(RequestedProperties, 'MinFeretProperties'))
    MinDiameter = zeros(numObjs,1);
    MinAngle = zeros(numObjs,1);
    MinCoordinates = cell(numObjs,1);
    for x=1:numObjs
        MinCoordinates{x} = [0,0;0,0];
    end
end
% Convert the properties to a table
if length(RequestedProperties)==2 %If both max and min Feret properties are requested
    out = table(MaxDiameter, MaxAngle, MaxCoordinates, MinDiameter, MinAngle, MinCoordinates);
elseif strcmp(RequestedProperties, 'MinFeretProperties') %min Feret properties are requested
    out = table(MinDiameter, MinAngle, MinCoordinates);
else %max Feret properties are requested
    out = table(MaxDiameter, MaxAngle, MaxCoordinates);
end
end
 
function PixelIdxList = calculateIndexList(CC, L, numObjs)
if numObjs ~= 0
    if ~isempty(CC)
        idxList = CC.PixelIdxList;
    else
        idxList = images.internal.builtins.label2idx(L, double(numObjs));
    end
    PixelIdxList = cell(1, numObjs);
    [PixelIdxList{:}] = deal(idxList{:});
else
    PixelIdxList = {};
end
end