function [X,map] = gray2ind(varargin)
    %GRAY2IND Convert intensity image to indexed image.
    %   GRAY2IND scales, then rounds, an intensity image to produce an equivalent
    %   indexed image.
    %
    %   [X,MAP] = GRAY2IND(I,N) converts the intensity image I to an indexed image X
    %   with colormap GRAY(N). If N is omitted, it defaults to 64.
    %
    %   [X,MAP] = GRAY2IND(BW,N) converts the binary image BW to an indexed image X
    %   with colormap GRAY(N). If N is omitted, it defaults to 2.
    %
    %   N must be an integer between 1 and 65536.
    %
    %   Class Support
    %   -------------
    %   The input image I can be logical, uint8, uint16, int16, single, or double
    %   and must be real and nonsparse.  I can have any dimension.  The class of the
    %   output image X is uint8 if the colormap length is less than or equal to 256;
    %   otherwise it is uint16.
    %
    %   Example
    %   -------
    %       I = imread('cameraman.tif');
    %       [X, map] = gray2ind(gpuArray(I), 16);
    %       figure, imshow(X, map);
    %
    %   See also GRAYSLICE, IND2GRAY, GPUARRAY/MAT2GRAY.

    %   Copyright 2022-2023 The MathWorks, Inc.

    if(~isgpuarray(varargin{1}))
        % CPU code path if the first input is not a gpuArray
        [varargin{:}] = gather(varargin{:});
        [X,map] = gray2ind(varargin{:});
        return;
    end

    [I,n] = parseInputs(varargin{:});

    if islogical(I)  % is it a binary image?
        X = bw2index(I,n);
    else
        X = gray2index(I,n);
    end

    map = gray(n);
end

function X = bw2index(BW,n)

    if n <= 256
        X = uint8(BW);
        n = uint8(n);
    else
        X = uint16(BW);
        n = uint16(n);
    end

    X = arrayfun(@assignValuesToX,X,BW,n-1);
end

function X = assignValuesToX(X,BW,val)
    if BW
        X = val;
    end
end

function X = gray2index(I,n)

    range = getrangefromclass(I);
    sf = (n - 1) / range(2);

    if n <= 256
        % 256 or fewer colors, we can output uint8
        X = imlincomb(sf,I,'uint8');
    else
        X = imlincomb(sf,I,'uint16');
    end
end

function [I,n] = parseInputs(varargin)

    default_grayscale_colormap_size = 64;
    default_binary_colormap_size = 2;

    narginchk(1,2);

    I = varargin{1};

    if nargin == 1
        if islogical(I)
            n = gpuArray(default_binary_colormap_size);
        else
            n = gpuArray(default_grayscale_colormap_size);
        end
    else
        n = gpuArray(varargin{2});
        validateattributes(n,{'numeric'},{'real', 'integer'}, mfilename, 'N', 2);
        if n < 1 || n > 65536
            error(message('images:gray2ind:inputOutOfRange'));
        end
    end

    validateattributes(I,{'uint8','int16','uint16','double','logical','single'},...
        {'real','nonsparse'}, mfilename,'I',1);
    % Convert int16 image to uint16.
    if isUnderlyingType(I,'int16')
        I = int16touint16(I);
    end
end