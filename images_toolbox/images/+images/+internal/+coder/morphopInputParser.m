function [A, input_is_packed, output_is_full, inNumRows, input_is_logical, input_is_2d] = morphopInputParser(A, op_type,func_name,varargin) %#codegen
%

% Copyright 2020 The MathWorks, Inc.

narginchk(3,6);

coder.inline('always');
coder.internal.prefer_const(A,op_type,func_name,varargin);

% Validate inputs
% Get the required inputs and check them for validity.
A = checkInputImage(A, func_name);

% Process optional arguments
[input_is_packed, output_is_full, inNumRows] = processOptionalArguments(func_name, varargin{:});

% The optional input options have to be compile time constants
eml_invariant(eml_is_const(output_is_full),...
    eml_message('images:morphop:shapeOptNotConst'),...
    'IfNotConst','Fail');
eml_invariant(eml_is_const(input_is_packed),...
    eml_message('images:morphop:packOptNotConst'),...
    'IfNotConst','Fail');

% Check inNumRows for consistency with image size.
if input_is_packed
    if inNumRows >= 0
        d = 32*size(A,1) - inNumRows;
        % run-time check
        eml_invariant(~(d < 0) || (d > 31),...
            eml_message('images:imerode:inconsistentUnpackedM'));
    end
end

% Compute necessary predicates
input_numdims     = coder.const(numel(size(A)));
input_is_uint32   = coder.const(isa(A,'uint32'));
input_is_logical  = coder.const(islogical(A));
input_is_2d       = coder.const(numel(size(A))==2);

% Check for error conditions related to packing
% if input is packed data. no gpu code is generated and gpu code generation is aborted.
if (coder.gpu.internal.isGpuEnabled && input_is_packed )
    coder.internal.errorIf(true,'gpucoder:common:MorphOpUnsupportedInputDataError');
end

coder.internal.errorIf( input_is_packed && strcmp(op_type, 'erode') && (inNumRows < 1), ...
    'images:morphop:missingPackedM');
coder.internal.errorIf( input_is_packed && ~input_is_uint32, ...
    'images:morphop:invalidPackedInputType');
coder.internal.errorIf( input_is_packed && (input_numdims > 2), ...
    'images:morphop:packedImageNot2D');
coder.internal.errorIf( input_is_packed && output_is_full,...
    'images:morphop:packedFull');


%==========================================================================
function A = checkInputImage(A, func_name)
coder.inline('always');
validateattributes(A, {'numeric' 'logical'}, ...
    {'real' 'nonsparse','nonnan'}, ...
    func_name, 'IM', 1);

% N-D not supported
coder.internal.errorIf(numel(size(A))>3,'images:morphop:noNDInMode');
%--------------------------------------------------------------------------

%==========================================================================
function [input_is_packed, output_is_full, inNumRows] = processOptionalArguments(func_name, varargin)
coder.inline('always');
coder.internal.prefer_const(func_name, varargin);

% Process optional arguments.
% varargin of length 0-3 will contain one or more of the following in any
% order: padoption (same/full), packoption (notpacked/ispacked} and a
% scalar number (unpacked_M, only from erode client)
%
allowed_strings = {'same','full','ispacked','notpacked'};

% Defaults:
% input_is_packed = false;
% output_is_full  = false;
% inNumRows       = -1; % i.e unused.

switch numel(varargin)
    case 1
        % Has to be a string
        string = validatestring(varargin{1}, allowed_strings, ...
            func_name, 'OPTION', 3); % 3rd position in calling function
        switch string
            case {'full','same'}
                input_is_packed = false;
                output_is_full  = strcmp(string,'full');
            case {'ispacked','notpacked'}
                input_is_packed = strcmp(string,'ispacked');
                output_is_full  = false;
        end
        inNumRows = -1;
        
    case 2
        % Either
        % shapeopt, packout
        % packopt, shapeopt
        % packopt, M
        string = validatestring(varargin{1}, allowed_strings, ...
            func_name, 'OPTION', 3); % 3rd position in calling function
        switch string
            case {'full','same'}
                % shapeopt, packout
                output_is_full  = strcmp(string,'full');
                packString      = validatestring(varargin{2}, {'ispacked','notpacked'}, ...
                    func_name, 'OPTION', 4);
                input_is_packed = strcmp(packString,'ispacked');
                inNumRows       = -1;
            case {'ispacked','notpacked'}
                % packopt, shapeopt
                % packopt, M
                input_is_packed = strcmp(string,'ispacked');
                if(ischar(varargin{2}))
                    % packopt, shapeopt
                    shapeString    = validatestring(varargin{2}, {'same','full'}, ...
                        func_name, 'OPTION', 4);
                    output_is_full = strcmp(shapeString,'full');
                    inNumRows      = -1;
                else
                    % packopt, M
                    inNumRows      = varargin{2};
                    validateattributes(inNumRows, {'double'},...
                        {'real' 'nonsparse' 'scalar' 'integer' 'nonnegative'}, ...
                        func_name, 'M', 4);
                    output_is_full = false;
                end
        end
        
    case 3
        % Either
        % shapeopt, packout, M
        % packopt, M, shapeopt
        
        % Has to be string first
        string = validatestring(varargin{1}, allowed_strings, ...
            func_name, 'OPTION', 3); % 3rd position in calling function
        switch string
            case {'full','same'}
                % shapeopt, packout, M
                output_is_full  = strcmp(string,'full');
                packString      = validatestring(varargin{2}, {'ispacked','notpacked'}, ...
                    func_name, 'OPTION', 4);
                input_is_packed = strcmp(packString,'ispacked');
                inNumRows       = varargin{3};
                validateattributes(inNumRows, {'double'},...
                    {'real' 'nonsparse' 'scalar' 'integer' 'nonnegative'}, ...
                    func_name, 'M', 5);
                
            case {'ispacked','notpacked'}
                % packopt, M, shapeopt
                input_is_packed = strcmp(string,'ispacked');
                inNumRows       = varargin{2};
                validateattributes(inNumRows, {'double'},...
                    {'real' 'nonsparse' 'scalar' 'integer' 'nonnegative'}, ...
                    func_name, 'M', 4);
                shapeString     = validatestring(varargin{3}, {'same','full'}, ...
                    func_name, 'OPTION', 5);
                output_is_full  = strcmp(shapeString,'full');
                
        end
        
    otherwise
        % Defaults
        output_is_full  = false;
        input_is_packed = false;
        inNumRows       = -1;
        
end

input_is_packed = coder.const(input_is_packed);
output_is_full = coder.const(output_is_full);
%--------------------------------------------------------------------------