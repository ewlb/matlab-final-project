%

%#codegen
classdef rigidtform2d < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 2
    end

    properties
        RotationAngle
        Translation
    end

    properties (Dependent)
        R
    end

    properties (Dependent, Hidden)
        %Rotation - Post-multiply rotation matrix
        %   This property is provided so that code written to work with
        %   rigid2d objects will also work with rigidtform2d objects.
        Rotation
    end

    methods

        function self = rigidtform2d(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);

            narginchk(0,2);

            if nargin == 0
                % rigidtform2d()
                self.RotationAngle = 0;
                self.Translation = [0 0];

            elseif (nargin == 1)
                self = parseOneInputSyntaxes(self,varargin{1});

            elseif (nargin == 2)
                self = parseTwoInputSyntaxes(self,varargin{1},varargin{2});
            end
            self.IsBidirectional = true;
        end

        %
        % Provide a more efficient implementation of isRigid than what is
        % in the images.geotrans.internal.MatrixTransformation base class.
        %
        function tf = isRigid(~)
            coder.inline('always');

            tf = true;
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
        function self = set.RotationAngle(self,new_rotation_angle)
            coder.inline('always');
            coder.internal.prefer_const(self,new_rotation_angle);

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
                (isequal(size(new_R),[2 2]));
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
                if coder.target('MATLAB')
                    throwAsCaller(MException(message("images:geotrans:invalidRotationMatrix")));
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
            validateattributes(val,{'double', 'single'},{'real', 'size', [2 2]}, ...
                '','Rotation');          

            obj.R = val.';
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

            self.Translation = new_translation(:).';
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

            self.RotationAngle = params.RotationAngle;
            self.Translation = params.Translation;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);

            r1 = cosd(self.RotationAngle);
            r2 = sind(self.RotationAngle);
            tx = self.Translation(1);
            ty = self.Translation(2);
            A = [r1 -r2 tx ; r2 r1 ty ; 0 0 1];
        end
    end

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %      
    methods (Hidden)
        function S = saveobj(self)
            S = struct('RotationAngle',self.RotationAngle,...
                'Translation',self.Translation,...
                'MATFormatVersion',1);
        end
    end

    methods (Static, Hidden)
        function self = loadobj(S)
            self = rigidtform2d(S.RotationAngle,S.Translation);
        end
    end    
end

function out = parseOneInputSyntaxes(self,arg1)
    coder.inline('always');
    coder.internal.prefer_const(self,arg1);

    if isa(arg1,"rigidtform2d")
        % rigidtform2d(rigidtform2d_obj)
        out = arg1;

    elseif isa(arg1,"images.geotrans.internal.MatrixTransformation")
        % rigidtform2d(matrix_transformation_obj)
        out = convertMatrixTransformation(self,arg1);

    elseif isvector(arg1) && (numel(arg1) == 2)
        % rigidtform2d(t)
        t = arg1(:).';   % Force to be a row
        r = 0;

        out = self;
        out.RotationAngle = r;
        out.Translation = t;

    elseif isequal(size(arg1),[3 3]) || isequal(size(arg1),[2 3])
        % rigidtform2d(A)
        out = self;
        out.A = arg1;

    else
        coder.internal.error("images:geotrans:invalidSyntax");
    end
end

function self = parseTwoInputSyntaxes(self,arg1,arg2)
    coder.inline('always');
    coder.internal.prefer_const(self,arg1,arg2);

    if isscalar(arg1) && isTwoElementVector(arg2)
        % rigidtform2d(r,t)
        self.RotationAngle = arg1;
        self.Translation = arg2;

    elseif isequal(size(arg1),[2 2]) && isTwoElementVector(arg2)
        % rigidtform(R,t)
        R = arg1;
        t = arg2;

        % Force input to be a rotation matrix and get the corresponding angle.
        [is_rotation_matrix,~,r] = images.geotrans.internal.checkRotationMatrix2D(R);
        % If not "close" to the input, it is an error.
        if ~is_rotation_matrix
            coder.internal.error("images:geotrans:invalidRotationMatrix");
        end

        self.RotationAngle = r;
        self.Translation = t;

    else
        coder.internal.error("images:geotrans:invalidSyntax");
    end
end

function tf = isTwoElementVector(in)
    coder.inline('always');
    coder.internal.prefer_const(in);

    tf = isvector(in) && (numel(in) == 2);
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);
    
    Ac = A;

    % Constrain the upper 2x2 submatrix to be a true rotation
    % matrix and determine the corresponding rotation angle.
    [Ac(1:2,1:2),r] = ...
        images.geotrans.internal.constrainToRotationMatrix2D(Ac(1:2,1:2));

    % Force the last row to be [0 0 1].
    Ac(3,:) = cast([0 0 1],class(Ac));

    % Return the underlying parameters derived from A.
    params.RotationAngle = r;
    params.Translation = Ac(1:2,3).';
end

% Copyright 2021-2022 The MathWorks, Inc.