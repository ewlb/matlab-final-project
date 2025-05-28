function ycbcr = rgb2ycbcr(X) %#codegen
%

% Copyright 2013-2024 The MathWorks, Inc.

%#ok<*EMCA>

if (numel(size(X))==2)
    % For backward compatibility, this function handles uint8 and uint16
    % colormaps. This usage will be removed in a future release.

    validateattributes(X, ...
        {'uint8','uint16','single','double'}, ...
        {'nonempty'}, ...
        mfilename, 'MAP', 1);
    coder.internal.errorIf((size(X,2) ~= 3 || size(X,1) < 1), ...
        'images:rgb2ycbcr:invalidSizeForColormap');

    if ~isfloat(X)
        eml_warning('images:rgb2ycbcr:notAValidColormap');
        ycbcr = rgb2ycbcr_core(im2double(X));
    else
        ycbcr = rgb2ycbcr_core(X);
    end

elseif (numel(size(X)) == 3)
    validateattributes(X, ...
        {'uint8','uint16','single','double'}, ...
        {}, mfilename, 'RGB', 1);
    coder.internal.errorIf((size(X,3) ~= 3), ...
        'images:rgb2ycbcr:invalidTruecolorImage');
    ycbcr = rgb2ycbcr_core(X);
else
    coder.internal.errorIf(true, 'images:rgb2ycbcr:invalidInputSize');
end

end

function ycbcr = rgb2ycbcr_core(rgb)
coder.inline('always');

origT      = [65.481 128.553 24.966;...
    -37.797 -74.203 112; ...
    112 -93.786 -18.214];
origOffset = [16; 128; 128];

scaleFactor.float.T       = 1/255;      % scale output so in range [0 1].
scaleFactor.float.offset  = 1/255;      % scale output so in range [0 1].
scaleFactor.uint8.T       = 1/255;      % scale input so in range [0 1].
scaleFactor.uint8.offset  = 1;          % output is already in range [0 255].
scaleFactor.uint16.T      = 257/65535;  % scale input so it is in range [0 1]
% and scale output so it is in range
% [0 65535] (255*257 = 65535).
scaleFactor.uint16.offset = 257;        % scale output so it is in range [0 65535].

if isfloat(rgb)
    classIn = 'float';
else
    classIn = class(rgb);
end
T      = scaleFactor.(classIn).T * origT;
offset = scaleFactor.(classIn).offset * origOffset;
ycbcr  = coder.nullcopy(zeros(size(rgb), 'like', rgb));
coder.internal.prefer_const(T);
coder.internal.prefer_const(offset);

% Use sharedlib (TBB) for images over 500k pixels (inherited from imlincomb)
GRAIN_SIZE = 500000;
numPixels = numel(rgb);
singleThread = images.internal.coder.useSingleThread();
useParallel = ~singleThread && (numPixels > GRAIN_SIZE);

% Use portable code if single-threaded
useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() ...
    && useParallel;

if coder.isColumnMajor % ColumnMajor
    if (numel(size(rgb)) == 2) % Colormap (2D input)
        % Both SharedLib and PortableC use the same path for 'map' datatype
        R = rgb(:,1);
        G = rgb(:,2);
        B = rgb(:,3);
        for p = 1:3
            ycbcr(:,p) = imlincomb(T(p,1),R,T(p,2),G,T(p,3),B,offset(p));
        end
    elseif (useSharedLibrary || (~useSharedLibrary && coder.internal.isInParallelRegion))
        % RGB (3D input) &&(SharedLib mode || (PortableC mode && InParallelRegion)
        R = rgb(:,:,1);
        G = rgb(:,:,2);
        B = rgb(:,:,3);
        for p = 1:3
            ycbcr(:,:,p) = imlincomb(T(p,1),R,T(p,2),G,T(p,3),B,offset(p));
        end
    else % RGB (3D input) && PortableC mode && ~isInParallelRegion
        rgbSize1 = size(rgb,1);
        parfor n = 1:size(rgb,2)
            for m = 1:rgbSize1
                coder.unroll;
                for p = 1:3
                    ycbcr(m,n,p) = imlincomb(T(p,1),rgb(m,n,1),T(p,2),rgb(m,n,2),T(p,3),rgb(m,n,3),offset(p));
                end
            end
        end
    end
else % Row-major
    if (numel(size(rgb)) == 2)
        % Colormap
        parfor m = 1:size(rgb,1)
            coder.unroll;
            for p = 1:3
                ycbcr(m,p) = imlincomb(T(p,1),rgb(m,1),T(p,2),rgb(m,2),T(p,3),rgb(m,3),offset(p));
            end
        end
    else % RGB (3D input)
        rgbSize2 = size(rgb,2);
        parfor m = 1:size(rgb,1)
            for n = 1:rgbSize2
                coder.unroll;
                for p = 1:3
                    ycbcr(m,n,p) = imlincomb(T(p,1),rgb(m,n,1),T(p,2),rgb(m,n,2),T(p,3),rgb(m,n,3),offset(p));
                end
            end
        end
    end
end
end
