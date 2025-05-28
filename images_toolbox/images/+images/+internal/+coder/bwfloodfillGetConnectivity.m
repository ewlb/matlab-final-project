function modeFlag = bwfloodfillGetConnectivity(connb, I) %#codegen
% This function checks connectivity of a given connectivity matrix
% for 2D image I, modeFlag could be 4/8 depending on connectivity
% for 3D image I, modeFlag could be 6/18/26 depending on connectivity
% modeFlag will be 0 if custom connectivity matrix is used

% Copyright 2020 The MathWorks, Inc.

coder.inline('always');

conn18side = logical([0 1 0; 1 1 1; 0 1 0]);
conn18middle = true(3);
conn18 = cat(3,conn18side,conn18middle,conn18side);

modeFlag = 0; % Default mode

if ismatrix(I) % for 2D image, set mode to 4 or 8 according to connectivity
    if(isequal(connb,4) || isequal(connb, conndef(2,'minimal')))
        modeFlag = 4;   % 4 connectivity, 2D
    elseif(isequal(connb,8) || isequal(connb, conndef(2,'maximal')))
        modeFlag = 8;   % 8 connectivity, 2D
    end
else      % for 3D image, set mode to 6, 18 or 26 according to connectivity
    if(isequal(connb,6) || isequal(connb, conndef(3,'minimal')))
        modeFlag = 6;   % 6 connectivity, 3D
    elseif(isequal(connb,18) || isequal(connb, conn18))
        modeFlag = 18;  % 18 connectivity, 3D
    elseif(isequal(connb,26) || isequal(connb, conndef(3,'maximal')))
        modeFlag = 26;  % 26 connectivity, 3D
    end
end
end
