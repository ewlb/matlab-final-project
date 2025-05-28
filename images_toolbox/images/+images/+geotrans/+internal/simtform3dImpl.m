%

%#codegen
classdef simtform3dImpl < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 3
    end
    
    properties
        Scale
        Translation
        R
    end
    
    methods
        
        function self = simtform3dImpl(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);
                        
            narginchk(0,3);

            if nargin == 0
                % simtform3d()
                self.Scale = 1;
                self.R = eye(3);
                self.Translation = [0 0 0];

            elseif (nargin == 1)
                if isa(varargin{1},"simtform3d")
                    % simtform3d(simtform3d_obj)
                    self = varargin{1};
                elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                    % simtform3d(matrix_transformation_obj)
                    self = convertMatrixTransformation(self,varargin{1});
                else
                    % simtform3d(A)
                    self.A = varargin{1};
                end

            elseif (nargin == 3)
                s = varargin{1};
                t = varargin{3};

                if isequal(size(varargin{2}),[3 3])
                    % simtform3d(s,R,t)
                    R = varargin{2};
                elseif isequal(size(varargin{2}),[1 3])
                    % simtform(s,r,t)
                    r = varargin{2};
                    R = images.geotrans.internal.anglesToRotationMatrix3D(r);
                else
                    coder.internal.error("images:geotrans:invalid3DRotationInput");
                end

                self.Scale = s;
                self.R = R;
                self.Translation = t;

            else
                coder.internal.error("images:geotrans:invalidSyntax");
            end
        end

        %
        % Provide a more efficient implementation of isSimilarity than what
        % is in the images.geotrans.internal.MatrixTransformation base
        % class.
        %        
        function tf = isSimilarity(~)
            coder.inline('always');

            tf = true;
        end
    end
    
    %
    % Property set/get methods
    %    
    methods
        function self = set.Scale(self,new_scale)
            coder.inline('always');
            coder.internal.prefer_const(self,new_scale);         
                        
            % The following error check is implemented this way, instead of
            % using validateattributes, to support codegen and to eliminate
            % the printing of stack information when reporting an error for
            % setting an object property.
            valid_type = isa(new_scale,"double") || isa(new_scale,"single");
            pass_basic_checks = valid_type && isreal(new_scale) && ...
                isscalar(new_scale) && (new_scale >= 0);
            msg_id = "images:geotrans:badScale";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end  

            self.Scale = new_scale;
        end        

        function self = set.R(self,new_R)
            coder.inline('always');
            coder.internal.prefer_const(self,new_R);

            % The following error check is implemented this way, instead of
            % using validateattributes, to support codegen and to eliminate
            % the printing of stack information when reporting an error for
            % setting an object property.
            valid_type = isa(new_R,"double") || isa(new_R,"single");
            pass_basic_checks = valid_type && isreal(new_R) && ...
                isequal(size(new_R),[3 3]);
            msg_id = "images:geotrans:badRotationMatrixForm3D";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end

            % Check that the input is a 3-D rotation matrix and extract the
            % angles from it.
            [is_rotation_matrix,Rc] = images.geotrans.internal.checkRotationMatrix3D(new_R);

            % If not "close" to the input, it is an error.
            if ~is_rotation_matrix
                coder.internal.error("images:geotrans:invalidRotationMatrix");
            end

            self.R = Rc;
        end

        function self = set.Translation(self,new_translation)
            coder.inline('always');
            coder.internal.prefer_const(self,new_translation);
                        
            % The following error check is implemented this way, instead of
            % using validateattributes, to support codegen and to eliminate
            % the printing of stack information when reporting an error for
            % setting an object property.
            valid_type = isa(new_translation,"double") || isa(new_translation,"single");
            pass_basic_checks = valid_type && isreal(new_translation) && ...
                (numel(new_translation) == 3);
            msg_id = "images:geotrans:badTranslation3D";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end   

            self.Translation = new_translation;
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
                        
            self.Scale = params.Scale;
            self.R = params.R;
            self.Translation = params.Translation;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            A = constructAFromParams(self.Scale,self.R,self.Translation);
        end
    end    
end

function A = constructAFromParams(s,R,t)
    coder.inline('always');
    coder.internal.prefer_const(s,R,t);

    A = [s*R t.'];
    A = [A ; 0 0 0 1];
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);

    % Assuming that A is a valid similarity transformation matrix,
    % find the scale factor first.
    s = sqrt(sum(A(1,1:3).^2));

    % Next, find the rotation matrix.
    R = A(1:3,1:3) / s;

    % Constrain R to be a true rotation matrix.
    Rc = images.geotrans.internal.constrainToRotationMatrix3D(R);

    % Find the translation.
    t = A(1:3,4).';

    % Construct the constrained transformation matrix from the
    % detected parameters.
    Ac = constructAFromParams(s,Rc,t);

    % Return the underlying parameters derived from A.
    params.Scale = s;
    params.R = Rc;
    params.Translation = t;
end

% Copyright 2021-2023 The MathWorks, Inc.
