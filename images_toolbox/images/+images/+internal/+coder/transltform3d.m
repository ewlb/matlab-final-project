%   This transltform3d class contains code generation implementation of
%   transltform3d

%   This class is for internal use only.

% Copyright 2022 The MathWorks, Inc.

%#codegen

classdef transltform3d < images.geotrans.internal.transltform3dImpl & ...
        images.internal.coder.OneDimArrayBehaviorTransform
    
    properties (Access = protected) % For array of affinetform3d codegen
        Data
    end
    
    properties (Constant, Hidden)
        ClassName = 'transltform3d';
    end
    
    %----------------------------------------------------------------------
    % Object Creation - static creation method and private constructor
    %----------------------------------------------------------------------
    methods (Hidden, Static)
        
        %------------------------------------------------------------------
        % Creating an empty affine3d object
        %------------------------------------------------------------------
        function e = makeEmpty(this)
            %makeEmpty Make an empty object
            
            % The empty() method cannot be overridden in code generation.
            % To overcome this, we use the make-empty method as an interface
            % to create empty objects.
            dataType = class(this.A);
            A     = eye(4, 4, dataType);
            % Create a dummy object
            dps = transltform3d(A);
            
            % Use repmat to make an empty object
            e = repmat(dps, 0, 0);
        end
    end
    
    methods
        %------------------------------------------------------------------
        %     Constructor
        %------------------------------------------------------------------
        function this = transltform3d(varargin)
            this = this@images.geotrans.internal.transltform3dImpl(varargin{:});
            data = {images.geotrans.internal.transltform3dImpl(varargin{:})};
            coder.varsize('dataArray');
            dataArray = data;
            this.Data = dataArray;
        end
    end
    
end
