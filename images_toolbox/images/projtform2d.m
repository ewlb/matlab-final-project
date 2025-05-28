%

%#codegen
classdef projtform2d < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 2
    end

    properties (Access = private)
        %A_ - Underlying storage for the dependent property A.
        %   A is the same as A_.
        A_
    end
        
    methods
        function self = projtform2d(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);  

            if nargin == 0
                A = eye(3);
                self.A = A;
            elseif isa(varargin{1},"projtform2d")
                self = varargin{1};
            elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                self = convertMatrixTransformation(self,varargin{1});
            else
                A = varargin{1};
                self.A = A; 
            end
            self.IsBidirectional = true;
        end
    end   

    %
    % Methods constrainA, setUnderlyingParameters, and constructA are
    % concrete implementations for abstract methods defined in
    % images.geotrans.internal.MatrixTransformation. See that class for
    % more info.
    %
    methods (Static, Access=protected)
        function [Ac,params] = constrainA(A)
            coder.inline('always');
            coder.internal.prefer_const(A);

            % There are no constraints on A.
            Ac = A;

            % For projective transformations, there are no underlying
            % parameters that are distinct from A. The private property A_
            % is the internal storage for the dependent property A.            
            params.A_ = Ac;
        end

        function tf = isValidTransformationMatrix(A)
            coder.inline('always');
            coder.internal.prefer_const(A);

            % There are no constraints on A for a projective
            % transformation.
            tf = true;
        end
    end

 
    methods (Access=protected)
        function self = setUnderlyingParameters(self,params)
            coder.inline('always');
            coder.internal.prefer_const(self,params);

            self.A_ = params.A_;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
            
            A = self.A_;
        end
    end   

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %       
    methods (Hidden)
        function S = saveobj(self)
            S = struct('A_',self.A_,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            self = projtform2d(S.A_);
        end
    end            
end

% Copyright 2021-2022 The MathWorks, Inc.
