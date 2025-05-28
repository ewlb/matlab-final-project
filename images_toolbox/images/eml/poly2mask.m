function BW = poly2mask(x,y,M,N) %#codegen
%POLY2MASK Convert region-of-interest polygon to mask.
%
%  Syntax
%  ------
%
%  BW = poly2mask(x,y,M,N)
%
%  Input Specs
%  ------------
%
%  x,y:
%     real, vector, finite
%     finite vector
%     'double'
%
% M,N :
%     positive integer
%
%  Output Specs
%  ------------
%
%  BW:
%     logical

% Copyright 2021 The MathWorks, Inc.

%#ok<*EMCA>

% Check that the number of inputs is 4
% Syntax is poly2mask(x,y,M,N)
narginchk(4,4);

validateattributes(x,{'double'},{},mfilename,'X',1);
validateattributes(y,{'double'},{},mfilename,'Y',2);

coder.internal.errorIf(length(x) ~=length(y),...
    'images:poly2mask:vectorSizeMismatch');

if isempty(x) || isempty(y)
    BW = false(M,N);
    return;
end

validateattributes(x,{'double'},{'real','vector','nonnan','finite','nonsparse'},mfilename,'X',1);
validateattributes(y,{'double'},{'real','vector','nonnan','finite','nonsparse'},mfilename,'Y',2);
validateattributes(M,{'double'},{'real','integer','nonnegative','scalar','nonsparse','nonempty'},mfilename,'M',3);
validateattributes(N,{'double'},{'real','integer','nonnegative','scalar','nonsparse','nonempty'},mfilename,'N',4);

newLength = numel(x)+1;
xNew = zeros(1,newLength);
yNew = zeros(1,newLength);
if (x(end) ~= x(1)) || (y(end) ~= y(1))
    xNew(1:end-1) = x(1:end);
    xNew(end) =x(1);
    yNew(1:end-1) = y(1:end);
    yNew(end) =y(1);
    BW = poly2MaskFromIntegralImagePortable(xNew,yNew, uint32(M),uint32(N));
else
    BW = poly2MaskFromIntegralImagePortable(x,y, uint32(M),uint32(N));
end

end

%--------------------------------------------------------------------------
% This function generates the portable code for poly2mask function which
% converts polygon poinnts into mask
function out = poly2MaskFromIntegralImagePortable(xpt,ypt, M,N)
coder.inline('always');
coder.internal.prefer_const(xpt, ypt, M, N);
scale = 5.0;
[edgeRows, edgeColumns] = size(xpt);
sizeX = uint32(edgeRows*edgeColumns);
x= zeros(1,sizeX,'double');
y= zeros(1,sizeX,'double');
i=1;
for c= 1:edgeColumns
    for r =1:edgeRows
        x(c+r-1)=xpt(i);
        y(c+r-1)=ypt(i);
        i=i+1;
    end
end

mInt = int32(M);
nInt = int32(N);

minY = zeros(1,N,'int32');
maxY = zeros(1,N,'int32');
out = false(M,N);
% creates edges in mask to be used during parity scan
[out,minY,maxY]  = poly2edgelist(x, y, sizeX, scale, mInt, nInt, out, minY, maxY);
% Performs the parity scan over output mask 'out'
out = parityScan(out, nInt, minY, maxY);
end

%--------------------------------------------------------------------------
% creates edges in mask to be used during parity scan
function [out, minY,maxY]  = poly2edgelist(x, y, xLength, scale, M, N, out,minY, maxY)
borderSize = int32(0);
for i=1:xLength
    x(i) = floor(scale *(x(i)-0.5)+0.5) + 1.0;
    y(i) = floor(scale *(y(i)-0.5)+0.5) + 1.0;
    if i>1
        tempDX = int32(abs(x(i)-x(i-1)));
        tempDY = int32(abs(y(i)-y(i-1)));
        if tempDX >= tempDY

            borderSize= borderSize + tempDX + 1;
        else
            borderSize = borderSize + tempDY + 1;
        end

    end
end

% Fill xLinePts and yLinePts with border information
[xLinePts, yLinePts] = makeBorder(x,y,xLength, borderSize);

for pt=1:borderSize-1
    %Check if x  changes
    diff = double(xLinePts(pt + 1) - xLinePts(pt));
    if abs(diff) >= 1
        yLinePts(pt) =min(yLinePts(pt),yLinePts(pt+1));
        if (diff<0)
            xLinePts(pt) = xLinePts(pt) -1;
        end
        scaledDown = (xLinePts(pt) + (scale-1)/2)/scale;
        if abs(scaledDown - floor(scaledDown)) < 1 / (scale*50)
            xLinePts(pt) = scaledDown;
            yLinePts(pt) = ceil((yLinePts(pt) + (scale - 1.0) / 2.0) / scale);
            %Set xUse and yUse to these scaled down x and y values for
            % indexing into the boolean array.
            xUse = int32(xLinePts(pt)) + int32(1);
            yUse = int32(yLinePts(pt)) + int32(1);
            if ~(xUse < 2 || xUse > N+1)
                if (yUse > M+1)
                    if minY(xUse-1) == 0
                        minY(xUse-1)= M+1;
                    else
                        minY(xUse-1)= min(minY(xUse-1),M+1);
                    end
                    if maxY(xUse-1) == 0
                        maxY(xUse-1)= M+1;
                    else
                        maxY(xUse-1)= max(maxY(xUse-1),M+1);
                    end
                else
                    yUse = max(2,yUse);
                    out(yUse-1,xUse-1) = ~(out(yUse-1,xUse-1));
                    if minY(xUse-1) == 0
                        minY(xUse-1)= yUse-1;
                    else
                        minY(xUse-1)= min(minY(xUse-1),yUse-1);
                    end
                    if maxY(xUse-1) == 0
                        maxY(xUse-1)= yUse;
                    else
                        maxY(xUse-1)= max(maxY(xUse-1),yUse);
                    end
                end
            end

        end
    end

end
end

%--------------------------------------------------------------------------
% This function fills in the yLinePts and xLinePts arrays to give the
% informtion necessary rto create the borders
function [xLinePts, yLinePts] = makeBorder(x,y,xLength, borderSize)
% Create vectors of the size 'borderSize' to hold the border points of
% mask
yLinePts =  zeros(1,borderSize,'double');
xLinePts =  zeros(1,borderSize,'double');
%inlining of the makeBorder function in the generated code
coder.inline('always');
borderPosition = int32(1) ;
for i= 2:xLength
    [xLinePts, yLinePts,borderPosition] = intLine(x(i-1),y(i-1),x(i),y(i), xLinePts, yLinePts,borderPosition);
end
end

%--------------------------------------------------------------------------
%  Creates x y pairs in the form of two vectors, xLinePts and yLinePts.
function [xLinePts, yLinePts, borderPosition]  = intLine(x1,y1,x2,y2,xLinePts, yLinePts, borderPosition)
coder.inline('always');
dx = int32(abs(x2-x1));
dy = int32(abs(y2-y1));
if (dx == 0) && (dy==0)
    xLinePts(borderPosition) = (x1);
    yLinePts(borderPosition) = (y1);
    borderPosition = borderPosition+1;
    return;
end
if dx >= dy
    %calculate slope
    m = double((y2-y1)/(x2-x1));

    if x2 > x1
        for xVal = x1 : x2
            yVal = round(y1 + m*(xVal-x1));
            xLinePts(borderPosition) = (xVal);
            yLinePts(borderPosition) = (yVal);
            borderPosition = borderPosition+1;
        end
    else
        for xVal = x1:-1:x2

            yVal = round(y1 + m*(xVal-x1));
            xLinePts(borderPosition) = (xVal);
            yLinePts(borderPosition) = (yVal);
            borderPosition = borderPosition+1;
        end
    end
else
    % if y changes the most we step along y
    m = double((x2-x1)/(y2-y1));
    if y2 > y1
        for yVal = y1 : y2
            xVal = round(x1 + m*(yVal-y1));
            xLinePts(borderPosition) = (xVal);
            yLinePts(borderPosition) = (yVal);
            borderPosition = borderPosition+1;
        end
    else
        for yVal = y1:-1:y2
            xVal = round(x1 + m*(yVal-y1));
            xLinePts(borderPosition) = (xVal);
            yLinePts(borderPosition) = (yVal);
            borderPosition = borderPosition+1;
        end
    end
end
end

%--------------------------------------------------------------------------
% Performs the parity scan over output mask 'out'
function out = parityScan(out, N,minY, maxY)
for c=1:N
    pixel=false;
    for r = minY(c):maxY(c)-1
        if out(r,c)
            pixel = ~pixel;
        end
        out(r,c) = pixel;
    end
end
end