%

%#codegen
classdef affinetform2d < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 2
    end

    properties (Access = private)
        %A23 - Upper 2x3 portion of the 3x3 affine transformation matrix.
        %   A is constructed from A23 as A = [A23 ; 0 0 1]
        A23
    end    
    
    methods
        function self = affinetform2d(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin); 

            if nargin == 0
                self.A = eye(3);
            elseif isa(varargin{1},"affinetform2d")
                self = varargin{1};
            elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                self = convertMatrixTransformation(self,varargin{1});
            else
                self.A = varargin{1};
            end                            

            self.IsBidirectional = true;
        end
    end

    %
    % Methods constrainH, setUnderlyingParameters, and constructH are
    % concrete implementations for abstract methods defined in
    % images.geotrans.internal.MatrixTransformation. See that class for
    % more info.
    %
    methods (Static, Access=protected)
        function [Ac,params] = constrainA(A)
            coder.inline('always');
            coder.internal.prefer_const(A);  

            [Ac,params] = constrainA_alg(A);
        end

        function tf = isValidTransformationMatrix(A)
            coder.inline('always');
            coder.internal.prefer_const(A);  

            Ac = constrainA_alg(A);
            tf = images.geotrans.internal.matricesNearlyEqual(A,Ac) && ...
                ~images.geotrans.internal.isTransformationMatrixSingular(Ac);
        end        
    end

    methods (Access=protected)
        function self = setUnderlyingParameters(self,params)
            coder.inline('always');
            coder.internal.prefer_const(self,params);  

            self.A23 = params.A23;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);   

            A = [self.A23 ; 0 0 1];
        end
    end    

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %
    methods (Hidden)
        function S = saveobj(self)
            S = struct('A23',self.A23,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            self = affinetform2d(S.A23);
        end
    end    
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);
    
    % Force the transformation matrix to be affine by making the
    % final row [0 0 1].
    Ac = A;
    Ac(3,:) = [0 0 1];

    % The only underlying parameter derived from A is A23, the
    % upper two rows of A.
    params.A23 = Ac(1:2,:);
end

% Copyright 2021-2022 The MathWorks, Inc.