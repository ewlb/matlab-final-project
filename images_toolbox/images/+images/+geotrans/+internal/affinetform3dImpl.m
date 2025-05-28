%

%#codegen
classdef affinetform3dImpl < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 3
    end

    properties (Access = protected)
        %A34 - Upper 3x4 portion of the 4x4 affine transformation matrix.
        %   A is constructed from A34 as A = [A34 ; 0 0 0 1]
        A34
    end    
    
    methods
        function self = affinetform3dImpl(varargin) 
            coder.inline('always');
            coder.internal.prefer_const(varargin);

            if nargin == 0
                self.A = eye(4);
            elseif isa(varargin{1},"affinetform3d")
                self = varargin{1};
            elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                self = convertMatrixTransformation(self,varargin{1});
            else
                self.A = varargin{1};
            end                            
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
                        
            self.A34 = params.A3;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            A = [self.A34 ; 0 0 0 1];
        end
    end 
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);

    % Force the transformation matrix to be affine by making the
    % final row [0 0 0 1].
    Ac = A;
    Ac(4,:) = [0 0 0 1];

    % The only underlying parameter derived from A is A34, the
    % upper three rows of A.
    params.A3 = Ac(1:3,:);
end
% Copyright 2021-2022 The MathWorks, Inc.
