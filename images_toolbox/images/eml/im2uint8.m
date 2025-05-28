function u = im2uint8(img, varargin) %#codegen
%

% Copyright 2013-2024 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(1,2);
coder.internal.prefer_const(img, varargin);

validateattributes(img,{'double','logical','uint8','uint16','single','int16'}, ...
    {'nonsparse'},mfilename,'Image',1);

if(~isreal(img))
    eml_warning('images:im2uint8:ignoringImaginaryPartOfInput');
    I = real(img);
else
    I = img;
end

if nargin == 2
    validateIndexedImages(I, varargin{1});
end

% Number of threads (obtained at compile time)
singleThread = images.internal.coder.useSingleThread();

% Shared library
useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() && ...
    coder.const(~singleThread);

if isa(I, 'uint8')
    u = I;
elseif isa(I, 'logical')
    u = uint8(I.*255);
else %double, single, uint16, or int16
    if nargin == 1
        if (useSharedLibrary)
            u = uint8SharedLibraryAlgo(I);
        else
            u = uint8PortableCodeAlgo(I);
        end
    else %indexed images
        if (isa(I, 'uint16') )
            u = uint8(I);
        else  %double or empty
            u = uint8(I-1);
        end
    end
end

end

function u = uint8PortableCodeAlgo(I)
%% Portable Code
coder.inline('always');
coder.internal.prefer_const(I);
u = coder.nullcopy(uint8(I));
switch (class(I))
    case 'int16'
        if coder.isColumnMajor
            parfor index = 1:numel(I)
                v = uint16(int32(I(index))+int32(32768));
                u(index) = uint8(double(v)*1/257);
            end
        else % Row-major
            if numel(size(I)) == 2
                Isize2 = size(I,2);
                parfor i = 1:size(I,1)
                    for j = 1:Isize2
                        v = uint16(int32(I(i,j))+int32(32768));
                        u(i,j) = uint8(double(v)*1/257);
                    end
                end
            elseif numel(size(I)) == 3
                Isize2 = size(I,2);
                Isize3 = size(I,3);
                parfor i = 1:size(I,1)
                    for j = 1:Isize2
                        for k = 1:Isize3
                            v = uint16(int32(I(i,j,k))+int32(32768));
                            u(i,j,k) = uint8(double(v)*1/257);
                        end
                    end
                end
            else
                v = uint16(int32(I)+int32(32768));
                u = uint8(double(v)*1/257);
            end
        end
    case 'uint16'
        if coder.isColumnMajor
            parfor index = 1:numel(I)
                u(index) = uint8(double(I(index))*1/257);
            end
        else % Row-major
            if numel(size(I)) == 2
                Isize2 = size(I,2);
                parfor i = 1:size(I,1)
                    for j = 1:Isize2
                        u(i,j) = uint8(double(I(i,j))*1/257);
                    end
                end
            elseif numel(size(I)) == 3
                Isize2 = size(I,2);
                Isize3 = size(I,3);
                parfor i = 1:size(I,1)
                    for j = 1:Isize2
                        for k = 1:Isize3
                            u(i,j,k) = uint8(double(I(i,j,k))*1/257);
                        end
                    end
                end
            else
                u = uint8(double(I)*1/257);
            end

        end
    case {'double','single'}
        if(isempty(I))
            u = uint8(I);
        else
            maxVal = cast(intmax('uint8'),'like',I);
            if coder.isColumnMajor
                parfor index = 1:numel(I)
                    val = I(index) * maxVal;
                    if val < 0
                        u(index) = uint8(0);
                    elseif val > maxVal
                        u(index) = uint8(maxVal);
                    else
                        u(index) = eml_cast(val+0.5,'uint8','to zero','spill');
                    end
                end
            else % Row-major
                if numel(size(I)) == 2
                    Isize2 = size(I,2);
                    parfor i = 1:size(I,1)
                        for j = 1:Isize2
                            val = I(i,j) * maxVal;
                            if val < 0
                                u(i,j) = uint8(0);
                            elseif val > maxVal
                                u(i,j) = uint8(maxVal);
                            else
                                u(i,j) = eml_cast(val+0.5,'uint8','to zero','spill');
                            end
                        end
                    end
                elseif numel(size(I)) == 3
                    Isize2 = size(I,2);
                    Isize3 = size(I,3);
                    parfor i = 1:size(I,1)
                        for j = 1:Isize2
                            for k = 1:Isize3
                                val = I(i,j,k) * maxVal;
                                if val < 0
                                    u(i,j,k) = uint8(0);
                                elseif val > maxVal
                                    u(i,j,k) = uint8(maxVal);
                                else
                                    u(i,j,k) = eml_cast(val+0.5,'uint8','to zero','spill');
                                end
                            end
                        end
                    end
                else
                    for index = 1:numel(I)
                        val = I(index) * maxVal;
                        if val < 0
                            u(index) = uint8(0);
                        elseif val > maxVal
                            u(index) = uint8(maxVal);
                        else
                            u(index) = eml_cast(val+0.5,'uint8','to zero','spill');
                        end
                    end
                end
            end
        end
    otherwise
        assert(false,'Unknown class');
end
end


function u = uint8SharedLibraryAlgo(I)
%% Shared Library
coder.inline('always');
coder.internal.prefer_const(I);
if isa(I, 'int16')
    v = int16touint16(I);
    u = grayto8(v);
else
    u = grayto8(I);
end
end

function validateIndexedImages(I, indexOption)
%% Indexed Image Validation
coder.inline('always');
coder.internal.prefer_const(I, indexOption);
validatestring( indexOption,{'indexed'},mfilename,'type',2);
coder.internal.errorIf(isa(I, 'int16'), ...
    'images:im2uint8:invalidIndexedImage');
maxVal = max(I(:));
minVal = min(I(:));
if (isa(I, 'uint16') )
    coder.internal.errorIf((maxVal > 255), ...
        'images:im2uint8:tooManyColorsFor8bitStorage');
end
if (isa(I, 'float') && ~(isempty(I)))
    coder.internal.errorIf((maxVal >= 257), ...
        'images:im2uint8:tooManyColorsFor8bitStorage');
    coder.internal.errorIf((minVal < 1), ...
        'images:im2uint8:invalidIndexValue');
end
end

% LocalWords:  nonsparse
