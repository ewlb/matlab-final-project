classdef OffsetStructuringElementHelper < matlab.mixin.internal.indexing.ParenAssign & ...
        matlab.mixin.internal.indexing.Paren %#codegen
    %OFFSETSTRUCTURINGELEMENTHELPER Create non-flat morphological structuring element.

    % Copyright 2015-2021 The MathWorks, Inc.

    properties(Dependent)
        Offset
        Dimensionality
    end

    properties(Access=private)
        OffsetSEHolder
        % Store input parameters of strel in params
        params
    end

    properties(Access = public, Transient)
        % Exposing this property as it is used in images.internal.coder.morphop to decide
        % what implementation to use either constant or non-constant folded impl
        UseConstantFoldingImpl
        IsGPUTarget
    end

    methods
        %==================================================================
        function obj = OffsetStructuringElementHelper(varargin)
            narginchk(1,4);

            obj = checkConstantFolding(obj, varargin{:});

            if obj.UseConstantFoldingImpl
                eml_assert_all_constant(varargin{:});
                coder.internal.prefer_const(varargin{:});
                obj.params = varargin;
                % The input values in varargin are stored and not executed.
                % The following line is required for checking errors in the
                % constructor syntax. It has no other effect.
                coder.const(feval('offsetstrel',varargin{:}));
                if coder.internal.const(isnumeric(varargin{1}))
                    nhood = coder.internal.const(isfinite(varargin{1}));
                    obj.OffsetSEHolder = images.internal.coder.strel.StructuringElementHelper('arbitrary', nhood, varargin{1});
                else
                    if coder.internal.const(strncmpi('ball', varargin{1}, numel(varargin{1})))
                        obj.OffsetSEHolder = images.internal.coder.strel.StructuringElementHelper(varargin{:});
                    else
                        nhood = coder.internal.const(isfinite(varargin{2}));
                        obj.OffsetSEHolder = images.internal.coder.strel.StructuringElementHelper('arbitrary', nhood, varargin{2});
                    end
                end
            else
                obj = makeOffsetStrel(obj, varargin{:});
            end
        end

        %==================================================================
        function [seq, isEachStrelObj2D] = decompose(obj)
            coder.internal.errorIf(obj.UseConstantFoldingImpl, ...
                'images:offsetstrel:methodNotSupportedForCodegen','decompose');
            [seq, isEachStrelObj2D] = obj.OffsetSEHolder.decompose();
        end

        %==================================================================
        function seq = getsequence(obj)
            coder.internal.errorIf(obj.UseConstantFoldingImpl, ...
                'images:offsetstrel:methodNotSupportedForCodegen','getsequence');
            seq = obj.OffsetSEHolder.getsequence();
        end

        %==================================================================
        function se2 = reflect(se1)
            coder.internal.errorIf(se1.UseConstantFoldingImpl, ...
                'images:offsetstrel:methodNotSupportedForCodegen','reflect');
            se2 = se1.OffsetSEHolder.reflect();
        end

        %==================================================================
        function se2 = translate(se1, displacement)
            coder.internal.errorIf(se1.UseConstantFoldingImpl, ...
                'images:offsetstrel:methodNotSupportedForCodegen','translate');
            se2 = se1.OffsetSEHolder.translate(displacement);
        end

        %==================================================================
        function TF = isequal(~,se) %#ok<STOUT>
            coder.internal.errorIf(true,'images:offsetstrel:methodNotSupportedForCodegen','isequal');
        end

        %==================================================================
        function se = loadobj(~) %#ok<STOUT>
            coder.internal.errorIf(true,'images:offsetstrel:methodNotSupportedForCodegen','loadobj');
        end

        %==================================================================
        function nhood = getnhood(obj,varargin)
            if obj.UseConstantFoldingImpl
                narginchk(1,2)
                if isempty(varargin)
                    % apply getnhood() on the strel object
                    idx = 0;
                else
                    % apply getnhood() on a decomposed strel object indexed by
                    % the input, idx
                    idx = varargin{1};
                end
                nhood = coder.internal.const(obj.OffsetSEHolder.getnhood(idx));
            else
                narginchk(1,1)
                coder.internal.errorIf(length(obj) ~= 1, 'images:offsetstrel:singleOffsetStrelOnly');
                nhood = obj.OffsetSEHolder.getnhood(varargin{:});
            end
        end

        %==================================================================
        function offset = getheight(obj,varargin)
            if obj.UseConstantFoldingImpl
                narginchk(1,2)
                if isempty(varargin)
                    % apply getnhood() on the strel object
                    idx = 0;
                else
                    % apply getnhood() on a decomposed strel object indexed by
                    % the input, idx
                    idx = varargin{1};
                end
                offset = coder.internal.const(obj.OffsetSEHolder.getheight(idx));
            else
                narginchk(1,1)
                coder.internal.errorIf(length(obj) ~= 1, 'images:offsetstrel:singleOffsetStrelOnly');
                offset = obj.OffsetSEHolder.getheight(varargin{:});
                offset(~obj.OffsetSEHolder.Neighborhood) = -coder.internal.inf;
            end
        end

        %==================================================================
        function len = getsequencelength(obj)
            if obj.UseConstantFoldingImpl
                len = coder.internal.const(obj.OffsetSEHolder.getsequencelength());
            else
                len = obj.OffsetSEHolder.getsequencelength();
            end
        end

        %==================================================================
        function TF = isdecompositionorthogonal(obj)
            if obj.UseConstantFoldingImpl
                TF = coder.internal.const(obj.OffsetSEHolder.isdecompositionorthogonal());
            else
                TF = obj.OffsetSEHolder.isdecompositionorthogonal();
            end
        end

        %==================================================================
        function TF = isflat(~,varargin)
            TF = false;
        end

        %==================================================================
        function [pad_ul, pad_lr] = getpadsize(obj)
            if obj.UseConstantFoldingImpl
                [pad_ul, pad_lr] = coder.internal.const(obj.OffsetSEHolder.getpadsize());
            else
                [pad_ul, pad_lr] = obj.OffsetSEHolder.getpadsize();
            end
        end
    end


    methods
        %==================================================================
        function Offset = get.Offset(obj, varargin)
            Offset = obj.OffsetSEHolder.getheight();
            Offset(~obj.OffsetSEHolder.Neighborhood) = -coder.internal.inf;
        end

        %==================================================================
        function dims = get.Dimensionality(obj)
            dims = ndims(obj.OffsetSEHolder.getnhood());
        end
    end

    methods (Static)
        function props = matlabCodegenNontunableProperties(~)
            % used for code generation
            props = {'params', 'UseConstantFoldingImpl', 'IsGPUTarget'};
        end
    end

    methods(Hidden = true)
        %==================================================================
        function obj = parenAssign(obj, rhs, idx, varargin)
            % offsetstrel does not support array of objects for codegeneration
            coder.internal.errorIf(true, 'images:offsetstrel:arraysNotSupportedForCodegen');

            % for creation of arrays, offsetstrel supports only one dimensional indexing
            coder.internal.errorIf(numel(varargin)>0, 'images:offsetstrel:oneDimIndexing');

            % validate the object that is appending to offsetstrel array
            coder.internal.errorIf(~isa(rhs, class(obj)), 'images:offsetstrel:cannotConvert', class(obj));

            if numel(obj) > 0
                if idx > numel(obj) && idx == numel(obj)+1
                    obj.OffsetSEHolder(idx) = rhs.OffsetSEHolder;
                end
            end

        end

        %==================================================================
        function obj = parenReference(obj, idx, varargin)
            % offsetstrel supports only one dimensional indexing
            coder.internal.errorIf(numel(varargin)>0, 'images:offsetstrel:oneDimIndexing');

            if ischar(idx) && strcmpi(idx, ':')
                return;
            elseif ischar(idx)
                coder.internal.errorIf(true, 'images:offsetstrel:oneDimIndexing');
            end

            tempOffsetSEHolder = obj.OffsetSEHolder(idx);
            obj.OffsetSEHolder = tempOffsetSEHolder;
        end

        %==================================================================
        function obj = horzcat(obj, varargin)
            % offsetstrel does not support array of objects for codegeneration
            coder.internal.errorIf(true, 'images:offsetstrel:arraysNotSupportedForCodegen');

            obj.OffsetSEHolder = horzcat(obj.OffsetSEHolder, varargin{:});
        end

        %==================================================================
        function obj = vertcat(obj, varargin)
            coder.internal.errorIf(true, 'images:offsetstrel:arraysNotSupportedForCodegen');
        end

        %==================================================================
        function obj = repmat(obj, varargin)
            obj.OffsetSEHolder = repmat(obj.OffsetSEHolder, varargin{:});
        end

        %==================================================================
        function n = numel(obj)
            n = numel(obj.OffsetSEHolder);
        end

        %==================================================================
        function sz = size(obj, varargin)
            sz = size(obj.OffsetSEHolder, varargin{:});
        end

        %==================================================================
        function is = isscalar(obj)
            is = numel(obj) == 1;
        end

        %==================================================================
        function ie = isempty(obj)
            ie = numel(obj) == 0;
        end

        %==================================================================
        function n = end(obj,varargin)
            % Only 1-D indexing is supported, so end is always numel.
            n = numel(obj.OffsetSEHolder);
        end

        %==================================================================
        function l = length(obj)
            if obj.UseConstantFoldingImpl
                l = length(obj.OffsetSEHolder);
            else
                % For a 1-D array, length is numel
                l = numel(obj);
            end
        end
    end

    %======================================================================
    % Helper Methods
    %======================================================================
    methods(Access = private)

        %==================================================================
        % checkConstantFolding
        %==================================================================
        function obj = checkConstantFolding(obj, varargin)
            coder.internal.prefer_const(varargin);
            obj.IsGPUTarget = coder.const(coder.gpu.internal.isGpuEnabled);

            % if all the inputs at compile time are constant-folded, then
            % tf is true otherwise false
            if numel(varargin) == 0
                isAllInputsConstantFolded = false;
            else
                for idx = coder.unroll(1:numel(varargin))
                    if coder.internal.isConst(varargin{idx})
                        isAllInputsConstantFolded = true;
                    else
                        isAllInputsConstantFolded = false;
                        break;
                    end
                end
            end

            if coder.const(isAllInputsConstantFolded) || coder.const(numel(varargin)) == 0
                % use constant folded implementation, when generating code with all
                % constant folded inputs
                TF = true;
            else
                % use non-constant folded implementation, when generating code with inputs
                % that all are not constant folded
                TF = false;
            end

            obj.UseConstantFoldingImpl  = coder.const(TF);
        end

        %==================================================================
        % makeOffsetStrel
        %==================================================================
        function obj = makeOffsetStrel(obj, varargin)
            if isnumeric(varargin{1})
                [~, nhood, height] = parseInputs(varargin{:});
                obj.OffsetSEHolder = strel('arbitrary', nhood, height);

            else
                [strelTypeEnum] = parseInputs(varargin{:});
                switch strelTypeEnum
                    case ARBITRARY
                        [~, nhood, height] = parseInputs(varargin{:});
                        obj.OffsetSEHolder = strel('arbitrary', nhood, height);
                    case BALL
                        [~, r, h, n] = parseInputs(varargin{:});
                        obj.OffsetSEHolder = strel('ball', r, h, n);

                    otherwise
                        coder.internal.errorIf(true, 'images:offsetstrel:unknownStrelType');
                end
            end
        end

    end

end

%==========================================================================
% Parse Inputs in Code Genertion
%==========================================================================
function [strelTypeEnum, argOut1, argOut2, argOut3] = parseInputs(varargin)
coder.inline('always');
coder.internal.prefer_const(varargin);
narginchk(1, 4);

default_ball_n = 8;

numArgs = numel(varargin);

sIdx = 1;
if ~ischar(varargin{1})
    type = 'arbitrary';
    strelTypeEnum = ARBITRARY;
    num_params = numArgs;

else
    valid_strings = {'arbitrary'
        'ball'};
    type = validatestring(varargin{1}, valid_strings, 'offsetstrel', ...
        'OFFSETSTREL_TYPE', 1);
    strelTypeEnum = stringToStrelType(char(varargin{1}));
    num_params = numArgs-1;
    sIdx = sIdx + 1;
end

switch strelTypeEnum
    case ARBITRARY
        if (num_params < 1)
            coder.internal.error('images:offsetstrel:tooFewInputs',type)
        end
        if (num_params > 1)
            coder.internal.error('images:offsetstrel:tooManyInputs',type)
        end

        if sIdx == 1
            height = varargin{1};
        else
            height = varargin{2};
        end
        validateattributes(height, {'double'}, {'real', 'nonnan'}, 'offsetstrel', ...
            'OFFSET', 1);
        nhood = isfinite(height);
        argOut1 = nhood;
        argOut2 = height;

    case BALL
        if (num_params < 2)
            coder.internal.error('images:offsetstrel:tooFewInputs',type);
        end
        if (num_params > 3)
            coder.internal.error('images:offsetstrel:tooManyInputs',type);
        end
        r = varargin{2};
        validateattributes(r, {'double'}, {'scalar' 'real' 'integer' 'nonnegative'}, ...
            'offsetstrel', 'R', 2);

        h = varargin{3};
        validateattributes(h, {'double'}, {'scalar' 'real'}, 'offsetstrel', 'H', 3);

        if (num_params < 3)
            n = default_ball_n;
        else
            n = varargin{4};
            validateattributes(n, {'double'}, {'scalar' 'integer' 'nonnegative' ...
                'even'}, 'offsetstrel', 'N', 4);
        end
        argOut1 = r;
        argOut2 = h;
        argOut3 = n;

    otherwise
        % This code should be unreachable.
        coder.internal.errorIf(true, 'images:offsetstrel:unrecognizedStrelType');
end
end

%--------------------------------------------------------------------------
function strelTypeEnum = stringToStrelType(strelTypeStr)
% Convert strel type string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(strelTypeStr, 'arbitrary', numel(strelTypeStr))
    strelTypeEnum = ARBITRARY;

elseif strncmpi(strelTypeStr, 'ball', numel(strelTypeStr))
    strelTypeEnum = BALL;
else
    % The code should be unreachable
    coder.internal.errorIf(true, 'images:strel:unrecognizedStrelType');
end
end

%--------------------------------------------------------------------------
function strelTypeFlag = ARBITRARY()
coder.inline('always');
strelTypeFlag = int8(2);
end

%--------------------------------------------------------------------------
function strelTypeFlag = BALL()
coder.inline('always');
strelTypeFlag = int8(12);
end