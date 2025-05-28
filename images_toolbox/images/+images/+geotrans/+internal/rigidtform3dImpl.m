%

%#codegen
classdef rigidtform3dImpl < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 3
    end
    
    properties
        Translation = [0 0 0]
        R = eye(3)
    end
    
    properties (Dependent, Hidden)
        %Rotation - Post-multiply rotation matrix
        %   This property is provided so that code written to work with
        %   rigid2d objects will also work with rigidtform2d objects.        
        Rotation
    end
 
    methods
        
        function self = rigidtform3dImpl(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);

            narginchk(0,2);

            if (nargin == 0)
                % rigidtform3d()
                self.R = eye(3);
                self.Translation = [0 0 0];

            elseif (nargin == 1)
                if isa(varargin{1},"rigidtform3d")
                    % rigidtform3d(rigidtform3d_obj)
                    self = varargin{1};

                elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                    % rigidtform3d(matrix_transformation_obj)
                    self = convertMatrixTransformation(self,varargin{1});

                else
                    % rigidtform3d(A)
                    A = varargin{1};
                    self.A = A;
                end

            elseif (nargin == 2)
                if isequal(size(varargin{1}),[3 3])
                    % rigidtform3d(R,t)
                    R = varargin{1};
                elseif isequal(size(varargin{1}),[1 3])
                    % rigidtform3d(r,t)
                    r = varargin{1};
                    R = images.geotrans.internal.anglesToRotationMatrix3D(r);
                else
                    coder.internal.error("images:geotrans:invalid3DRotationInput");
                end
                self.R = R;
                self.Translation = varargin{2};
            end
        end


                                                           
    end

   
    
    %
    % Property set/get methods
    %    
    methods
        function value = get.Rotation(obj)
            coder.inline('always');
            coder.internal.prefer_const(obj);
                        
            value = obj.R.';
        end

        function obj = set.Rotation(obj,val)
            coder.inline('always');
            coder.internal.prefer_const(obj,val);
                        
            % Don't bother with extra logic here to trim the error stack in
            % a codegen friendly way because this property is undocumented.
            validateattributes(val,{'double', 'single'},{'real', 'size', [3 3]}, ...
                '','Rotation');

            obj.R = val.';
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
                (isequal(size(new_R),[3 3]));
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

            if ~is_rotation_matrix
                if coder.target('MATLAB')
                    throwAsCaller(MException(message("images:geotrans:invalidRotationMatrix")));
                else
                    coder.internal.error("images:geotrans:invalidRotationMatrix");
                end
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

            self.Translation = new_translation(:).';
        end
        
    end

    %
    % Methods constrainA, setUnderlyingParameters, and constructA are
    % concrete implementations for abstract methods defined in
    % images.geotrans.internal.MatrixTransformation. See that class for more info.
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
                        
            self.R = params.R;
            self.Translation = params.Translation;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            A = [self.R self.Translation.' ; 0 0 0 1];
        end
    end          
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);
                
    % Constrain the upper-left 3x3 submatrix to be a rotation
    % matrix.
    R = images.geotrans.internal.constrainToRotationMatrix3D(A(1:3,1:3));

    % Find the translation.
    t = A(1:3,4).';

    % Constrain A according to the detected parameters.
    Ac = [R t.' ; 0 0 0 1];

    % Return the underlying parameters derived from A.
    params.R = R;
    params.Translation = t;
end

% Copyright 2021-2022 The MathWorks, Inc.