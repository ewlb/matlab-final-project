function rgb = ycbcr2rgb(X) %#codegen
%

% Copyright 2013-2024 The MathWorks, Inc.

%#ok<*EMCA>

if (numel(size(X)) == 2)
    validateattributes(X, ...
        {'uint8','uint16','single','double'}, ...
        {'real','nonempty'}, ...
        mfilename, 'MAP', 1);
    coder.internal.errorIf((size(X,2) ~= 3 || size(X,1) < 1), ...
        'images:ycbcr2rgb:invalidSizeForColormap');
    rgb = ycbcr2rgb_core(X);
elseif (numel(size(X)) == 3)
    validateattributes(X, ...
        {'uint8','uint16','single','double'}, ...
        {'real'}, mfilename, 'YCBCR', 1);
    coder.internal.errorIf((size(X,3) ~= 3), ...
        'images:ycbcr2rgb:invalidTruecolorImage');
    rgb = ycbcr2rgb_core(X);
else
    coder.internal.errorIf(true, 'images:ycbcr2rgb:invalidInputSize');
end

end

function rgb = ycbcr2rgb_core(ycbcr)
coder.inline('always');

T = [65.481 128.553 24.966;...
    -37.797 -74.203 112; ...
    112 -93.786 -18.214];

Tinv = T^-1;
offset = [16;128;128];

scaleFactor.float.T = 255;        % scale input so it is in range [0 255].
scaleFactor.float.offset = 1;     % output already in range [0 1].
scaleFactor.uint8.T = 255;        % scale output so it is in range [0 255].
scaleFactor.uint8.offset = 255;   % scale output so it is in range [0 255].
scaleFactor.uint16.T = 65535/257; % scale input so it is in range [0 255]
% (65535/257 = 255),
% and scale output so it is in range [0 65535].
scaleFactor.uint16.offset = 65535; % scale output so it is in range [0 65535].

if isfloat(ycbcr)
    classIn = 'float';
    floatFlag = true;
else
    classIn = class(ycbcr);
    floatFlag = false;
end
T      = scaleFactor.(classIn).T * Tinv;
offset = scaleFactor.(classIn).offset * Tinv * offset;
rgb    = coder.nullcopy(zeros(size(ycbcr), 'like', ycbcr));
coder.internal.prefer_const(T);
coder.internal.prefer_const(offset);

% Use sharedlib (TBB) for images over 500k pixels (inherited from imlincomb)
GRAIN_SIZE = 500000;
numPixels = numel(ycbcr);
singleThread = images.internal.coder.useSingleThread();
useParallel = ~singleThread && (numPixels > GRAIN_SIZE);

% Use portable code if single-threaded
useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() ...
    && useParallel;

if coder.isColumnMajor
    if (numel(size(ycbcr)) == 2) % Colormap (2D input)
        % Both SharedLib and PortableC use the same path for 'map' datatype
        Y  = ycbcr(:,1);
        Cb = ycbcr(:,2);
        Cr = ycbcr(:,3);
        for p = 1:3
            rgb(:,p) = imlincomb(T(p,1),Y,T(p,2),Cb,T(p,3),Cr,-offset(p));
        end
        if floatFlag
            rgb = min(max(rgb,0),1);
        end
    elseif (useSharedLibrary || (~useSharedLibrary && coder.internal.isInParallelRegion))
        % YCbCr (3D input) &&(SharedLib mode || (PortableC mode && InParallelRegion)
        Y  = ycbcr(:,:,1);
        Cb = ycbcr(:,:,2);
        Cr = ycbcr(:,:,3);
        for p = 1:3
            rgb(:,:,p) = imlincomb(T(p,1),Y,T(p,2),Cb,T(p,3),Cr,-offset(p));
        end
        if floatFlag
            rgb = min(max(rgb,0),1);
        end
    else % YCbCr (3D input) && PortableC mode && ~isInParallelRegion
        ycbcrSize1 = size(ycbcr,1);
        parfor n = 1:size(ycbcr,2)
            for m = 1:ycbcrSize1
                coder.unroll;
                for p = 1:3
                    rgb(m,n,p) = imlincomb(T(p,1),ycbcr(m,n,1),T(p,2),ycbcr(m,n,2),T(p,3),ycbcr(m,n,3),-offset(p));
                    if floatFlag
                        rgb(m,n,p) = min(max(rgb(m,n,p),0),1);
                    end
                end
            end
        end
    end
else % Row-major
    if (numel(size(ycbcr)) == 2)
        % Colormap
        parfor m = 1:size(ycbcr,1)
            for p = 1:3
                rgb(m,p) = imlincomb(T(p,1),ycbcr(m,1),T(p,2),ycbcr(m,2),T(p,3),ycbcr(m,3),-offset(p));
            end
        end
    else % YCbCr (3D input)
        ycbcrSize2 = size(ycbcr,2);
        parfor m = 1:size(ycbcr,1)
            for n = 1:ycbcrSize2
                for p = 1:3
                    rgb(m,n,p) = imlincomb(T(p,1),ycbcr(m,n,1),T(p,2),ycbcr(m,n,2),T(p,3),ycbcr(m,n,3),-offset(p));
                end
            end
        end
    end

    if isfloat(rgb)
        rgb = min(max(rgb,0),1);
    end
end
end
