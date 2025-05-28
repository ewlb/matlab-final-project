function BW = activecontour(varargin) %#codegen
%ACTIVECONTOUR Segment image into foreground and background using active contour.

narginchk(2,8);

[A, mask, N, method, smoothfactor,contractionbias] = parseInputs(varargin{:});

coder.inline('always');
coder.internal.prefer_const(A,mask,N,method,smoothfactor,contractionbias);

if isempty(A)
    BW = logical(A);
    return;
elseif islogical(A)
    BW = A;
    return;
end

%To help cast to the data type single or double in object
if isinteger(A)
    classVar = zeros(1,'single');
else
    classVar = zeros(1,'like',A);
end

%3D flag
if ndims(A) == 3
    is3D = true;
else
    is3D = false;

end

% Create speed function object
switch (method)
    case CHANVESE

        foregroundweight = 1;
        backgroundweight = 1;

        speed = images.internal.coder.ActiveContourSpeedChanVese ...
            (smoothfactor, contractionbias, foregroundweight, backgroundweight,classVar);

    case EDGE
        coder.internal.errorIf(is3D,'images:activecontour:edgeNotSupportedFor3D');
        advectionweight = 1;
        sigma = 2;
        gradientnormfactor = 1;
        edgeExponent = 1;

        speed = images.internal.coder.ActiveContourSpeedEdgeBased ...
            (smoothfactor, contractionbias, advectionweight, sigma, ...
            gradientnormfactor, edgeExponent,classVar);
end

% Create contour evolver object
evolver = images.internal.coder.ActiveContourEvolver(A, mask, speed);

% Evolve the contour for specified number of iterations
evolver = moveActiveContour(evolver, N);

% Extract final contour state
BW = evolver.ContourState;

end

%Parse Inputs
%==========================================================================

function [A, mask, N, method, smoothfactor,contractionbias] =...
    parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);
% Validate A
A = varargin{1};
validImageTypes = {'uint8','int8','uint16','int16','uint32','int32', ...
    'single','double','logical'};
validateattributes(A,validImageTypes,{'finite','nonsparse','real'},...
    mfilename,'A',1);

coder.internal.errorIf(isvector(A) || ndims(A) > 3,...
    'images:activecontour:mustBe2Dor3D','A');

% Validate MASK
validMaskTypes = {'logical','numeric'};
validateattributes(varargin{2},validMaskTypes,{'nonnan','nonsparse','real'},...
    mfilename,'MASK',2);

coder.internal.errorIf(isvector(varargin{2}) || ndims(varargin{2}) > 3,...
    'images:activecontour:mustBe2Dor3D','MASK');

invalidMaskImageDims = ~isequal(size(A,1),size(varargin{2},1)) ||...
    ~isequal(size(A,2),size(varargin{2},2))...
    || (size(varargin{2},3) > 1 && ~isequal(size(A),size(varargin{2})));


coder.internal.errorIf(invalidMaskImageDims,...
    'images:activecontour:differentMatrixSize','A','MASK');

isColor = ~isequal(size(A),size(varargin{2}));

if ~islogical(varargin{2})
    mask = logical(varargin{2});
else
    mask = varargin{2};
end

% Default values for optional arguments (N, METHOD, SMOOTHFACTOR, CONTRACTIONBIAS)
N = 100;
smoothfactor = 0; % Default SMOOTHFACTOR for Chan-Vese method
contractionbias = 0; % Default CONTRACTIONBIAS for Chan-Vese method

% If specified, parse optional arguments
if nargin > 2
    if ~ischar(varargin{3})
        N = varargin{3};
        % Validate N
        validateattributes(varargin{3},{'numeric'},{'positive','scalar','finite', ...
            'integer'}, mfilename,'N',3);
        method_arg_loc = coder.internal.indexInt(4);
    else
        method_arg_loc = coder.internal.indexInt(3);
    end

    varLen = coder.internal.indexInt(length(varargin));
    diffLen = varLen - method_arg_loc;
    if diffLen < 0
        cellLen = coder.internal.indexInt(0);
    else
        cellLen = diffLen + coder.internal.indexInt(1);
    end
    if cellLen == 0
        args_after_N = {};
    else
        args_after_N = cell(1,cellLen);
        for i = 1:cellLen
            args_after_N{i} = varargin{method_arg_loc-1+i};
        end
    end


    if ~isempty(args_after_N)

        coder.internal.errorIf(length(args_after_N) > 5,...
            'images:validate:tooManyInputs', mfilename);
        % Validate METHOD
        method_strings = {'Chan-Vese', 'edge'}; % Do not change order.

        validatestring(args_after_N{1}, method_strings, ...
            mfilename,'METHOD',method_arg_loc);
        method = stringToMethod(args_after_N{1});
        % activecontour(A,mask,{N},method)
        switch method
            case CHANVESE
                smoothfactor = 0;
                contractionbias = 0;
            case EDGE
                coder.internal.errorIf(isColor,...
                    'images:activecontour:edgeNotSupportedForColor');
                smoothfactor = 1;
                contractionbias = 0.3; % balloonweight > 0 biases the contour to shrink.
            otherwise
                coder.internal.assert(false,...
                    'images:validate:unknownInputString',method);
        end

        if length(args_after_N) == 2
            % activecontour(A,mask,{N},method,smoothfactor)
            smoothfactor = args_after_N{2};

            % Validate smoothfactor
            validateattributes(args_after_N{2},{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'nonnegative', ...
                'real','scalar','finite'}, mfilename,'SMOOTHFACTOR', ...
                method_arg_loc+1);
            smoothfactor = double(smoothfactor);
        elseif length(args_after_N) >2
            % activecontour(A,mask,{N},method,'PARAM1',Value1,'PARAM2',Value2)
            Len = cellLen-coder.internal.indexInt(1);
            switch method
                case CHANVESE
                    smoothfactor = 0;
                    contractionbias = 0;
                case EDGE
                    coder.internal.errorIf(isColor,'images:activecontour:edgeNotSupportedForColor');
                    smoothfactor = 1;
                    contractionbias = 0.3;
                otherwise
                    coder.internal.assert(false,'images:validate:unknownInputString',method);
            end

            param_strings = {'SmoothFactor','ContractionBias'};

            % Parse param-value pairs
            for n = 2 : 2 : Len
                % Error if param is not a string.

                coder.internal.errorIf(~(ischar(args_after_N{n}) || isstring(args_after_N{n})),...
                    'images:validate:mustBeString');
                % else
                param = validatestring(args_after_N{n},param_strings,mfilename);

                % Error if corresponding value is missing.

                coder.internal.errorIf(n>Len,...
                    'images:validate:missingValue',param);

                valid_types = {'uint8','int8','uint16','int16',...
                    'uint32','int32','single','double'};
                switch param
                    case 'SmoothFactor'
                        smoothfactor = args_after_N{n+1};

                        % Validate smoothfactor
                        validateattributes(args_after_N{n+1},valid_types, ...
                            {'nonnegative','real','scalar','finite'}, ...
                            mfilename,'SMOOTHFACTOR',method_arg_loc+n);

                        smoothfactor = double(smoothfactor);
                    case 'ContractionBias'
                        contractionbias = args_after_N{n+1};

                        % Valid contractionbias
                        validateattributes(args_after_N{n+1},valid_types,...
                            {'real','scalar','finite'},mfilename,...
                            'CONTRACTIONBIAS',method_arg_loc+n);

                        contractionbias = double(contractionbias);
                    otherwise

                        coder.internal.assert(false,'images:validate:unknownInputString',param);
                end

            end

        end
    else
        method = CHANVESE;
    end
else
    method = CHANVESE;
end
end


%==========================================================================
function method = stringToMethod(mStr)
% Convert method string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(mStr,'Chan-Vese',numel(mStr))
    method = CHANVESE;
else
    method = EDGE;
end
end

%==========================================================================
% %Enumeration functions for method strings and direction strings.
function methodFlag = CHANVESE()
coder.inline('always');
methodFlag = int8(1);
end

function methodFlag = EDGE()
coder.inline('always');
methodFlag = int8(2);
end