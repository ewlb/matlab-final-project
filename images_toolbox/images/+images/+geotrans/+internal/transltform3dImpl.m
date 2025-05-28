%

%#codegen
classdef transltform3dImpl < images.geotrans.internal.MatrixTransformation

    properties (Constant)
        Dimensionality = 3
    end
    
    properties
        Translation
    end
 
    methods
        function self = transltform3dImpl(varargin)
            coder.inline('always');
            coder.internal.prefer_const(varargin);
                        
            if (nargin == 0)
                % transltform3d()
                self.Translation = [0 0 0];

            elseif (nargin == 1)
                if isa(varargin{1},"transltform3d")
                    % transltform3d(transltform3d_obj)
                    self = varargin{1};

                elseif isa(varargin{1},"images.geotrans.internal.MatrixTransformation")
                    % transltform3d(matrix_transformation_obj)
                    self = convertMatrixTransformation(self,varargin{1});

                elseif isvector(varargin{1}) && (numel(varargin{1}) == 3)
                    % transltform3d(t)
                    self.Translation = varargin{1};

                else
                    % transltform3d(A)
                    self.A = varargin{1};
                end

            elseif (nargin == 3)
                % transtorm3d(dx,dy,dz)
                self.Translation = [varargin{1} varargin{2} varargin{3}];

            else
                error(message("images:geotrans:invalidSyntax"))
            end
        end  

        %
        % Provide more efficient implementations of the is-functions that
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
            pass_basic_checks = valid_type && isreal(translation) && (numel(translation) == 3);
            msg_id = "images:geotrans:badTranslation3D";
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
                        
            self.Translation = params.Translation;
        end

        function A = constructA(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            A = [eye(3) self.Translation.' ; 0 0 0 1];
        end
    end    
end

function [Ac,params] = constrainA_alg(A)
    coder.inline('always');
    coder.internal.prefer_const(A);

    % Find translation
    t = A(1:3,4).';

    % Construct constrained matrix based on translation.
    Ac = [eye(3) t.' ; 0 0 0 1];

    % Return the underlying parameters derived from A.
    params.Translation = t;
end

% Copyright 2021-2022 The MathWorks, Inc.