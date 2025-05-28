function [B] = modefilt(varargin)

[A, filterSize, padOpt, catConverter] = parseInputs(varargin{:});
isInputCategorical = ~isempty(catConverter);

if (all(filterSize == 1)) || isempty(A)
    B = varargin{1};
    return;
end

if ndims(A) <= 2
    % MFL::CONV modefilt2 builtin
    B = images.internal.builtins.modefilt2(A, double(filterSize), padOpt, isInputCategorical);
else
    % Sliding Window modefilt3 builtin
    B = images.internal.builtins.modefilt3(A, double(filterSize), padOpt, isInputCategorical);
end

if isInputCategorical
    B = catConverter.numeric2Categorical(B);
end

end

function [A,filterSize,padOpt,catConverter] = parseInputs(varargin)

narginchk(1,3);
matlab.images.internal.errorIfgpuArray(varargin{:});

varargin = matlab.images.internal.stringToChar(varargin);

padOpt = 'symmetric';
catConverter = [];

A = varargin{1};
ndimsA = ndims(A);

if ndimsA <= 2
    filterSize = [3 3];
elseif ndimsA == 3
    filterSize = [3 3 3];
else
    error(message('images:modefilt:invalidInputSize'));
end

validateattributes(A,...
    {'uint8','uint16','uint32','int8','int16','int32','single','double','categorical','logical'},...
    {'nonsparse','real'},mfilename,'A',1);

if iscategorical(A)
    catConverter = images.internal.utils.CategoricalConverter(categories(A));
    A = catConverter.categorical2Numeric(A);
end

if nargin == 2
    % Can be PadOpt or FiltSize
    if ischar(varargin{2})
        padOpt = validatestring(varargin{2},{'zeros','replicate','symmetric'},...
            mfilename,'PADOPT',2);
    else
        
        validateattributes(varargin{2},{'numeric'},...
            {'real','finite','positive','integer','odd','nonempty','nonsparse','vector','numel',ndimsA},...
            mfilename,'FILTSIZE',2);
        filterSize = varargin{2};
    end
end

if nargin == 3
    % FiltSize
    validateattributes(varargin{2},{'numeric'},...
        {'real','finite','positive','integer','odd','nonempty','nonsparse','vector','numel',ndimsA},...
        mfilename,'FILTSIZE',2);
    filterSize = varargin{2};

    % PadOpt
    padOpt = validatestring(varargin{3},{'zeros','replicate','symmetric'},...
            mfilename,'PADOPT',3);
end

end

%   Copyright 2019-2022 The MathWorks, Inc.