%

%#codegen
classdef simtform2d < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 2
    end
    
    properties
        Scale
        RotationAngle
        Translation
    end

    properties (Dependent)
        R
    end
    
    methods
        
        function self = simtform2d(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);

            if nargin == 0
                % simtform2d()
                self.Scale = 1;
                self.RotationAngle = 0;
                self.Translation = [0 0];

            elseif (nargin == 1)
                if isa(varargin{1},"simtform2d")
                    % simtform2d(simtform2d_obj)
                    self = varargin{1};
                elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                    % simtform2d(matrix_transformation_obj)
                    self = convertMatrixTransformation(self,varargin{1});
                else
                    % simtform2d(A)
                    self.A = varargin{1};
                end

            elseif (nargin == 3)
                s = varargin{1};
                t = varargin{3};

                % Initialize to provide Coder with a type hint.
                self.RotationAngle = cast(0,'like',varargin{2});

                if isscalar(varargin{2})
                    % simtform2d(s,r,t)
                    r = varargin{2};
                else
                    % simtform2d(s,R,t)
                    R = varargin{2};
                    % The following error check is implemented this way, instead of
                    % using validateattributes, to support codegen and to eliminate
                    % the printing of stack information when reporting an error for
                    % setting an object property.
                    valid_type = isa(R,"double") || isa(R,"single");
                    pass_basic_checks = valid_type && isreal(R) && ...
                        (isequal(size(R),[2 2]));
                    msg_id = "images:geotrans:badRotationMatrixForm2D";
                    if ~pass_basic_checks
                        if coder.target('MATLAB')
                            throwAsCaller(MException(message(msg_id)));
                        else
                            coder.internal.error(msg_id);
                        end
                    end

                    [is_rotation_matrix,~,r] = images.geotrans.internal.checkRotationMatrix2D(R);

                    if ~is_rotation_matrix
                        coder.internal.error("images:geotrans:invalidRotationMatrix");
                    end
                end

                if isnumeric(s) && isscalar(s) && (s < 0)
                    s = -s;
                    r = r + 180;
                end

                self.Scale = s;
                self.RotationAngle = r;
                self.Translation = t;
            else
                coder.internal.assert("images:geotrans:invalidSyntax");
            end
            self.IsBidirectional = true;
        end

        %
        % Provide a more efficient implementation of invert than what is
        % in the images.geotrans.internal.MatrixTransformation base class.
        %
        function out = invert(self)
            coder.inline('always');
            coder.internal.prefer_const(self);

            s = self.Scale;
            r = self.RotationAngle;
            tx = self.Translation(1);
            ty = self.Translation(2);

            s_new = 1/s;
            r_new = -r;

            % New translations derived by multiplying three matrices that:
            %
            %   1. invert the translation
            %   2. invert the rotation
            %   3. invert the scale
            %
            % and then getting the new translations from the (1,3) and
            % (2,3) elements of the matrix product. See derivation attached
            % to MathWorks record g3206897.
            sigma1 = sind(r);
            sigma2 = cosd(r);            
            tx_new = (-tx * sigma2 - ty * sigma1)/s;
            ty_new = (tx * sigma1 - ty * sigma2)/s;

            out = simtform2d(s_new,r_new,[tx_new ty_new]);
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
            pass_basic_checks = valid_type && isreal(new_scale) && isscalar(new_scale);
            msg_id = "images:geotrans:badScale";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end 

            % In releases R2023b and earlier, simtform2d accepted a
            % negative scale factor. To minimize compatibility issues,
            % continue to accept a negative scale factor on input, but
            % convert to a mathematically equivalent transformation that
            % has a positive scale factor. This is done by adding 180
            % degrees to the rotation angle. MathWorks engineers: see
            % g3101363.

            negative_scale = new_scale < 0;
            if negative_scale
                warning(message("images:geotrans:negScalePropertySet"));
                new_scale = -new_scale;
            end

            self.Scale = new_scale;

            if negative_scale
                if coder.target('MATLAB')
                    % The Code Analyzer warns for the following line about
                    % setting a different property value. The hazard of setting
                    % a different property value in a property set method is
                    % that MATLAB does not guarantee the order of property
                    % initialization when load objects from MAT-files, and so
                    % unexpected results could occur. However, the simtform2d
                    % class has an overloaded loadobj method that guarantees a
                    % standard initialization order. The Code Analyzer warning
                    % is therefore suppressed.
                    self.RotationAngle = self.RotationAngle + 180; %#ok<MCSUP>
                else
                    coder.internal.error("images:geotrans:negativeScaleUnsupported2D");
                end
            end

            
        end

        function self = set.RotationAngle(self,new_rotation_angle)
            coder.inline('always');
            coder.internal.prefer_const(self,new_rotation_angle);

            % Initialize property to give Coder a type hint.
            self.RotationAngle = cast(0,'like',new_rotation_angle);

            % The following error check is implemented this way, instead of
            % using validateattributes, to support codegen and to eliminate
            % the printing of stack information when reporting an error for
            % setting an object property.
            valid_type = isa(new_rotation_angle,"double") || ...
                isa(new_rotation_angle,"single");
            pass_basic_checks = valid_type && isreal(new_rotation_angle) && ...
                isscalar(new_rotation_angle);
            msg_id = "images:geotrans:badRotationAngle";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end   

            self.RotationAngle = images.geotrans.internal.canonicalizeDegreeAngle(new_rotation_angle);
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
                isequal(size(new_R),[2 2]);
            msg_id = "images:geotrans:badRotationMatrixForm2D";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end               

            [is_rotation_matrix,~,r] = images.geotrans.internal.checkRotationMatrix2D(new_R);

            if ~is_rotation_matrix
                if coder.internal.target('MATLAB')
                    throwAsCaller(MException(message("images:geotrans:invalidRotationMatrix")))
                else
                    coder.internal.error("images:geotrans:invalidRotationMatrix");
                end
            end

            % Make this operation idempotent in the presence of
            % floating-point round-off error by checking to see whether r
            % is very close to self.RotationAngle. If it is, do not change
            % self.RotationAngle. Set an absolute tolerance based on the
            % angle range, [-180,180), and the class or r.
            tol = 10 * 180 * eps(class(r));
            if (abs(r - self.RotationAngle) > tol)
                self.RotationAngle = r;
            end
        end

        function R = get.R(self)
            coder.inline('always');
            coder.internal.prefer_const(self);

            w = self.RotationAngle;
            x1 = cosd(w);
            x2 = sind(w);
            R = [x1 -x2; x2 x1];
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
                (numel(new_translation) == 2);
            msg_id = "images:geotrans:badTranslation2D";
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
    % Methods constrainA, isValidMatrix, setUnderlyingParameters, and
    % constructA are concrete implementations for abstract methods defined
    % in images.geotrans.internal.MatrixTransformation. See that class for
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
            self.RotationAngle = params.RotationAngle;
            self.Translation = params.Translation;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);  

            r1 = cosd(self.RotationAngle);
            r2 = sind(self.RotationAngle);
            s = self.Scale;
            tx = self.Translation(1);
            ty = self.Translation(2);
            A = [s*r1 -s*r2 tx ; s*r2 s*r1 ty ; 0 0 1];
        end
    end   

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %    
    methods (Hidden)
        function S = saveobj(self)
            S = struct('Scale',self.Scale,...
                'RotationAngle',self.RotationAngle,...
                'Translation',self.Translation,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            if S.Scale < 0
                % In earlier versions of simtform2d, the object could be
                % created with a negative scale factor. This was considered
                % to be bug and was fixed for R2024a. This code handles the
                % situation where a simtform2d object with a negative scale
                % factor was saved to a MAT-file so that a valid and
                % equivalent simtform2d object is returned. MathWorks
                % engineers: see g3101363.

                warning(message("images:geotrans:loadSimilarity2DNegativeScale"))
                S.Scale = -S.Scale;
                S.RotationAngle = S.RotationAngle + 180;
            end
            self = simtform2d(S.Scale,S.RotationAngle,S.Translation);
        end
    end        
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);
    
    % Assuming that A is a valid similarity transformation matrix,
    % find the scale factor first.
    s = hypot(A(1,1),A(1,2));

    % Next, find the rotation angle in degrees.
    theta_degrees = atan2d(-A(1,2)/s,A(1,1)/s);

    % Find the translation.
    tx = A(1,3);
    ty = A(2,3);

    % Given the scale factor, rotation angle, and translation,
    % construct the transformation matrix that is constrained to be
    % a similarity with those parameters.
    r1 = cosd(theta_degrees);
    r2 = sind(theta_degrees);
    Ac = [s*r1 -s*r2 tx ; s*r2 s*r1 ty ; 0 0 1];

    % Return the underlying parameters derived from A.
    params.Scale = s;
    params.RotationAngle = theta_degrees;
    params.Translation = [tx ty];
end

% Copyright 2021-2024 The MathWorks, Inc.