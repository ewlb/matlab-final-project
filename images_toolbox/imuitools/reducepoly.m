function posreduced = reducepoly(pos, varargin)
%REDUCEPOLY Reduce density of points in array.
%
%   P_reduced = REDUCEPOLY(P) reduces the density of points in array P.
%   Specify P as an n-by-2 array of the form [x1 y1; ...; xn yn], where
%   each row represents a point. For example, P could be the array returned
%   by one of the ROI creation functions, such as DRAWFREEHAND or
%   DRAWPOLYGON. REDUCEPOLY returns P_reduced, an n-by-2 array of points
%   that is typically smaller that P. REDUCEPOLY uses the Douglas-Peucker
%   line simplification algorithm, removing points along a straight line
%   and leaving only knickpoints (points where the line curves).
%
%   P_reduced = REDUCEPOLY(P, TOLERANCE) reduces the density of points in
%   array P, where TOLERANCE specifies how much a point can deviate from a
%   straight line. Specify TOLERANCE in the range [0,1]. A tolerance value
%   of 0 would have a minimum reduction in points. A tolerance value of 1
%   would result in maximum reduction leaving only the end points of the
%   line. The default value for TOLERANCE is 0.001.
%
%   The Douglas-Peucker line simplification algorithm recursively
%   subdivides a shape until a run of points can be replaced by a
%   straight line segment, with no point in that run deviating from the
%   straight line by more than the TOLERANCE.
%
%   Example
%   -------
%   % Read the coins image.
%   I = imread('coins.png');
%
%   % Convert I to a binary image for locating boundaries.
%   bw = imbinarize(I);
%
%   % Obtain boundaries for all coins in the image.
%   [B,L] = bwboundaries(bw,'noholes');
%
%   % Plot the boundary for one coin.
%   imshow(I)
%   hold on;
%   k = 1;
%   boundary = B{k};
%   plot(boundary(:,2), boundary(:,1), 'r', 'LineWidth', 2)
%   hold off;
%
%   % Use REDUCEPOLY to reduce the number of points in the coin boundary.
%   p = [boundary(:,2) boundary(:,1)];
%   tolerance = 0.02; % choose suitable tolerance
%   p_reduced = reducepoly(p,tolerance);
%
%   % Visualize reduced boundary
%   drawpolyline('Position',p_reduced, 'InteractionsAllowed', 'None')
%   
%   See also DRAWPOLYGON, DRAWPOLYLINE, BWBOUNDARIES, POLY2MASK

%   Copyright 2019 The MathWorks, Inc.

% Parse inputs 
narginchk(1,2)

matlab.images.internal.errorIfgpuArray(pos, varargin{:})

[tolerance, pos, isFloat, posdtype] = parseInputs(pos,varargin{:});
n = size(pos,1);

if n <= 1
    posreduced = pos;
else
    posreduced = douglasPeucker(pos, n, tolerance);    
end
if(~isFloat)
    posreduced = cast(posreduced,posdtype);
end
end

function posreduced = douglasPeucker(ptList, n, tolerance)
% If the number of points passed in are less than or equal to 2, no
% simplification is performed and the points are returned as is.
if n <= 2
    posreduced = ptList;
    return;
end

% End points of current recursion
startEnd =  ptList([1,n],:);

% Distance between end points of current recursion
dNode = sqrt((startEnd(2,2) - startEnd(1,2)).^ 2 + (startEnd(2,1) - startEnd(1,1)).^ 2);

% To compute point that is farthest away from end points
d = zeros(n-2,1,'like',ptList);

for k = 2:n-1
    if dNode > eps
        % Compute perpendicular distance from line joining end points to
        % the current point
         d(k) =  abs(det([1 startEnd(1,1) startEnd(1,2); 1 startEnd(2,1) startEnd(2,2); 1 ptList(k,1) ptList(k,2)]))/dNode;
    else
        % For end points that are apart by less than eps, distance from
        % line joining end points to current point is same as distance from
        % one end point to current point.        
        d(k) = sqrt((ptList(k,1)-startEnd(1,1)).^ 2+(ptList(k,2)-startEnd(1,2)).^ 2);
    end
end
% Index of point at maximum distance from end points
idx = find(d == max(d));

% Value of maximum distance from end points
dmax = d(idx);

% Index of first point with maximum distance
farthestIdx = idx(1);

% If farthest distance is greater than tolerance, recursively simplify
if dmax > tolerance
    %Recursive call
    recList1 = douglasPeucker(ptList(1:farthestIdx,:), farthestIdx, tolerance);
    recList2 = douglasPeucker(ptList(farthestIdx:n,:), n-farthestIdx+1, tolerance);
    %Build the result list
    posreduced = [recList1;recList2(2:end,:)];
else
    posreduced = startEnd;
end
end

% To parse input argument position list and optional argument tolerance
function [tolerance, pos, isFloat, posdtype]  = parseInputs(pos,varargin)

defaultTolerance = 0.001; % Small default tolerance
p = inputParser();

p.addRequired('pos',@validatePosition);
p.addOptional('tolerance',defaultTolerance, @validateTolerance);
p.parse(pos,varargin{:});
posdtype = class(pos);
isFloat = isfloat(pos);

tolerance = p.Results.tolerance;

if(~isFloat)
    pos = single(pos);
end
if(~isfloat(tolerance))
    tolerance = single(tolerance);
end
% Calculate scaling to be the diagonal of the bounding box that fits the
% polygon data
if(isempty(pos))
    scaling = 0;
else
    a = min(pos);
    b = max(pos);
    scaling = norm(b-a);
end
% Normalize tolerance according to scaling factor
if (tolerance == 0)
    tolerance = tolerance + eps;
end   
tolerance = tolerance * scaling;

end

function TF = validatePosition(pos)

if(isempty(pos))
    TF = true;
    return
end
validPosTypes = {'numeric'};
attributes = {'real','ncols',2,'nonnan','finite','nonsparse'};
validateattributes(pos, validPosTypes, attributes);
TF = true;

end

function TF = validateTolerance(x)

validTolerance = {'numeric'};
attributes = {'nonnan','finite','>=',0,'<=',1,'real','scalar','nonsparse'};

validateattributes(x, validTolerance, attributes);
TF = true;

end



