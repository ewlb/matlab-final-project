%   This affine3d class contains code generation implementation of affine3d

%   This class is for internal use only.

% Copyright 2021 The MathWorks, Inc.

%#codegen

classdef affine3d < images.internal.affine3dImpl & ...
        images.internal.coder.OneDimArrayBehaviorTransform
    
    properties (Access = protected) % For array of affine3d codegen
        Data
    end
    
    properties (Constant, Hidden)
        ClassName = 'affine3d';
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
            dataType = class(this.T);
            tmat     = eye(4, 4, dataType);
            % Create a dummy object
            dps = affine3d(tmat);
            
            % Use repmat to make an empty object
            e = repmat(dps, 0, 0);
        end
    end
    
    methods
        %------------------------------------------------------------------
        %     Constructor
        %------------------------------------------------------------------
        function this = affine3d(varargin)
            this = this@images.internal.affine3dImpl(varargin{:});
            data = {images.internal.affine3dImpl(varargin{:})};
            coder.varsize('dataArray');
            dataArray = data;
            this.Data = dataArray;
        end
    end
    
end
