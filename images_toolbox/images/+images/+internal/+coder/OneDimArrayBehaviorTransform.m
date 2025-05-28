%   This class is used to implement code generation support for the
%   rigid3d and affine3d objects. In order to support array of object
%   syntaxes, this class holds a property Data containing a cell array
%   of objects data. Each individual object data points to rigid3d and
%   affine3d object data.
%
%   Note that ONLY 1-D indexing is supported.

% Copyright 2021 The MathWorks, Inc.

%#codegen

classdef OneDimArrayBehaviorTransform < matlab.mixin.internal.indexing.ParenAssign & ...
        matlab.mixin.internal.indexing.Paren
    
    properties (Access = protected, Abstract)
        %   Cell array of objects
        Data
    end
    
    properties (Constant, Hidden, Abstract)
        ClassName
    end
    
    methods
        %------------------------------------------------------------------
        % paren reference function for array of transform objects
        %------------------------------------------------------------------
        function this1 = parenReference(this, idx, varargin)
            coder.internal.errorIf(numel(varargin)>0,...
                'images:geotrans:oneDimIndexing');
            if isa(this, 'rigid3d')
                this1 = images.internal.coder.rigid3d.makeEmpty(this);
            elseif isa(this, 'affine3d')
                this1 = images.internal.coder.affine3d.makeEmpty(this);
            elseif isa(this, 'affinetform3d')
                this1 = images.internal.coder.affinetform3d.makeEmpty(this);
            elseif isa(this, 'rigidtform3d')
                this1 = images.internal.coder.rigidtform3d.makeEmpty(this);
            elseif isa(this, 'simtform3d')
                this1 = images.internal.coder.simtform3d.makeEmpty(this);
            elseif isa(this, 'transltform3d')
                this1 = images.internal.coder.transltform3d.makeEmpty(this);
            end
            
            coder.internal.errorIf(ischar(idx) && ~strcmpi(idx,':'), ...
                'images:geotrans:oneDimIndexing');

            if ischar(idx) && strcmpi(idx, ':')
                return;
            end
            
            % Maintain sizing
            if isrow(this)
                dataArray = coder.nullcopy( cell(1, numel(idx)) );
            else
                dataArray = coder.nullcopy( cell(numel(idx), 1) );
            end
            
            for n = 1 : numel(idx)
                dataArray{n} = this.Data{idx(n)};
            end
            
            this1.Data        = dataArray;
            if isa(this, 'rigid3d')
                this1.T           = dataArray{1}.T;
                this1.Rotation    = dataArray{1}.Rotation;
                this1.Translation = dataArray{1}.Translation;
            else
                this1.T = dataArray{1}.T;
            end
        end
        
        %------------------------------------------------------------------
        % paren assign function for array of transform objects
        %------------------------------------------------------------------
        function this = parenAssign(this, rhs, idx, varargin)
            
            coder.internal.errorIf(numel(varargin)>0, ...
                'images:geotrans:oneDimIndexing');
            checkTransformsSimilrity(this, rhs);            
            
            if ischar(idx) && strcmp(idx, ':')
                idx = 1 : numel(this);
            elseif ischar(idx)
                coder.internal.error('images:geotrans:oneDimIndexing');
            end
            
            farthestElement = max(idx);
            
            if farthestElement > numel(this)
                % Copy over current elements
                if isrow(this)
                    dataArray = coder.nullcopy( cell(1, farthestElement) );
                else
                    dataArray = coder.nullcopy( cell(farthestElement, 1) );
                end
                for n = 1 : numel(this)
                    dataArray{n} = this.Data{n};
                end
                
                % Replace/add new elements
                for n = 1 : numel(idx)
                    dataArray{idx(n)} = rhs.Data{n};
                end
                this.Data = dataArray;
            else
                % No need to grow cell array, just replace data
                for n = 1 : numel(idx)
                    this.Data{idx(n)} = rhs.Data{n};
                end
            end
        end
        
        %------------------------------------------------------------------
        % overloading the vertcat functionality
        %------------------------------------------------------------------
        function this = vertcat(this, varargin)
            
            coder.internal.errorIf(...
                isrow(this), 'MATLAB:catenate:matrixDimensionMismatch');
            
            num = numel(varargin);
            for n = 1 : num
                checkTransformsSimilrity(this, varargin{n});
            end       
            
            data = initializeArrayData(this);
            dataArray  = repmat({data}, coder.ignoreConst(0), 1);
            
            this = copyConcatData(this, dataArray, num, varargin{:});
        end
        
        %------------------------------------------------------------------
        % calculate the number of transform objects in transform array
        %------------------------------------------------------------------
        function n = numel(this)
            n = numel(this.Data);
        end
        
        %------------------------------------------------------------------
        % overloading the isscalar functionality
        %------------------------------------------------------------------
        function tf = isscalar(this)
            tf = numel(this.Data)==1;
        end
        
        %------------------------------------------------------------------
        % overloading the repmat functionality
        %------------------------------------------------------------------
        function this = repmat(this, varargin)
            coder.internal.assert( numel(varargin)<3, ...
                'images:geotrans:oneDimIndexing');
            
            % validate repmat(obj,[a, b, ...]) syntax
            if numel(varargin)==1 && ~isscalar(varargin{1})
                in = varargin{1};
                
                % Only indexing up to two dimensions
                coder.internal.assert( numel(in)<=2 && ...
                    (in(1)<=1 || in(2)<=1), ...
                    'images:geotrans:oneDimIndexing');
            end
            
            two_scalar_arguments = (numel(varargin)==2 && isscalar(varargin{1}) && isscalar(varargin{2}));
            coder.internal.assert(~two_scalar_arguments || ...
                (varargin{1} <=1 && varargin{2}<=1),...
                'images:geotrans:oneDimIndexing');

            this.Data = repmat(this.Data, varargin{:});
        end
        
        %------------------------------------------------------------------
        % overloading the horzcat functionality
        %------------------------------------------------------------------
        function this = horzcat(this, varargin)
            
            coder.internal.assert(...
                isrow(this), 'MATLAB:catenate:matrixDimensionMismatch');
            num = numel(varargin);
            for n = 1 : num
                 checkTransformsSimilrity(this, varargin{n});
            end            
           
            data = initializeArrayData(this);
            dataArray  = repmat({data}, 1, coder.ignoreConst(0));
            
            this = copyConcatData(this, dataArray, num, varargin{:});
        end
        %------------------------------------------------------------------
        % overloading the transpose functionality
        %------------------------------------------------------------------
        function this = transpose(this)
            
            % Transpose is not supported for cell arrays in code
            % generation. Use reshape instead for transpose because these
            % are 1-D arrays.
            if isrow(this)
                this.Data = reshape(this.Data, numel(this), 1);
            else
                this.Data = reshape(this.Data, 1, numel(this));
            end
        end
        
        %------------------------------------------------------------------
        % overloading the ctranspose functionality
        %------------------------------------------------------------------
        function this = ctranspose(this)
            
            this = transpose(this);
        end
        
        %------------------------------------------------------------------
        % overloading the reshape functionality
        %------------------------------------------------------------------
        function this = reshape(this, varargin)
            
            coder.internal.assert( numel(varargin)<3, ...
                'images:geotrans:oneDimIndexing');
            
            two_arguments = (numel(varargin) == 2);
            coder.internal.assert(~two_arguments || ...
                ~(isempty(varargin{1}) || isempty(varargin{2})), ...
                'images:geotrans:reshapeWithEmpties');
            
            this.Data = reshape(this.Data, varargin{:});
        end
        
        %------------------------------------------------------------------
        % overloading the isempty functionality
        %------------------------------------------------------------------
        function ie = isempty(this)
            
            ie = numel(this)== 0;
        end
        
        %------------------------------------------------------------------
        % overloading the end functionality
        %------------------------------------------------------------------
        function n = end(this,varargin)
            % Only 1-D indexing is supported, so end is always numel.
            n = numel(this);
        end
        
        %------------------------------------------------------------------
        % overloading the length functionality
        %------------------------------------------------------------------
        function l = length(this)
            % For a 1-D array, length is numel
            l = numel(this);
        end
        
        %------------------------------------------------------------------
        % overloading the isrow functionality
        %------------------------------------------------------------------
        function y = isrow(this)
            y = isrow(this.Data);
        end
        
        %------------------------------------------------------------------
        % copy the concatenate data into object
        %------------------------------------------------------------------
        function this = copyConcatData(this, dataArray, num, varargin)
            % copy over current elements
            for n=1:numel(this)
                dataArray{end+1} = this.Data{n};
            end
            
            % copy over new elements
            for n=1:num
                for nn = 1:numel(varargin{n})
                    dataArray{end+1} = varargin{n}.Data{nn};
                end
            end
            
            % Assign dataArray to corresponding data property
            this.Data = dataArray;
        end

        %------------------------------------------------------------------
        % check the transform similarities
        %------------------------------------------------------------------
        function checkTransformsSimilrity(this, that)

            coder.internal.errorIf(~isa(that, class(this)), 'images:geotrans:cannotConvert',...
                class(this), class(that));
            coder.internal.errorIf(isa(this, 'rigid3d') && ~isa(this.Rotation, class(that.Rotation)),...
                'images:geotrans:differentTypes');
            coder.internal.errorIf(isa(this, 'rigid3d') && ~isa(this.Translation, class(that.Translation)),...
                'images:geotrans:differentTypes');
            coder.internal.errorIf(~isa(this.T, class(that.T)),...
                'images:geotrans:differentTypes');
        end
        
        %------------------------------------------------------------------
        % initialize the array objects for rigid3d and affine3d object
        %------------------------------------------------------------------
        function data = initializeArrayData(this)
            % initialize rigid3d/affine3d array data
            if isa(this, 'rigid3d')
                data = images.internal.rigid3dImpl(this.T);
            elseif isa(this, 'affine3d')
                data = images.internal.affine3dImpl(this.T);
            elseif isa(this, 'affinetform3d')
                data = images.geotrans.internal.affinetform3dImpl(this.A);
            elseif isa(this, 'rigidtform3d')
                data = images.geotrans.internal.rigidtform3dImpl(this.A);
            elseif isa(this, 'simtform3d')
                data = images.geotrans.internal.simtform3dImpl(this.A);
            elseif isa(this, 'transltform3d')
                data = images.geotrans.internal.transltform3dImpl(this.A);
            end
        end
    end
end
