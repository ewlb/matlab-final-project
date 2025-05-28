function checkForInvertedWorldCoordinateSystem(x,y)
% The specification of XData and YData as a plaid meshgrid is an
% undocumented V1 syntax that is tested in the testsuite. If this syntax is
% specified, detect it and convert it to the [min,max] form that is
% documented for validation.

% Copyright 2020 The MathWorks, Inc.


plaidXYGridsSpecified = ~isvector(x);
if plaidXYGridsSpecified
    x = [x(1,1) x(1,end)];
    y = [y(1,1) y(end,1)];
end

worldAndIntrinsicSystemsInverted = (x(2)-x(1)) < 0 || (y(2)-y(1)) < 0;

if worldAndIntrinsicSystemsInverted
    error(message('images:imcrop:invertedWorldCoordinateSystem'));
end

end %checkForInvertedWorldCoordinateSystem