function posreduced = reducepoly(pos, varargin) %#codegen
%REDUCEPOLY Reduce polygon vertices using Douglas-Peucker algorithm.

%   Copyright 2019 The MathWorks, Inc.

narginchk(1,2) 

% Validate position
if(~isempty(pos))
    validateattributes(pos, {'numeric'}, {'real','ncols',2,'nonnan','finite','nonsparse'});
end

% Validate tolerance
% second argument tolerance not empty
if(nargin == 2) 
    tolerance = varargin{:};
    validateattributes(tolerance, {'numeric'}, {'nonnan','finite','>=',0,'<=',1,'real','scalar','nonsparse'});
else
    tolerance = 0.001; % Small default tolerance
end

posdtype = class(pos);
isFloat = isfloat(pos);

if(~isFloat)
    % To allow assignment after casting for codegen purposes
    posFloat = cast(pos,'single'); 
else
    posFloat = pos;
end
if(~isfloat(tolerance))
    % To allow assignment after casting for codegen purposes
    toleranceFloat = cast(tolerance, 'single'); 
else
    toleranceFloat = tolerance;
end

% Calculate scaling to be the diagonal of the bounding box that fits the
% polygon data
if(isempty(posFloat))
    scaling = 0;
else
    a = min(posFloat, [],1);
    b = max(posFloat, [], 1);
    scaling = norm(b-a);
end

% Normalize tolerance according to scaling factor
toleranceFloat = (toleranceFloat) * scaling;

n = size(posFloat,1);
posnew = posFloat;
coder.varsize('posnew');
if n <= 1
    posreducedFloat = posnew;
else
    posreducedFloat = douglasPeucker(posnew, n, toleranceFloat);
    
end

if(~isFloat)
    % To allow assignment after casting for codegen purposes
    posreduced = cast(posreducedFloat,posdtype);
else
    posreduced = posreducedFloat;
end
end

function posreduced = douglasPeucker(ptList, n, tolerance)
% If the number of points passed in are less than or equal to 2, no
% simplification is performed and the points are returned as is.
if n <= 2 
    posreduced = ptList;
    return;
end

% End points
startEnd =  ptList([1,n],:);

% Distance between end points of current recursion
dNode = sqrt((startEnd(2,2) - startEnd(1,2)).^ 2 + (startEnd(2,1) - startEnd(1,1)).^ 2);

% Placeholder for maximum distance from end points.
dmax = cast(-inf,'like',ptList);

farthestIdx = 0;

% Loop to find point farthest from end points
for k = 2:n-1
    if dNode > eps
        % Compute perpendicular distance from line joining end points to
        % the current point
        d = abs(det([1 startEnd(1,1) startEnd(1,2); 1 startEnd(2,1) startEnd(2,2); 1 ptList(k,1) ptList(k,2)]))/dNode;        
    else
        % For end points that are apart by less than eps, distance from
        % line joining end points to current point is same as distance from
        % one end point to current point.
        d = sqrt((ptList(k,1)-startEnd(1,1)).^ 2+(ptList(k,2)-startEnd(1,2)).^ 2);
    end    
    if d > dmax
        % Value of maximum distance from end point
        dmax = d; 
        % Index of point with maximum distance  
        farthestIdx = k;       
    end
end

% If farthest distance is greater than tolerance, recursively simplify
if dmax > tolerance
    % Recursive call to douglasPeucker
    recList1 = douglasPeucker(ptList(1:farthestIdx,:), farthestIdx, tolerance);
    recList2 = douglasPeucker(ptList(farthestIdx:n,:), n-farthestIdx+1, tolerance);
    % Build the result list
    posreduced = [recList1;recList2(2:end,:)];
else
    posreduced = startEnd;
end
end





