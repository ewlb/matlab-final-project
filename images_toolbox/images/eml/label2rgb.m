function RGB = label2rgb(label,map,varargin) %#codegen
%MATLAB Code Generation Library Function

% Limitations for RGB = LABEL2RGB(LABEL, MAP, ZEROCOLOR, ORDER)
%
%   At least two input arguments are required: LABEL2RGB(LABEL,MAP)
%
%   MAP must be an n-by-3 double colormap matrix.  Not supported: string
%   containing the name of a MATLAB colormap function. Not supported:
%   function handle of a colormap function.
%
%   No warning is thrown if ZEROCOLOR matches the color of one of the
%   regions in LABEL.
%
%   ORDER 'shuffle' is not supported.
%
%   OutputFormat can be 'image' or 'triplets'.

% ZEROCOLOR and ORDER do not need to be coder.Constant(). Error checking is
% done at runtime.

%   Copyright 1996-2021 The MathWorks, Inc.

% Number of input args supported by the toolbox version
narginchk(1,6);

[zerocolor,outputFormat] = parseInputs(label,map,varargin{:});

% Runtime error if cmap has less colors than number of labels in L.
coder.internal.errorIf(~isempty(label) && (size(map,1) < max(double(label),[],"all")), 'images:label2rgb:colormapNumColorsTooSmall')

% Concatenate with zero color and
% convert double 0 <= map <= 1 to uint8 0 <= CMAP <= 255
CMAP = uint8([zerocolor; map] * 255);

if coder.internal.isInParallelRegion()
    if eml_partial_strcmp(outputFormat,'triplets')
        m = numel(label);
        RGB = coder.nullcopy(zeros(m,3,'uint8'));
        for i = 1:m
            index = coder.internal.indexPlus(coder.internal.indexInt(label(i)),1);
            RGB(i,:) = CMAP(index,:);
        end
        
    else        
        % The actual algorithm (equivalent to ind2rgb8)
        [m,n] = size(label);
        RGB = coder.nullcopy(zeros(m,n,3,'uint8'));
        if coder.isColumnMajor()
            for j = 1:n
                for i = 1:m
                    index = coder.internal.indexPlus(coder.internal.indexInt(label(i,j)),1);
                    RGB(i,j,:) = CMAP(index,:);
                end
            end
        else
            for i = 1:m
                for j = 1:n
                    index = coder.internal.indexPlus(coder.internal.indexInt(label(i,j)),1);
                    RGB(i,j,:) = CMAP(index,:);
                end
            end
        end
    end
    
else
    
    if eml_partial_strcmp(outputFormat,'triplets')
        
        m = numel(label);
        RGB = coder.nullcopy(zeros(m,3,'uint8'));
        parfor i = 1:m
            temp = CMAP;
            index = coder.internal.indexPlus(coder.internal.indexInt(label(i)),1);
            RGB(i,:) = temp(index,:);
        end
        
    else
        
        % The actual algorithm (equivalent to ind2rgb8)
        [m,n] = size(label);
        RGB = coder.nullcopy(zeros(m,n,3,'uint8'));
        if coder.isColumnMajor()
            parfor j = 1:n
                temp = CMAP;
                for i = 1:m
                    index = coder.internal.indexPlus(coder.internal.indexInt(label(i,j)),1);
                    RGB(i,j,:) = temp(index,:);
                end
            end
        else
            parfor i = 1:m
                temp = CMAP;
                for j = 1:n
                    index = coder.internal.indexPlus(coder.internal.indexInt(label(i,j)),1);
                    RGB(i,j,:) = temp(index,:);
                end
            end
        end
    end
end

%--------------------------------------------------------------------------
function [zerocolor,outputFormat] = parseInputs(label,map,varargin)
% Both LABEL and MAP must be input in MATLAB Coder
coder.internal.errorIf(nargin < 2,'images:label2rgb:tooFewInputsCodegen');
coder.internal.prefer_const(label,map);

validateLabel(label);
validateMap(map);

% Default parameter values.
defaultZeroColor = [1 1 1];
defaultOutputFormat = coder.internal.const('image');

% Parse option and name-value arguments.
switch nargin
    case 2
        % Parse and validate the following syntaxes:
        %   - label2rgb(L,map)
        zerocolor = defaultZeroColor;
        outputFormat = defaultOutputFormat;
    case 3
        % Parse and validate the following syntaxes:
        %   - label2rgb(L,map,zerocolor)
        zerocolor = parseZerocolor(varargin{1});
        outputFormat = defaultOutputFormat;
    case 4
        % Parse and validate the following syntaxes:
        %   - label2rgb(L,map,'OutputFormat',value)
        %   - label2rgb(L,map,zerocolor,order)
        
        [outputFormat, outputFormatSpecified] = parseOutputFormat(varargin{1:2});
        if outputFormatSpecified
            % parse: label2rgb(L,map,'OutputFormat',value)
            zerocolor = defaultZeroColor;
        else
            % parse: label2rgb(L,map,zerocolor,order)
            zerocolor = parseZerocolor(varargin{1});
            validateOrder(varargin{2});
        end
        
    case 5
        % Parse and validate the following syntaxes:
        %    - label2rgb(L,map,zerocolor,'OutputFormat',value)
        %    - label2rgb(L,map,zerocolor,xxx,xxx)
        
        zerocolor = parseZerocolor(varargin{1});
        
        [outputFormat, outputFormatSpecified] = parseOutputFormat(varargin{2:3});
        if ~outputFormatSpecified
            % Invalid syntax: label2rgb(L,map,zerocolor,xxx,xxx)
            narginchk(6,6)
        end
    case 6
        % Parse and validate the following syntaxes
        %    - label2rgb(L,map,zerocolor,order,'OutputFormat',value)
        
        zerocolor = parseZerocolor(varargin{1});
        validateOrder(varargin{2});
        outputFormat = parseOutputFormat(varargin{3:4});
        
    otherwise
        % Too many inputs.
        narginchk(2,6);
end

%--------------------------------------------------------------------------
function validateLabel(label)
validateattributes(label,{'numeric','logical'}, ...
    {'real','2d','nonsparse','finite','nonnegative','integer'}, ...
    mfilename,'L',1);

%--------------------------------------------------------------------------
function validateMap(map)

coder.internal.errorIf(isa(map,'char'), ...
    'images:label2rgb:invalidColormapCodegen');

coder.internal.errorIf(~isa(map,'double') || isempty(map) || ...
    ~ismatrix(map) || size(map,2)~=3 || ~isreal(map), ...
    'images:label2rgb:invalidColormap');

coder.internal.errorIf(~ALL_BETWEEN_ZERO_AND_ONE(map), ...
    'images:label2rgb:invalidColormap');

%--------------------------------------------------------------------------
function validateOrder(order)
coder.internal.prefer_const(order);
% Only support 'noshuffle' for code generation using MATLAB.
coder.internal.errorIf(~eml_partial_strcmp('noshuffle',eml_tolower(order)),...
    'images:label2rgb:shuffleNotSupported');

%--------------------------------------------------------------------------
function zerocolor = parseZerocolor(zerocolor_in)

coder.internal.prefer_const(zerocolor_in);

if ischar(zerocolor_in)
    color_spec = eml_tolower(zerocolor_in);
    assert(~isempty(color_spec) && ~isequal('bl',color_spec),...
        eml_message('images:label2rgb:notInColorspecCodegenbl'));
    if     eml_partial_strcmp('yellow',color_spec)
        zerocolor = [1 1 0];   % yellow
    elseif eml_partial_strcmp('magenta',color_spec)
        zerocolor = [1 0 1];   % magenta
    elseif eml_partial_strcmp('cyan',color_spec)
        zerocolor = [0 1 1];   % cyan
    elseif eml_partial_strcmp('red',color_spec)
        zerocolor = [1 0 0];   % red
    elseif eml_partial_strcmp('green',color_spec)
        zerocolor = [0 1 0];   % green
    elseif isequal('b', color_spec) || eml_partial_strcmp('blue',color_spec)
        zerocolor = [0 0 1];   % blue
    elseif eml_partial_strcmp('white',color_spec)
        zerocolor = [1 1 1];   % white
    elseif isequal('k',color_spec) || eml_partial_strcmp('black',color_spec)
        zerocolor = [0 0 0];   % black
    else
        assert(false,eml_message('images:label2rgb:notInColorspecCodegen'));
        zerocolor = [1 1 1]; % To set types and sizes for compilation step
    end
else
    zerocolor = zerocolor_in;
end

% Validate zero color
validateZerocolor(zerocolor);

%--------------------------------------------------------------------------
function validateZerocolor(zerocolor)

coder.internal.errorIf(~isa(zerocolor,'double') || ...
    ~isequal(size(zerocolor),[1,3]) || ~isreal(zerocolor), ...
    'images:label2rgb:invalidZerocolor');

coder.internal.errorIf(~ALL_BETWEEN_ZERO_AND_ONE(zerocolor), ...
    'images:label2rgb:invalidZerocolor');

%--------------------------------------------------------------------------
function p = ALL_BETWEEN_ZERO_AND_ONE(v)

[M,N] = size(v);
for r = 1:M
    for c = 1:N
        if ~(v(r,c) >= 0 && v(r,c) <= 1)
            p = false;
            return
        end
    end
end

p = true;

%--------------------------------------------------------------------------
function [outputFormat,outputFormatSpecified] = parseOutputFormat(varargin)
defaultOutputFormat = coder.internal.const('image');

if ischar(varargin{1}) && strncmpi('OutputFormat',varargin{1},1)
    outputFormatSpecified = true;
    params = struct(...
        'OutputFormat',uint32(0));
    
    options = struct( ...
        'CaseSensitivity',false, ...
        'StructExpand',   true, ...
        'PartialMatching',true);
    
    optarg = eml_parse_parameter_inputs(params,options,varargin{1:2});
    
    outputFormatIn = eml_get_parameter_value( ...
        optarg.OutputFormat, ...
        defaultOutputFormat, ...
        varargin{1:2});
    
    outputFormat = validatestring(outputFormatIn,{'image','triplets'},mfilename,'OutputFormat');
else
    outputFormat = defaultOutputFormat;
    outputFormatSpecified = false;
    
end

% LocalWords:  ZEROCOLOR CMAP zerocolor nonsparse noshuffle Colorspec Codegenbl
