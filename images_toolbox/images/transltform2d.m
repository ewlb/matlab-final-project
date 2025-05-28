%

%#codegen
classdef transltform2d < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 2
    end
    
    properties
        Translation
    end
    
    methods
        function self = transltform2d(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);

            if nargin == 0
                % transltform2d()
                self.Translation = [0 0];

            elseif nargin == 1
                if isa(varargin{1},"transltform2d")
                    % transltform2d(transltform2d_obj)
                    self = varargin{1};

                elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                    % transltform2d(matrix_transformation_obj)
                    self = convertMatrixTransformation(self,varargin{1});

                elseif (numel(varargin{1}) == 2)
                    % transltform2d(t)
                    t = varargin{1};
                    self.Translation = t;

                elseif ismatrix(varargin{1})
                    self.A = varargin{1};

                else
                    error(message("images:geotrans:invalidSyntax"))
                end

            elseif nargin == 2
                % transltform2d(dx,dy)
                validateattributes(varargin{1},{'double' 'single'},{'scalar' 'real'});
                validateattributes(varargin{2},{'double' 'single'},{'scalar' 'real'});
                self.Translation = [varargin{1} varargin{2}];
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

            out = transltform2d(-self.Translation);
        end

        %
        % Provide more efficient implementations of the is-functions than
        % what is provided in the
        % images.geotrans.internal.MatrixTransformation base class.
        %
        function tf = isTranslation(~)
            coder.inline('always');

            tf = true;
        end

        function tf = isRigid(~)
            coder.inline('always');

            tf = true;
        end

        function tf = isSimilarity(~)
            coder.inline('always');

            tf = true;
        end                            
    end 

    %
    % Property set/get methods
    %
    methods
        function self = set.Translation(self,translation)
            coder.inline('always');
            coder.internal.prefer_const(self,translation);

            % The following error check is implemented this way, instead of
            % using validateattributes, to support codegen and to eliminate
            % the printing of stack information when reporting an error for
            % setting an object property.
            valid_type = isa(translation,"double") || isa(translation,"single");
            pass_basic_checks = valid_type && isreal(translation) && (numel(translation) == 2);
            msg_id = "images:geotrans:badTranslation2D";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end

            % Force translation to be a row vector.
            translation = translation(:).';

            self.Translation = translation;
        end
    end


    %
    % Provide more efficient implementations of the point transformation
    % functions than what is provided in the
    % images.geotrans.internal.MatrixTransformation base class.
    methods (Access = protected)
        function X = transformPackedPointsForward(self,U)
            coder.inline('always');
            coder.internal.prefer_const(self,U);

            X = U + self.Translation;
        end

        function U = transformPackedPointsInverse(self,X)
            coder.inline('always');
            coder.internal.prefer_const(self,X);
            
            U = X - self.Translation;
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
        function obj_out = setUnderlyingParameters(obj_in,params)
            coder.inline('always');
            coder.internal.prefer_const(obj_in,params);

            obj_out = obj_in;
            obj_out.Translation = params.Translation;
        end

        function A = constructA(obj)
            coder.inline('always');
            coder.internal.prefer_const(obj);

            % Constructing A using concatenation this way ensures that A is
            % single if obj.Translation is single.
            A = [eye(2) obj.Translation.' ; 0 0 1];
        end
    end

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %       
    methods (Hidden)
        function S = saveobj(self)
            S = struct('Translation',self.Translation,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            self = transltform2d(S.Translation);
        end
    end       
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);

    % Constrain the upper-left 2x2 submatrix to be the identity
    % matrix.
    Ac = A;
    Ac(1:2,1:2) = [1 0; 0 1];

    % Force the last row to be [0 0 1].
    Ac(3,:) = [0 0 1];

    % Return the underlying parameters derived from A.
    params.Translation = Ac(1:2,3).';
end

% Copyright 2021-2022 The MathWorks, Inc.