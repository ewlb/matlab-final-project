function [useAlternate, B] = morphop_fast(morphFunc, A,se, varargin) %#codegen
%

% Copyright 2017-2024 The MathWorks, Inc.
coder.extrinsic('images.internal.coder.isHalideActive');
coder.internal.prefer_const(morphFunc, se);

B = A;
useAlternate = true;

% Don't test for NaN for faster runtime
validateattributes(A, {'single', 'double', 'int8', 'int16', 'int32', ...
    'uint8', 'uint16', 'uint32', 'logical'}, ...
    {'real' 'nonsparse'}, ...
    morphFunc, 'IM', 1);

% No empty inputs, no additional arguments
if nargin~=3 || isempty(A) || isempty(se)
    return
end

% Single flat strel only
if isa(se,'strel')
    if ~(numel(se)==1 && ~isempty(se.Neighborhood) && all(se.isflat()))
        return
    end
end

% Convert se to logical 2D/3D array
if isa(se,'strel') && ~isempty(se)
    se = se.Neighborhood;
elseif isreal(se) && (isnumeric(se) || islogical(se))
    if(isnumeric(se))
        isValidSE = all( ismember(se, [0 1]), 'all');
        coder.internal.errorIf(~isValidSE,...
            'images:strelcheck:invalidNhoodValues', 'nhood', morphFunc);
    end
    se = logical(full(se));
else
    % fallthrough
    return;
end

% Dimension of image and se should match and be 2D or 3D only
if ndims(A)>3 || ndims(A)~=ndims(se)
    return
end

numNeighbors = nnz(se);
is2DFull = ismatrix(A) && numNeighbors==numel(se);

numNeighborsThreshold = 600;
maxstrelSizeThreshold = 15;
useHalide = numNeighbors<numNeighborsThreshold...
    && all(size(se)<=maxstrelSizeThreshold);

if ~isempty(varargin) || ~coder.target('MATLAB')    
    % Check for Halide and generators in path    
    isHalideSupportedFcn = coder.const(isHalideSupportedFunction(morphFunc));
    useHalide = useHalide && coder.const(coder.internal.preferPrecompiledLibraries);
    useHalide = useHalide && coder.const(coder.internal.isHalideAvailable);
    useHalide = useHalide && isHalideSupportedFcn && coder.target("C++");
    useHalide = useHalide && ~coder.isRowMajor;
    useHalide = useHalide && ~coder.target('CUDA'); 
    useHalide = useHalide && coder.const(coder.areUnboundedVariableSizedArraysSupported);
    useHalide = useHalide && coder.const(coder.internal.isHalideSupportedTarget);
    useHalide = useHalide && coder.const(images.internal.coder.isHalideActive);
    useHalide = useHalide ...
        && coder.internal.isConst(se) && coder.internal.isConst(ndims(A));
    
    if(useHalide && ~coder.target('MATLAB'))
        minmax = getMinMax(A);
        B = images.internal.coder.halideeval.morphop(morphFunc, A, minmax, se);
        useAlternate = false;
    end
    % No support for 'full', or codegen
    return
else
    % Not codegen, check setting
    s = settings;
    useHalide = useHalide && s.images.UseHalide.ActiveValue;
end


% Full se's - only dilate/erode supported with builtins
canUse2DFullBuiltin = is2DFull && (morphFunc=="imdilate"||morphFunc=="imerode");
if canUse2DFullBuiltin
    B = imagesbuiltinMorphop2DFullSE(A, size(se), morphFunc, 'same');
    useAlternate = false;
    return
elseif is2DFull
    % For other morph functions, use imdilate/imerode sequentially.
    useAlternate = true;
    return
end

% Inf/Nan dont work as expected (in bot/top hat)
useHalide = useHalide && ...
    ~( isfloat(A) && (strcmp(morphFunc(end-2:end),'hat')));

if useHalide
    % Get initial values based on datatype
    minmax = getMinMax(A);
    
    B = images.internal.builtins.morphmex_halide(A, minmax, se,  morphFunc);
    useAlternate = false;
    return
end

end

function minmax = getMinMax(A)
if isfloat(A)
    minmax = [-inf(class(A)); inf(class(A))];
elseif islogical(A)
    minmax = [ false; true];
else
    minmax = [intmin(class(A)); intmax(class(A))];
end
minmax = double(minmax);
end

function b = isHalideSupportedFunction(func)
coder.internal.prefer_const(func);
b = (func=="imerode") || (func=="imdilate");
end
