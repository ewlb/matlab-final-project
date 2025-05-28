classdef StructuringElementHelper < matlab.mixin.internal.indexing.ParenAssign & ...
        matlab.mixin.internal.indexing.Paren %#codegen
    % STRUCTURINGELEMENTHELPER Create morphological structuring element.
    
    % Copyright 2015-2022 The MathWorks, Inc.
    
    properties(Access = private, Hidden)
        StrelArray
        DecomposedStrelArray
    end
    
    properties(Dependent)
        Neighborhood
        Dimensionality
    end
    
    properties(Access = private)
        % Store input parameters of strel in params
        params
    end
    
    properties(Access = public, Transient, Hidden)
        UseConstantFoldingImpl
        IsGPUTarget
    end
    
    
    methods(Static, Hidden)
        function obj = makeuninitialized()
            coder.inline('always');
            se = strel(images.internal.coder.strel.uninitialized);
            obj = repmat(se, [1 0]);
        end
    end
    
    methods(Access=public)
        %==================================================================
        function obj = StructuringElementHelper(varargin)
            
            obj = checkConstantFolding(obj, varargin{:});
            
            if obj.UseConstantFoldingImpl
                eml_assert_all_constant(varargin{:});
                coder.internal.prefer_const(varargin{:});
                obj.params = varargin;
                % The input values in varargin are stored and not executed.
                % The following line is required for checking errors in the
                % constructor syntax. It has no other effect.
                coder.internal.const(feval('strel',varargin{:}));
            else
                obj = makeStrel(obj, varargin{:});
            end
        end
        
        %==================================================================
        function [seq, isEachStrelObj2D] = decompose(obj)
            coder.internal.errorIf(obj.UseConstantFoldingImpl, ...
                'images:strel:methodNotSupportedForCodegen','decompose');
            [seq, isEachStrelObj2D] = decomposeImpl(obj);
        end
        
        %==================================================================
        function seq = getsequence(obj)
            coder.internal.errorIf(obj.UseConstantFoldingImpl, ...
                'images:strel:methodNotSupportedForCodegen','getsequence');
            seq = decomposeImpl(obj);
        end
        
        %==================================================================
        function se2 = reflect(se1)
            coder.internal.errorIf(se1.UseConstantFoldingImpl, ...
                'images:strel:methodNotSupportedForCodegen','reflect');
            se2 = reflectImpl(se1);
        end
        
        %==================================================================
        function se2 = translate(se1, displacement)
            coder.internal.errorIf(se1.UseConstantFoldingImpl, ...
                'images:strel:methodNotSupportedForCodegen','translate');
            se2 = translateImpl(se1, displacement);
        end
        
        %==================================================================
        function disp(~)
            coder.internal.errorIf(true,'images:strel:methodNotSupportedForCodegen','disp');
        end
        
        %==================================================================
        function display(~) %#ok
            coder.internal.errorIf(true,'images:strel:methodNotSupportedForCodegen','display');
        end
        
        %==================================================================
        function TF = eq(~, se) %#ok<STOUT>
            coder.internal.errorIf(true,'images:strel:methodNotSupportedForCodegen','eq');
        end
        
        %==================================================================
        function TF = isequal(~,se) %#ok<STOUT>
            coder.internal.errorIf(true,'images:strel:methodNotSupportedForCodegen','isequal');
        end
        
        %==================================================================
        function se = loadobj(~) %#ok<STOUT>
            coder.internal.errorIf(true,'images:strel:methodNotSupportedForCodegen','loadobj');
        end
        
        %==================================================================
        function nhood = getnhood(obj, varargin)
            coder.extrinsic('images.internal.coder.strel.getnhood');
            
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
                
                nhood = coder.internal.const(...
                    images.internal.coder.strel.getnhood(...
                    idx, obj.params{:}));
            else
                narginchk(1,1)
                coder.internal.errorIf(length(obj) ~= 1, 'images:getnhood:wrongType');
                nhood = obj.StrelArray{1}.nhood;
            end
        end
        
        %==================================================================
        function height = getheight(obj, varargin)
            coder.extrinsic('images.internal.coder.strel.getheight');
            
            if obj.UseConstantFoldingImpl
                narginchk(1,2)
                if isempty(varargin)
                    idx = 0;
                else
                    idx = varargin{1};
                end
                
                height = coder.internal.const(...
                    images.internal.coder.strel.getheight(...
                    idx, obj.params{:}));
            else
                narginchk(1,1)
                coder.internal.errorIf(length(obj) ~= 1, 'images:getheight:wrongType');
                height = obj.StrelArray{1}.height;
            end
        end
        
        %==================================================================
        function [offsets, heights] = getneighbors(obj, varargin)
            coder.extrinsic('images.internal.coder.strel.getneighbors');
            
            if obj.UseConstantFoldingImpl
                narginchk(1,2)
                if isempty(varargin)
                    idx = 0;
                else
                    idx = varargin{1};
                end
                
                [offsets, heights] = coder.internal.const(...
                    images.internal.coder.strel.getneighbors(...
                    idx, obj.params{:}));
            else
                narginchk(1,1)
                coder.internal.errorIf(length(obj) ~= 1, 'images:getneighbors:wrongType');
                
                nhood = obj.getnhood;
                height= obj.getheight;
                
                [offsets, heights] = getneighborsImpl(nhood, height);
            end
        end
        
        %==================================================================
        function TF = isflat(obj, varargin)
            coder.extrinsic('images.internal.coder.strel.isflat');
            
            if obj.UseConstantFoldingImpl
                narginchk(1,2)
                
                if isempty(varargin)
                    idx = 0;
                else
                    idx = varargin{1};
                end
                
                TF = coder.internal.const(...
                    images.internal.coder.strel.isflat(...
                    idx, obj.params{:}));
            else
                if isscalar(obj)
                    TF = obj.StrelArray{1}.Flat;
                else
                    TF = false(1, numel(obj));
                    for k = 1:numel(obj)
                        TF(k) = obj.StrelArray{k}.Flat;
                    end
                end
            end
        end
        
        %==================================================================
        function n = getsequencelength(obj)
            coder.extrinsic('images.internal.coder.strel.getsequencelength');
            if obj.UseConstantFoldingImpl
                n = coder.internal.const(...
                    images.internal.coder.strel.getsequencelength(...
                    obj.params{:}));
            else
                seq = decomposeImpl(obj);
                n = length(seq);
            end
        end
        
        %==================================================================
        function TF = isdecompositionorthogonal(obj)
            coder.extrinsic('images.internal.coder.strel.isdecompositionorthogonal');
            if obj.UseConstantFoldingImpl
                TF = coder.internal.const(...
                    images.internal.coder.strel.isdecompositionorthogonal(...
                    obj.params{:}));
            else
                seq = decomposeImpl(obj);
                
                num_strels = numel(seq);
                
                P = ones(num_strels, 3);
                
                for sInd = 1:num_strels
                    nhood_size = size(seq.StrelArray{sInd}.nhood);
                    P(sInd,1:numel(nhood_size)) = nhood_size;
                end
                
                % Fill in trailing singleton dimensions as needed
                P(P==0) = 1;
                
                TF = any( sum(P~=1,1) == 1);
            end
        end
        
        %==================================================================
        function [pad_ul, pad_lr] = getpadsize(obj)
            coder.extrinsic('images.internal.coder.strel.getpadsize');
            
            if obj.UseConstantFoldingImpl
                [pad_ul, pad_lr] = coder.internal.const(...
                    images.internal.coder.strel.getpadsize(...
                    obj.params{:}));
            else
                seq = decomposeImpl(obj);
                num_strels = numel(seq);
                offsets    = cell(1,num_strels);
                
                for sInd = 1:num_strels
                    nhood = seq.StrelArray{sInd}.nhood;
                    height = seq.StrelArray{sInd}.height;
                    
                    offsets{sInd} = getneighborsImpl(nhood, height);
                end
                
                if isempty(offsets)
                    pad_ul = zeros(1,2);
                    pad_lr = zeros(1,2);
                    
                else
                    num_dims = size(offsets{1},2);
                    for k = 2:length(offsets)
                        num_dims = max(num_dims, size(offsets{k},2));
                    end
                    for k = 1:length(offsets)
                        offsets{k} = [offsets{k} zeros(size(offsets{k},1),...
                            num_dims - size(offsets{k},2))];
                    end
                    
                    pad_ul = zeros(1,num_dims);
                    pad_lr = zeros(1,num_dims);
                    
                    for k = 1:length(offsets)
                        offsets_k = offsets{k};
                        if ~isempty(offsets_k)
                            pad_ul = coder.sameSizeBinaryOp(@plus, pad_ul, max(0, -min(offsets_k,[],1)));
                            pad_lr = coder.sameSizeBinaryOp(@plus, pad_lr, max(0, max(offsets_k,[],1)));
                        end
                    end
                    
                end
            end
        end %getpadsize
        
    end
    
    methods
        %==================================================================
        function Neighborhood = get.Neighborhood(obj, varargin)
            coder.internal.errorIf(length(obj) ~= 1, 'images:strel:wrongType');
            Neighborhood = obj.getnhood();
        end
        
        %==================================================================
        function dims = get.Dimensionality(obj)
            coder.internal.errorIf(length(obj) ~= 1, 'images:strel:wrongType');
            dims = ndims(obj.getnhood());
        end
        
    end
    
    methods(Static)
        function props = matlabCodegenNontunableProperties(~)
            % used for code generation
            props = {'params', 'UseConstantFoldingImpl', 'IsGPUTarget'};
        end
    end
    
    
    methods(Hidden = true)
        %==================================================================
        function obj = parenAssign(obj, rhs, idx, varargin)
            % strel does not support array of objects for code generation
            coder.internal.errorIf(true, 'images:strel:arraysNotSupportedForCodegen');
            
            % For creation of arrays, strel supports only one dimensional indexing
            coder.internal.errorIf(numel(varargin)>0, 'images:strel:oneDimIndexing');
            
            % Validate the object that is appending to strel array
            coder.internal.errorIf(~isa(rhs, class(obj)), 'images:strel:cannotConvert', class(obj));
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            % Currently, It supports only to expand the array using one dimensional
            % indexing. Does not support to modify the existing object in the array
            if numel(obj) > 0
                if idx > numel(obj) && idx == numel(obj)+1
                    % copy over current elements
                    for  n = 1:numel(obj)
                        strelArray{end+1} = obj.StrelArray{n};
                        
                        % copy over decomposed elements
                        if numel(obj.DecomposedStrelArray{n}) > 0
                            for ii = 1:numel(obj.DecomposedStrelArray{n})
                                tempStrelArray{end+1} = obj.DecomposedStrelArray{n}{ii};
                            end
                        end
                        decomposedStrelArray{end+1} = tempStrelArray;
                        tempStrelArray = repmat({images.internal.coder.strel.StrelImpl}, 1, 0);
                    end
                    
                    % append new element (rhs)
                    strelArray{end+1} = rhs.StrelArray{1};
                    
                    % copy over decomposed elements (rhs)
                    if numel(rhs.DecomposedStrelArray{1}) > 0
                        for ii = 1:numel(rhs.DecomposedStrelArray{1})
                            tempStrelArray{end+1} = rhs.DecomposedStrelArray{1}{ii};
                        end
                    end
                    decomposedStrelArray{end+1} = tempStrelArray;
                end
            end
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            obj.StrelArray = strelArray;
            obj.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        function obj = parenReference(obj, idx, varargin)
            % strel supports only one dimensional indexing
            coder.internal.errorIf(numel(varargin)>0, 'images:strel:oneDimIndexing');
            
            if ischar(idx) && strcmpi(idx, ':')
                return;
            elseif ischar(idx)
                coder.internal.errorIf(true, 'images:strel:oneDimIndexing');
            end
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, ~] = initializeStrelData();
            
            for n = 1:numel(idx)
                strelArray{end+1} = obj.StrelArray{idx(n)};
                decomposedStrelArray{end+1} = obj.DecomposedStrelArray{idx(n)};
            end
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            obj.StrelArray = strelArray;
            obj.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        function obj = horzcat(obj, varargin)
            % strel does not support array of objects for code generation
            coder.internal.errorIf(true, 'images:strel:arraysNotSupportedForCodegen');
            
            coder.internal.assert(...
                isrow(obj), 'MATLAB:catenate:matrixDimensionMismatch');
            num = numel(varargin);
            for n = 1 : num
                coder.internal.assert(...
                    isa(varargin{n}, class(obj)), ...
                    'images:strel:invalidClass');
            end
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, ~] = initializeStrelData();
            
            % copy over current elements
            for n=1:numel(obj)
                strelArray{end+1} = obj.StrelArray{n};
                decomposedStrelArray{end+1} = obj.DecomposedStrelArray{n};
            end
            
            % copy over new elements
            for n=1:num
                for nn = 1:numel(varargin{n})
                    strelArray{end+1} = varargin{n}.StrelArray{nn};
                    decomposedStrelArray{end+1} =varargin{n}.DecomposedStrelArray{nn};
                end
            end
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            obj.StrelArray = strelArray;
            obj.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        function obj = vertcat(obj, varargin)
            coder.internal.errorIf(true, 'images:strel:arraysNotSupportedForCodegen');
        end
        
        %==================================================================
        function obj = repmat(obj, varargin)
            coder.internal.assert( numel(varargin)<3, ...
                'images:strel:oneDimIndexing');
            
            % validate repmat(obj,[a, b, ...]) syntax
            if numel(varargin)==1 && ~isscalar(varargin{1})
                in = varargin{1};
                
                % Only indexing up to two dimensions
                coder.internal.assert( numel(in)<=2 && ...
                    (in(1)<=1 || in(2)<=1), ...
                    'images:strel:oneDimIndexing');
            end
            
            if numel(varargin)==2 && isscalar(varargin{1}) && isscalar(varargin{2})
                coder.internal.assert( varargin{1} ==1 && varargin{2}<=1, ...
                    'images:strel:oneDimIndexing');
            end
            
            obj.StrelArray = repmat(obj.StrelArray, varargin{:});
            obj.DecomposedStrelArray = repmat(obj.DecomposedStrelArray, varargin{:});
        end
        
        %==================================================================
        function n = numel(obj)
            if obj.UseConstantFoldingImpl
                n = coder.internal.const(prod(size(obj))); %#ok
            else
                n = numel(obj.StrelArray);
            end
        end
        
        %==================================================================
        function sz = size(obj, varargin)
            coder.extrinsic('images.internal.coder.strel.getStrelSize');
            if obj.UseConstantFoldingImpl
                sz = coder.internal.const(images.internal.coder.strel.getStrelSize(obj.params, varargin{:}));
            else
                sz = size(obj.StrelArray, varargin{:});
            end
        end
        
        %==================================================================
        function is = isscalar(obj)
            if obj.UseConstantFoldingImpl
                is = coder.internal.const(length(obj) == 1);
            else
                is = numel(obj.StrelArray) == 1;
            end
        end
        
        %==================================================================
        function ie = isempty(obj)
            if obj.UseConstantFoldingImpl
                ie = coder.internal.const(length(obj) == 0); %#ok
            else
                ie = numel(obj.StrelArray) == 0;
            end
        end
        
        %==================================================================
        function n = end(obj,varargin)
            % Only 1-D indexing is supported, so end is always numel.
            n = numel(obj);
        end
        
        %==================================================================
        function l = length(obj)
            coder.extrinsic('images.internal.coder.strel.getStrelLength');
            if obj.UseConstantFoldingImpl
                l = coder.internal.const(images.internal.coder.strel.getStrelLength(obj.params{:}));
            else
                % For a 1-D array, length is numel
                l = numel(obj);
            end
        end
        
        %==================================================================
        function y = isrow(obj)
            if obj.UseConstantFoldingImpl
                y = coder.internal.const(size(obj,1) == 1);     
            else
                y = isrow(obj.StrelArray);
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
            
            if ~(coder.const(isAllInputsConstantFolded) || coder.const(numel(varargin)) == 0) || ...
                    (numel(varargin) == 1 && coder.const(isa(varargin{1}, 'images.internal.coder.strel.uninitialized'))) || ...
                    (numel(varargin) > 1 && coder.const(isa(varargin{end}, 'images.internal.coder.strel.uninitialized')))
                
                % use non-constant folded implementation, when generating code with inputs
                % that all are not constant folded
                TF = false;
            else
                % use constant folded implementation, when generating code with all
                % constant folded inputs
                TF = true;
            end
            
            obj.UseConstantFoldingImpl  = coder.const(TF);
        end
        
        %==================================================================
        % makeStrel
        %==================================================================
        function se = makeStrel(se, varargin)
            
            if (nargin == 2) && isa(varargin{1}, 'images.internal.coder.strel.uninitialized') || ...
                    (nargin > 2) && isa(varargin{end}, 'images.internal.coder.strel.uninitialized')
                se = makeStrel(se, varargin{1:end-1});
                return;
            end
            
            if (nargin == 1)
                % No input arguments --- return empty strel
                % default Type is arbitrary, even for empty strels.
                % Do Nothing
                se = makeArbitraryStrel(se, ARBITRARY, [], []);
                
            elseif (nargin == 2) && (isnumeric(varargin{1}) || islogical(varargin{1}))
                % Avoid string conversion etc for performance
                [strelTypeEnum, nhood, height] = parseInputs(varargin{:});
                se = makeArbitraryStrel(se, strelTypeEnum, nhood, height);
                
            else
                [strelTypeEnum] = parseInputs(varargin{:});
                
                switch strelTypeEnum
                    case ARBITRARY
                        [~, nhood, height] = parseInputs(varargin{:});
                        se = makeArbitraryStrel(se, strelTypeEnum, nhood, height);
                        
                    case SQUARE
                        [~, M] = parseInputs(varargin{:});
                        se = makeSquareStrel(se, strelTypeEnum, M);
                        
                    case DIAMOND
                        [~, M] = parseInputs(varargin{:});
                        se = makeDiamondStrel(se, M);
                        
                    case RECTANGLE
                        [~, MN] = parseInputs(varargin{:});
                        se = makeRectangleStrel(se, strelTypeEnum, MN);
                        
                    case OCTAGON
                        [~, M] = parseInputs(varargin{:});
                        se = makeOctagonStrel(se, M);
                        
                    case LINE
                        [~, len, deg] = parseInputs(varargin{:});
                        se = makeLineStrel(se, len, deg);
                        
                    case PAIR
                        [~, offset] = parseInputs(varargin{:});
                        se = makePairStrel(se, offset);
                        
                    case PERIODICLINE
                        [~, p, v] = parseInputs(varargin{:});
                        se = makePeriodicLineStrel(se, p, v);
                        
                    case DISK
                        [~, r, n] = parseInputs(varargin{:});
                        se = makeDiskStrel(se, r, n);
                        
                    case BALL
                        [~, r, h, n] = parseInputs(varargin{:});
                        se = makeBallStrel(se, r, h, n);
                        
                    case SPHERE
                        [~, r] = parseInputs(varargin{:});
                        se = makeSphereStrel(se, r);
                        
                    case CUBE
                        [~, width] = parseInputs(varargin{:});
                        se = makeCubeStrel(se, strelTypeEnum, width);
                        
                    case CUBOID
                        [~, XYZ] = parseInputs(varargin{:});
                        se = makeCuboidStrel(se, strelTypeEnum, XYZ);
                        
                    otherwise
                        coder.internal.errorIf(true, 'images:strel:unknownStrelType');
                end
            end
        end
        
        %==================================================================
        % decomposeImpl
        %==================================================================
        function [seq, isEachStrelObj2D] = decomposeImpl(obj)
            [seq, isEachStrelObj2D] = decomposeReflectAndTranslateAlgo(@decompose, obj);
        end
        
        %==================================================================
        % reflectImpl
        %==================================================================
        function se2 = reflectImpl(se1)
            se2 = decomposeReflectAndTranslateAlgo(@reflect, se1);
        end
        
        %==================================================================
        % translateImpl
        %==================================================================
        function se2 = translateImpl(se1, displacement)
            coder.internal.errorIf( ~isa(se1,'strel'), 'images:translate:wrongType');
            coder.internal.errorIf(~isa(displacement,'double'), 'images:translate:invalidInputDouble');
            
            if any(displacement ~= floor(displacement))
                coder.internal.error('images:translate:invalidInput');
            end
            
            se2 = decomposeReflectAndTranslateAlgo(@translate, se1, displacement);
        end
        
        %==================================================================
        % makeArbitraryStrel
        %==================================================================
        function se = makeArbitraryStrel(se, typeEnum, nhood, height)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(typeEnum, nhood, height);
            
            if (~isempty(nhood) && all(nhood(:)) && ~any(height(:)))
                % Strel is flat with an all-ones neighborhood.  Decide whether to decompose
                % it.
                size_nhood = size(nhood);
                % Heuristic --- if theoretical computation advantage is
                % at least a factor of two, then assume that the advantage
                % is worth the overhead cost of performing dilation or erosion twice.
                
                advantage = prod(size_nhood) / sum(size_nhood);
                
                if (advantage >= 2)
                    if ismatrix(nhood)
                        for k = 1:2
                            size_k = ones(1,3);
                            size_k(k) = size(nhood,k);
                            tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(ones(size_k));
                        end
                    else
                        for k = 1:3
                            size_k = ones(1,3);
                            size_k(k) = size(nhood,k);
                            tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(ones(size_k));
                        end
                    end
                end
            end
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makeSquareStrel
        %==================================================================
        function se = makeSquareStrel(se, typeEnum, M)
            
            se = makeArbitraryStrel(se, typeEnum, ones(M, M), zeros(M, M));
            
        end
        
        %==================================================================
        % makeRectangleStrel
        %==================================================================
        function se = makeRectangleStrel(se, typeEnum, MN)
            
            se = makeArbitraryStrel(se, typeEnum, ones(MN(1), MN(2)), zeros(MN(1), MN(2)));
            
        end
        
        %==================================================================
        % makeDiamondStrel
        %==================================================================
        function se = makeDiamondStrel(se, M)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            [rr,cc] = meshgrid(-M:M);
            nhood = (abs(rr) + abs(cc)) <= M;
            height = zeros(size(nhood));
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(DIAMOND, nhood, height);
            
            % Heuristic --- if M > 2, assume computational advantage of decomposition
            % is worth the cost of performing multiple dilations (or erosions).
            if (M > 2)
                % Compute the logarithmic decomposition of the strel using the method in
                % Rein van den Boomgard and Richard van Balen, "Methods for Fast
                % Morphological Image Transforms Using Bitmapped Binary Images," CVGIP:
                % Models and Image Processing, vol. 54, no. 3, May 1992, pp. 252-254.
                
                n = floor(log2(M));
                
                tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl([0 1 0; 1 1 1; 0 1 0]);
                
                for k = 0:(n-1)
                    P = 2^(k+1) + 1;
                    middle = (P+1)/2;
                    nhood = zeros(P,P);
                    nhood(1,middle) = 1;
                    nhood(P,middle) = 1;
                    nhood(middle,1) = 1;
                    nhood(middle,P) = 1;
                    tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(nhood);
                end
                
                q = M - 2^n;
                if (q > 0)
                    P = 2*q+1;
                    middle = (P+1)/2;
                    nhood = zeros(P,P);
                    nhood(1,middle) = 1;
                    nhood(P,middle) = 1;
                    nhood(middle,1) = 1;
                    nhood(middle,P) = 1;
                    tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(nhood);
                end
            end
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makeOctagonStrel
        %==================================================================
        function se = makeOctagonStrel(se, M)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            % The ParseInputs routine checks to make sure M is a multiple of 3.
            k = M/3;
            [rr,cc] = meshgrid(-M:M);
            nhood = abs(rr) + abs(cc) <= M + k;
            height = zeros(size(nhood));
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(OCTAGON, nhood, height);
            
            % Compute the decomposition.  To decompose an octagonal strel for M=3k,
            % first the strel is decomposed into k strels that each have M=3.  Then,
            % each M=3 strel is further (recursively) decomposed into 4 line-segment
            % strels.
            if (k >= 1)
                % Decompose into 4*k strels, each of which have a 3x3 neighborhood.
                a = [0 0 0; 1 1 1; 0 0 0];
                b = a';
                c = eye(3);
                d = rot90(c);
                
                tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(a);
                tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(b);
                tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(c);
                tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(d);
                tempStrelArray = repmat(tempStrelArray, 1, k);
            end
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makePairStrel
        %==================================================================
        function se = makePairStrel(se, MN)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            size_nhood = abs(MN) * 2 + 1;
            nhood = false(size_nhood);
            center = floor((size_nhood + 1)/2);
            nhood(center(1),center(2)) = 1;
            nhood(center(1) + MN(1), center(2) + MN(2)) = 1;
            height = zeros(size_nhood);
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(PAIR, nhood, height);
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makeLineStrel
        %==================================================================
        function se = makeLineStrel(se, len, theta_d)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            [nhood, height] = getNhoodAndHeightFromLineParams(len, theta_d);
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(LINE, nhood, height);
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makePeriodicLineStrel
        %==================================================================
        function se = makePeriodicLineStrel(se, p, v)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            [nhood, height] = getNhoodAndHeightFromPeriodicLineParams(p, v);
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(PERIODICLINE, nhood, height);
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makeDiskStrel
        %==================================================================
        function se = makeDiskStrel(se, r, n)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            if (r < 3)
                % Radius is too small to use decomposition, so force n=0.
                n = 0;
            end
            
            if (n == 0)
                % Use simple Euclidean distance formula to find the disk neighborhood.  No
                % decomposition.
                [xx,yy] = meshgrid(-r:r);
                nhood = xx.^2 + yy.^2 <= r^2;
                
            else
                % Determine the set of "basis" vectors to be used for the
                % decomposition.  The rows of v will be used as offset vectors for
                % periodic line strels.
                switch n
                    case 4
                        v = [ 1 0
                            1 1
                            0 1
                            -1 1];
                        
                    case 6
                        v = [ 1 0
                            1 2
                            2 1
                            0 1
                            -1 2
                            -2 1];
                        
                    case 8
                        v = [ 1 0
                            2 1
                            1 1
                            1 2
                            0 1
                            -1 2
                            -1 1
                            -2 1];
                        
                    otherwise
                        % This error should have been caught already in ParseInputs.
                        coder.internal.error('images:getheight:invalidN');
                end
                
                % Determine k, which is the desired radial extent of the periodic
                % line strels.  For the origin of this formula, see the second
                % paragraph on page 328 of the Rolf Adams paper.
                theta = pi/(2*n);
                k = 2*r/(cot(theta) + 1/sin(theta));
                % For each periodic line strel, determine the repetition parameter,
                % rp.  The use of floor() in the computation means that the resulting
                % strel will be a little small, but we will compensate for this
                % below.
                
                % Initialize Strel Data to create local strel object
                [~, decomposedData, tempData] = initializeStrelData();
                
                for q = 1:n
                    rp = floor(k / norm(v(q,:)));
                    [nhood_local, height_local] = getNhoodAndHeightFromPeriodicLineParams(rp, v(q,:));
                    
                    % Create periodic line strels and append to decomposed strel array
                    tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(PERIODICLINE, nhood_local, height_local);
                    decomposedData{end+1} = tempData;
                end
                
                % Create strel object for dilation
                strelObj = images.internal.coder.strel.StructuringElementHelper.makeuninitialized();
                strelObj.StrelArray = tempStrelArray;
                strelObj.DecomposedStrelArray = decomposedData;
                
                % Now dilate the strels in the decomposition together to see how
                % close we came to the desired disk radius.
                
                % By using single datatype take IPP codepath instead of openCV(only for
                % double datatype) in images.internal.morphop
                % nhood = imdilate(single(1), strel_tmp, 'full');
                nhood = imdilate(single(1), strelObj, 'full');
                nhood = nhood > 0;
                if ismatrix(nhood)
                    if ~isrow(nhood)
                        [rd,~] = find(nhood);
                    else
                        nhood_ = nhood(:);
                        [rd,~] = find(nhood_);
                    end
                else
                    [rd,~] = find(nhood);
                end
                
                M = size(nhood,1);
                rd = rd - floor((M+1)/2);
                max_horiz_radius = max(rd(:));
                radial_difference = r - max_horiz_radius;
                
                % Reset Data
                [data, decomposedData, ~] = initializeStrelData();
                
                % Now we are going to add additional vertical and horizontal line
                % strels to compensate for the fact that the strel resulting from the
                % above decomposition tends to be smaller than the desired size.
                len = 2*(radial_difference-1) + 1;
                if (len >= 3)
                    % Add horizontal and vertical line strels.
                    [nhood_local, height_local] = getNhoodAndHeightFromLineParams(len, 0);
                    tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(LINE, nhood_local, height_local);
                    data{end+1} = images.internal.coder.strel.StrelImpl(LINE, nhood_local, height_local);
                    decomposedData{end+1} = tempData;
                    
                    [nhood_local, height_local] = getNhoodAndHeightFromLineParams(len, 90);
                    tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(LINE, nhood_local, height_local);
                    data{end+1} = images.internal.coder.strel.StrelImpl(LINE, nhood_local, height_local);
                    decomposedData{end+1} = tempData;
                    
                    % Update the computed neighborhood to reflect the additional strels in
                    % the decomposition.
                    strelObj.StrelArray = data;
                    strelObj.DecomposedStrelArray = decomposedData;
                    nhood = imdilate(nhood, strelObj, 'full');
                    nhood = nhood > 0;
                end
                
            end
            
            height = zeros(size(nhood));
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(DISK, nhood, height);
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
            
        end
        
        %==================================================================
        % makeBallStrel
        %==================================================================
        function se = makeBallStrel(se,r,h,n)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            if (r == 0)
                % Make a unit strel.
                nhood = true;
                height = h;
                
            elseif (n == 0)
                % Use Euclidean distance and ellipsoid formulas to construct strel;
                % no decomposition used.
                [xx,yy] = meshgrid(-r:r);
                nhood = xx.^2 + yy.^2 <= r^2;
                height = h * sqrt(r^2 - min(r^2,xx.^2 + yy.^2)) / r;
                
            else
                % Radial decomposition of a sphere.  Reference is the Rolf Adams
                % paper listed above.
                
                % Height profile for each radial line strel is given by a parametric
                % formula of the form (a, g(a)), where a is a function of beta.  See
                % page 331 of the Rolf Adams paper.  Our strategy for using this
                % function is to create a table of (a,g(a)) values and then
                % interpolate into this table.
                beta = linspace(0,pi,100)';
                a = beta - pi/2 - sin(beta).*cos(beta);
                g_a = sin(beta).^2;
                
                % Length of each line strel.
                L = pi*r/n;
                
                % Compute the end-point coordinates of each line strel.
                theta = pi * (0:(n/2 - 1))' / n;
                xy = round(L/2 * [cos(theta) sin(theta)]);
                xy = [xy ; [-xy(:,2) xy(:,1)]];
                
                % Initialize Strel Data to create local strel object
                [~, decomposedData, tempData] = initializeStrelData();
                
                for k = 1:n
                    % For each line strel, compute the x-y coordinates of the elements
                    % of the strel, and also compute the corresponding height.
                    x = xy(k,1);
                    y = xy(k,2);
                    [xx,yy] = iptui.intline(0,x,0,y);
                    xx = [xx; -xx(2:end,1)]; %#ok<AGROW>
                    yy = [yy; -yy(2:end,1)]; %#ok<AGROW>
                    
                    dist = sqrt(xx.^2 + yy.^2);
                    ap = dist*n/r;
                    z = h/n * interp1q(a, g_a, ap);
                    
                    % We could have nan's at the end-points now; replace them by 0.
                    z(isnan(z)) = 0;
                    
                    % Now form neighborhood and height matrices with which we can call
                    % strel.
                    xmin = min(xx);
                    ymin = min(yy);
                    M = -2*ymin + 1;
                    N = -2*xmin + 1;
                    localNhood = false(M,N);
                    localHeight = zeros(M,N);
                    row = yy - ymin + 1;
                    col = xx - xmin + 1;
                    idx = row + M*(col-1);
                    localNhood(idx) = 1;
                    localHeight(idx) = z;
                    
                    % Create arbitrary strels and append to decomposed strel array
                    tempStrelArray{end+1} = images.internal.coder.strel.StrelImpl(ARBITRARY, localNhood, localHeight);
                    decomposedData{end+1} = tempData;
                end
                
                % Create strel object for dilation
                strelObj = images.internal.coder.strel.StructuringElementHelper.makeuninitialized();
                strelObj.StrelArray = tempStrelArray;
                strelObj.DecomposedStrelArray = decomposedData;
                
                % Now compute the neighborhood and height of the strel resulting the radial
                % decomposition.
                height = imdilate(0, strelObj, 'full');
                nhood = isfinite(height);
                
            end
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(BALL, nhood, height);
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makeSphereStrel
        %==================================================================
        function se = makeSphereStrel(se, r)
            
            % Initialize Strel Data
            [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();
            
            [x,y,z] = meshgrid(-r:r,-r:r,-r:r);
            nhood =  ( (x/r).^2 + (y/r).^2 + (z/r).^2 ) <= 1;
            height = zeros(size(nhood));
            
            % Append the strel
            strelArray{end+1} = images.internal.coder.strel.StrelImpl(SPHERE, nhood, height);
            
            % Append the decomposed strels
            decomposedStrelArray{end+1} = tempStrelArray;
            
            % Assign strel & decomposed strel arrays to corresponding
            % properties StrelArray & DecomposedStrelArray
            se.StrelArray = strelArray;
            se.DecomposedStrelArray = decomposedStrelArray;
        end
        
        %==================================================================
        % makeCubeStrel
        %==================================================================
        function se = makeCubeStrel(se, typeEnum, width)
            
            se = makeArbitraryStrel(se, typeEnum, true(width,width,width), zeros(width, width, width));
            
        end
        
        %==================================================================
        % makeCuboidStrel
        %==================================================================
        function se = makeCuboidStrel(se, typeEnum, XYZ)
            
            se = makeArbitraryStrel(se, typeEnum, true(XYZ(1), XYZ(2), XYZ(3)), zeros(XYZ(1), XYZ(2), XYZ(3)));
            
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
default_disk_n = 4;

numArgs = numel(varargin);

sIdx = 1;
if ~(ischar(varargin{1}) || isstring(varargin{1}))
    type = 'arbitrary';
    strelTypeEnum = ARBITRARY;
    num_params = numArgs;
else
    valid_strings = {'arbitrary', 'square', 'diamond', 'rectangle', ...
        'octagon', 'line', 'disk', 'sphere', 'cube', 'cuboid', 'ball', ...
        'pair', 'periodicline'};
    
    validatestring(varargin{1}, valid_strings, 'strel', ...
        'STREL_TYPE', 1);
    
    type = char(varargin{1});
    strelTypeEnum = stringToStrelType(char(varargin{1}));
    num_params = numArgs-1;
    sIdx = sIdx + 1;
end

switch strelTypeEnum
    case ARBITRARY
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs',type);
        coder.internal.errorIf(num_params > 2, 'images:strel:tooManyInputs',type);
        
        % Check validity of the NHOOD argument.
        if sIdx == 1
            nhood = varargin{1};
        else
            nhood = varargin{2};
        end
        validateattributes(nhood, {'numeric', 'logical'}, {'real'}, 'strel', ...
            'NHOOD', 2);
        
        % Check validity of the HEIGHT argument.
        if num_params >= 2
            if sIdx == 1
                height = varargin{2};
            else
                height = varargin{3};
            end
            validateattributes(height, {'double'}, {'real', 'nonnan'}, 'strel', ...
                'HEIGHT', 3);
            
            coder.internal.errorIf(~isequal(size(height), size(nhood)), 'images:strel:sizeMismatch')
            
        else
            height = zeros(size(nhood));
        end
        
        argOut1 = nhood;
        argOut2 = height;
        
    case SQUARE
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type)
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs', type)
        
        M = varargin{2};
        validateattributes(M, {'double'}, {'scalar' 'integer' 'real' 'nonnegative'}, ...
            'strel', 'SIZE', 2);
        
        argOut1 = M;
        
    case DIAMOND
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs', type);
        
        M = varargin{2};
        validateattributes(M, {'double'}, {'scalar' 'integer' 'nonnegative'}, ...
            'strel', 'SIZE', 2);
        argOut1 = M;
        
    case OCTAGON
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs', type);
        
        M = varargin{2};
        validateattributes(M, {'double'}, {'scalar' 'integer' 'nonnegative'}, ...
            'strel', 'SIZE', 2);
        
        coder.internal.errorIf(rem(M,3) ~= 0, 'images:strel:notMultipleOf3');
        argOut1 = M;
        
    case RECTANGLE
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs', type);
        
        MN = varargin{2};
        validateattributes(MN, {'double'}, {'vector' 'real' 'integer' 'nonnegative'}, ...
            'strel', 'SIZE', 2);
        
        coder.internal.errorIf(numel(MN) ~= 2, 'images:strel:badSizeForRectangle')
        argOut1 = MN;
        
    case PAIR
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs', type);
        
        RC = varargin{2};
        validateattributes(RC, {'double'}, {'vector' 'real' 'integer'}, ...
            'strel', 'OFFSET', 2);
        
        coder.internal.errorIf(numel(RC) ~= 2, 'images:strel:badOffsetsForPair')
        argOut1 = RC;
        
    case LINE
        coder.internal.errorIf(num_params < 2, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 2, 'images:strel:tooManyInputs', type);
        
        len = varargin{2};
        validateattributes(len, {'double'}, {'scalar' 'real' 'finite' 'nonnegative'}, ...
            'strel', 'LEN', 2);
        deg = varargin{3};
        validateattributes(deg, {'double'}, {'scalar' 'real' 'finite'}, 'strel', 'DEG', 3);
        argOut1 = len;
        argOut2 = deg;
        
    case PERIODICLINE
        coder.internal.errorIf(num_params < 2, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 2, 'images:strel:tooManyInputs', type);
        
        p = varargin{2};
        validateattributes(p, {'double'}, {'scalar' 'real' 'integer' 'nonnegative'}, ...
            'strel', 'P', 2);
        
        v = varargin{3};
        validateattributes(v, {'double'}, {'vector' 'real' 'integer'}, 'strel', ...
            'V', 3);
        
        coder.internal.errorIf(numel(v) ~= 2, 'images:strel:wrongSizeForV');
        
        argOut1 = p;
        argOut2 = v;
        
    case DISK
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 2, 'images:strel:tooManyInputs', type);
        
        r = varargin{2};
        validateattributes(r,{'double'}, {'scalar' 'real' 'integer' 'nonnegative'}, ...
            'strel', 'R', 2);
        
        if (num_params < 2)
            n = default_disk_n;
        else
            n = varargin{3};
            validateattributes(n, {'double'}, {'scalar' 'real' 'integer'}, ...
                'strel', 'N', 3);
            
            coder.internal.errorIf(((n ~= 0) && (n ~= 4) && (n ~= 6) && (n ~= 8)), ...
                'images:strel:invalidN');
        end
        argOut1 = r;
        argOut2 = n;
        
    case BALL
        coder.internal.errorIf(num_params < 2, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 3, 'images:strel:tooManyInputs', type);
        
        r = varargin{2};
        validateattributes(r, {'double'}, {'scalar' 'real' 'integer' 'nonnegative'}, ...
            'strel', 'R', 2);
        
        h = varargin{3};
        validateattributes(h, {'double'}, {'scalar' 'real'}, 'strel', 'H', 3);
        
        if (num_params < 3)
            n = default_ball_n;
        else
            n = varargin{4};
            validateattributes(n, {'double'}, {'scalar' 'integer' 'nonnegative' ...
                'even'}, 'strel', 'N', 4);
        end
        argOut1 = r;
        argOut2 = h;
        argOut3 = n;
        
    case SPHERE
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs',type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs',type);
        
        r = varargin{2};
        validateattributes(r, {'double'}, {'scalar' 'integer' 'nonnegative'}, ...
            'strel', 'R', 2);
        argOut1 = r;
        
    case CUBE
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs',type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs',type);
        
        width = varargin{2};
        validateattributes(width, {'double'}, {'scalar' 'integer' 'nonnegative'}, ...
            'strel', 'WIDTH', 2);
        argOut1 = width;
        
    case CUBOID
        coder.internal.errorIf(num_params < 1, 'images:strel:tooFewInputs', type);
        coder.internal.errorIf(num_params > 1, 'images:strel:tooManyInputs', type);
        
        XYZ = varargin{2};
        validateattributes(XYZ, {'double'}, {'vector' 'integer' 'nonnegative'}, ...
            'strel', 'SIZE', 2);
        coder.internal.errorIf(numel(XYZ) ~= 3, 'images:strel:badSizeForCuboid');
        argOut1 = XYZ;
        
    otherwise
        % This code should be unreachable.
        coder.internal.errorIf(true, 'images:strel:unrecognizedStrelType');
end
end

%--------------------------------------------------------------------------
function strelTypeEnum = stringToStrelType(strelTypeStr)
% Convert strel type string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(strelTypeStr, 'arbitrary', numel(strelTypeStr))
    strelTypeEnum = ARBITRARY;
elseif strncmpi(strelTypeStr, 'square', numel(strelTypeStr))
    strelTypeEnum = SQUARE;
elseif strncmpi(strelTypeStr, 'diamond', numel(strelTypeStr))
    strelTypeEnum = DIAMOND;
elseif strncmpi(strelTypeStr, 'octagon', numel(strelTypeStr))
    strelTypeEnum = OCTAGON;
elseif strncmpi(strelTypeStr, 'rectangle', numel(strelTypeStr))
    strelTypeEnum = RECTANGLE;
elseif strncmpi(strelTypeStr, 'pair', numel(strelTypeStr))
    strelTypeEnum = PAIR;
elseif strncmpi(strelTypeStr, 'line', numel(strelTypeStr))
    strelTypeEnum = LINE;
elseif strncmpi(strelTypeStr, 'periodicline', numel(strelTypeStr))
    strelTypeEnum = PERIODICLINE;
elseif strncmpi(strelTypeStr, 'disk', numel(strelTypeStr))
    strelTypeEnum = DISK;
elseif strncmpi(strelTypeStr, 'ball', numel(strelTypeStr))
    strelTypeEnum = BALL;
elseif strncmpi(strelTypeStr, 'sphere', numel(strelTypeStr))
    strelTypeEnum = SPHERE;
elseif strncmpi(strelTypeStr, 'cube', numel(strelTypeStr))
    strelTypeEnum = CUBE;
elseif strncmpi(strelTypeStr, 'cuboid', numel(strelTypeStr))
    strelTypeEnum = CUBOID;
else
    % This code should be unreachable.
    coder.internal.errorIf(true, 'images:strel:unrecognizedStrelType')
end
end

%--------------------------------------------------------------------------
function type = strelTypeToString(strelTypeEnum)
switch strelTypeEnum
    case ARBITRARY
        type = 'arbitrary';
    case SQUARE
        type = 'square';
    case DIAMOND
        type = 'diamond';
    case OCTAGON
        type = 'octagon';
    case RECTANGLE
        type = 'rectangle';
    case PAIR
        type = 'pair';
    case LINE
        type = 'line';
    case PERIODICLINE
        type = 'periodicline';
    case DISK
        type = 'disk';
    case BALL
        type = 'ball';
    case SPHERE
        type = 'sphere';
    case CUBE
        type = 'cube';
    case CUBOID
        type = 'cuboid';
    otherwise
        % This code should be unreachable.
        coder.internal.errorIf(true, 'images:strel:unrecognizedStrelType')
end
end

%--------------------------------------------------------------------------
function strelTypeFlag = ARBITRARY()
coder.inline('always');
strelTypeFlag = int8(2);
end

%--------------------------------------------------------------------------
function strelTypeFlag = SQUARE()
coder.inline('always');
strelTypeFlag = int8(3);
end

%--------------------------------------------------------------------------
function strelTypeFlag = DIAMOND()
coder.inline('always');
strelTypeFlag = int8(4);
end

%--------------------------------------------------------------------------
function strelTypeFlag = RECTANGLE()
coder.inline('always');
strelTypeFlag = int8(5);
end

%--------------------------------------------------------------------------
function strelTypeFlag = OCTAGON()
coder.inline('always');
strelTypeFlag = int8(6);
end

%--------------------------------------------------------------------------
function strelTypeFlag = LINE()
coder.inline('always');
strelTypeFlag = int8(7);
end

%--------------------------------------------------------------------------
function strelTypeFlag = DISK()
coder.inline('always');
strelTypeFlag = int8(8);
end

%--------------------------------------------------------------------------
function strelTypeFlag = SPHERE()
coder.inline('always');
strelTypeFlag = int8(9);
end

%--------------------------------------------------------------------------
function strelTypeFlag = CUBE()
coder.inline('always');
strelTypeFlag = int8(10);
end

%--------------------------------------------------------------------------
function strelTypeFlag = CUBOID()
coder.inline('always');
strelTypeFlag = int8(11);
end

%--------------------------------------------------------------------------
function strelTypeFlag = BALL()
coder.inline('always');
strelTypeFlag = int8(12);
end

%--------------------------------------------------------------------------
function strelTypeFlag = PAIR()
coder.inline('always');
strelTypeFlag = int8(13);
end

%--------------------------------------------------------------------------
function strelTypeFlag = PERIODICLINE()
coder.inline('always');
strelTypeFlag = int8(14);
end

%--------------------------------------------------------------------------
function [nhood, height] = getNhoodAndHeightFromLineParams(len, theta_d)
if (len >= 1)
    % The line is constructed so that it is always symmetric with respect
    % to the origin. Theta is mod(180) to return consistent angles for
    % inputs that are outside the [0, 180] range.
    theta = mod(theta_d, 180) * pi / 180;
    x = round((len-1)/2 * cos(theta));
    y = -round((len-1)/2 * sin(theta));
    [c,r] = iptui.intline(-x,x,-y,y);
    M = 2*max(abs(r)) + 1;
    N = 2*max(abs(c)) + 1;
    nhood = false(M,N);
    idx = sub2ind([M N], r + max(abs(r)) + 1, c + max(abs(c)) + 1);
    nhood(idx) = 1;
    height = zeros(M,N);
else
    % Do nothing here, return empty nhood and height
    nhood = logical([]);
    height = [];
end
end

%--------------------------------------------------------------------------
function [nhood, height] = getNhoodAndHeightFromPeriodicLineParams(p, v)
v = v(:)';
p = (-p:p)';
pp = repmat(p,1,2);
rc = bsxfun(@times, pp, v);
r = rc(:,1);
c = rc(:,2);
M = 2*max(abs(r)) + 1;
N = 2*max(abs(c)) + 1;
nhood = false(M,N);
idx = sub2ind([M N], r + max(abs(r)) + 1, c + max(abs(c)) + 1);
nhood(idx) = 1;
height = zeros(M,N);
end

%--------------------------------------------------------------------------
function [offsets, heights] = getneighborsImpl(nhood, height)
num_dims = numel(size(nhood));

if ismatrix(nhood) && isrow(nhood)
    % Handle separately when the nhood is row vector at run time
    nhood_ = nhood(:);
    idx = find(nhood_);
else
    idx = find(nhood);
end

heights_ = height(:);
tmpHeight = heights_(nhood(:) ~= 0);

if ismatrix(nhood)
    if isrow(nhood)
        heights = tmpHeight';
    else
        heights = tmpHeight;
    end
else
    if size(nhood,1) == 1 && size(nhood,2) == 1
        heights = reshape(tmpHeight, [1 1 numel(tmpHeight)]);
    else
        heights = tmpHeight;
    end
end

size_nhood = size(nhood);
center = floor((size_nhood+1)/2);

subs = cell(1, num_dims);
[subs{:}] = ind2sub(size_nhood,idx);
offsets_ = [subs{:}];
offsets_ = reshape(offsets_, length(idx),num_dims);
offsets_ = bsxfun(@minus, offsets_, center);

if ismatrix(nhood)
    offsets = offsets_(:,1:2);
else
    offsets = offsets_;
end
end

%--------------------------------------------------------------------------
function [se2, isEachInputStrel2D] = decomposeReflectAndTranslateAlgo(fHandle, se1, varargin)
coder.inline('always');
se2 = images.internal.coder.strel.StructuringElementHelper.makeuninitialized();

[strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData();

% array of strels
numStrels = numel(se1);

if isequal(fHandle, @decompose) % decompose impl
    if nargout > 1
        isEachInputStrel2D = zeros(1, coder.ignoreSize(0), 'logical');
    end
    for len = 1:numStrels
        if numel(se1.DecomposedStrelArray{len}) == 0
            strelArray{end+1} = se1.StrelArray{len};
            decomposedStrelArray{end+1} = tempStrelArray;
            if nargout > 1
                isEachInputStrel2D = [isEachInputStrel2D ismatrix(se1.StrelArray{len}.nhood)]; %#ok<AGROW>
            end
        else
            for n = 1:numel(se1.DecomposedStrelArray{len})
                strelArray{end+1} = se1.DecomposedStrelArray{len}{n};
                decomposedStrelArray{end+1} = tempStrelArray;
                if nargout > 1
                    isEachInputStrel2D = [isEachInputStrel2D ismatrix(se1.StrelArray{len}.nhood)]; %#ok<AGROW>
                end
            end
        end
        tempStrelArray = repmat({images.internal.coder.strel.StrelImpl}, 1, 0);
    end
else % reflect & translate impl
    for len = 1:numStrels
        strelArray{end+1} = fHandle(se1.StrelArray{len}, varargin{:});
        for n = 1:numel(se1.DecomposedStrelArray{len})
            tempStrelArray{end+1} = fHandle(se1.DecomposedStrelArray{len}{n}, varargin{:});
        end
        
        decomposedStrelArray{end+1} = tempStrelArray;
        tempStrelArray = repmat({images.internal.coder.strel.StrelImpl}, 1, 0);
    end
end

se2.StrelArray = strelArray;
se2.DecomposedStrelArray = decomposedStrelArray;
end

%--------------------------------------------------------------------------
function [strelArray, decomposedStrelArray, tempStrelArray] = initializeStrelData()
coder.inline('always');

% Using coder.ignoreConst here to prevent the 2nd dimension to be constant
% and to create variable size cell array. One has to use `end+1` idiom to
% expand these variable size cell arrays in code generation

strelArray = repmat({images.internal.coder.strel.StrelImpl}, ...
    1, coder.ignoreConst(0));

decomposedStrelArray = repmat( ...
    {repmat({images.internal.coder.strel.StrelImpl}, ...
    1, coder.ignoreConst(0))}, ...
    1, coder.ignoreConst(0));

tempStrelArray = repmat({images.internal.coder.strel.StrelImpl}, ...
    1, coder.ignoreConst(0));
end
