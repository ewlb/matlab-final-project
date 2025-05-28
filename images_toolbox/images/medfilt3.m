function B = medfilt3(A, filterSize, padopt)
%MEDFILT3 3-D median filtering
%
%   B = MEDFILT3(A) filters 3-D image A with a 3-by-3-by-3 median filter.
%
%   B = MEDFILT3(A,[M N P]) performs median filtering of the 3-D image A
%   in three dimensions. Each output voxel in B contains the median value
%   in the M-by-N-by-P neighborhood around the corresponding voxel in A.
%   M, N and P must be odd integers. The default neighborhood size is
%   [3 3 3]. A is padded by mirroring border elements.
%
%   B = MEDFILT3(...,PADOPT) controls how the array boundaries are padded.
%   Possible values of PADOPT are:
%
%       'symmetric': Pad array with mirror reflections of itself (default)
%       'replicate': Pad array by repeating border elements
%       'zeros'    : Pad array with 0s
%
%   Class Support
%   -------------
%   A must be a real, non-sparse 3-D array of class logical or numeric.
%   B is of the same class and has the same size as A. The neighborhood
%   size [M N P] must be a vector of positive, integral, odd, numeric
%   values.
%
%   Notes
%   -----
%   If the input image A is of integer class, all of the output values are
%   returned as integers.
%
%   Example
%   -------
%   % Use median filtering to remove outliers in 3-D data
%
%     % Create a noisy 3-D volume
%     load mristack;
%     noisyV = imnoise(mristack,'salt & pepper',0.2);
%
%     % Apply median filtering
%     filteredV = medfilt3(noisyV);
%
%     %Display noisy and filtered volumes
%     figure, volshow(noisyV);
%     figure, volshow(filteredV);
%
%   See also MEDFILT2.

%   Copyright 2016-2020 The MathWorks, Inc.

arguments
    A
    filterSize = missing
    padopt = missing
end

if ismissing(filterSize)
    filterSize = [3 3 3];
    padopt = 'symmetric';
elseif ~isnumeric(filterSize) && nargin==2
    % medfilt2(A, PADOPT) syntax
    padopt = filterSize;
    filterSize = [3 3];
elseif ~isnumeric(filterSize) && nargin==3
    % medfilt2(A, PADOPT, MN) syntax
    t = filterSize;
    filterSize = padopt;
    padopt = t;
end
if ismissing(padopt)
    padopt = 'symmetric';
end

validateattributes(A, ...
    {'numeric','logical'}, ...
    {'3d','real','nonsparse'}, ...
    mfilename, 'A', 1);

validateattributes(filterSize, ...
    {'numeric'}, ...
    {'real','positive','odd','integer','vector','numel',3}, ...
    mfilename, ...
    '[m n p]');
filterSize = reshape(double(filterSize), [1,numel(filterSize)]);

options = {'replicate', 'zeros', 'symmetric'};
padopt = validatestring(padopt, options, mfilename, 'PADOPT');
padMap = containers.Map( ...
    {'zeros', 'indexed', 'replicate', 'symmetric'}, ...
    {0, 1, 2, 3});


if isempty(A)
    B = A;
    return
end

if ismatrix(A)
    B = medfilt2(A, filterSize(1:2), padopt);

else
    if all(filterSize <= 31) % win64, core004.
        B = images.internal.builtins.mwmedfilt3(A, filterSize, padMap(padopt));
        
    else
        imageSize = size(A);
        radius = (filterSize - 1) / 2;
        % Pad image when filterSize > 2*dimension+1
        if(ndims(A)==3)
            if (any(radius > imageSize))
                padSize = radius - imageSize;
                padSize = max(padSize,0);
                A = padarray(A,padSize,padopt);
            end
        end
        
        numPhysicalCores = feature('numthreads');
        use_cst_algorithm = (isa(A, 'uint8') || isa(A, 'int8') || isa(A, 'logical'));
        B = images.internal.builtins.medianfilter3d(A, radius, padMap(padopt), use_cst_algorithm, numPhysicalCores);
        if (any(size(B)>imageSize))
            padAmt = size(B) - imageSize;
            % Extracting the central portion of the image such that size of output is
            % same as input
            B = B(1+padAmt(1)/2:end-padAmt(1)/2,1+padAmt(2)/2:end-padAmt(2)/2,...
                1+padAmt(3)/2:end-padAmt(3)/2);
        end
    end
end
end
