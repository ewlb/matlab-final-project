%

%#codegen
classdef MatrixTransformation < images.geotrans.internal.GeometricTransformation & images.internal.CustomDisplay
    
    properties (Dependent)
        A
    end

    properties (Dependent, Hidden)
        %T - Post-multiply transformation matrix. Provided so that code written
        %   for the old geometric transformation classes will work with the
        %   new ones.
        T
    end

    properties (Hidden)
        IsBidirectional = true
    end
    

    methods (Abstract, Static, Access=protected)
        % Concrete classes must provide a static constrainA method. This
        % method takes a transformation matrix, A, and returns a possibly
        % modified matrix that has been constrained to be exactly valid for
        % that concrete class. For example, the affinetform2d class would
        % force the last row to be [0 0 1].
        %
        % This method also returns the underlying class-defining parameters
        % (in the form of struct fields) that are derived from A. For
        % example, the rigidtform2d implementation returns a struct with
        % the fields RotationAngle and Translation.
        [Ac,params] = constrainA(A)

        % Concrete classes must provide a static
        % isValidTransformationMatrix method. This method takes a
        % transformation matrix and returns true or false, indicating
        % whether the input is a valid transformation matrix for that
        % class. If this method returns true, then calling the constructor
        % with the same matrix should not error.
        %
        % The concrete method does not have to check the size or the type
        % of A, only that the matrix elements are consistent with the
        % requirements of that concrete class.
        tf = isValidTransformationMatrix(A)
    end

    methods (Abstract, Access=protected)
        % Concrete classes must provide a setUnderlyingParameters method.
        % This method uses the struct fields in the second output of
        % constrainH to set object properties that are derived from the
        % transformation matrix, A.
        obj_out = setUnderlyingParameters(obj_in,params)

        % Concrete classes must provide a constructA method that returns A.
        % This method is invoked by the property get method, get.A, defined
        % in this base class.
        A = constructA(obj)
    end

    methods (Access=protected)
        % This method is used in class constructors to implement syntaxes
        % such as rigidtform2d(matrix_transformation_obj). The real work
        % (validation of A and the setting of underlying parameters derived
        % from A) is done in the set.A method.
        function self = convertMatrixTransformation(self,in)
            coder.inline('always');
            coder.internal.prefer_const(self,in);
                        
            if ~self.isValidTransformationMatrix(in.A)
                msg_args = {'images:geotrans:invalidInputForConversion',class(self)};
                if coder.target('MATLAB')
                    % Use throwAsCaller to eliminate the internal base
                    % class methods from the stack track when printing
                    % error messages about invalid inputs.
                    throwAsCaller(MException(message(msg_args{:})));
                else
                    coder.internal.error(msg_args{:});
                end
            else
                self.A = in.A;
            end
        end
    end

    % getPropertyGroups, which is invoked by matlab.mixin.CustomDisplay, is
    % redefined here for the purpose of stripping out A from the property
    % list. The matrix A will instead by displayed at the bottom, with its
    % element values by the override of getFooter.
    %
    % Note: images.internal.CustomDisplay is a codegen-friendly wrapper
    % around matlab.mixin.CustomDisplay.
    methods (Access = protected)
        function group = getPropertyGroups(this)
            if isscalar(this)
                % Strip A from the list. It will be shown by getFooter.
                p = string(properties(this));
                p(p == "A") = [];
                group = matlab.mixin.util.PropertyGroup(p);
            else
                group = getPropertyGroups@matlab.mixin.CustomDisplay(this);
            end
        end

        function footer_text = getFooter(this_tform)
            if ~isscalar(this_tform)
                % If this is a nonscalar object array, then get the default
                % and return.
                footer_text = getFooter@matlab.mixin.CustomDisplay(this_tform);
                return
            end

            % Use formattedDisplayText to get the text representation of
            % the matrix values, using the shortG format. Split the result
            % into separate lines. 
            s = split(formattedDisplayText(this_tform.A,NumericFormat = "short"),newline);

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "      0.70711     -0.70711           10"
            %         "      0.70711      0.70711           15"
            %         "            0            0            1"
            %         ""

            % There is an extra blank line in s because formattedDisplayText returns its
            % result with a final newline. Remove the blank line.
            s(s == "") = [];

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "      0.70711     -0.70711           10"
            %         "      0.70711      0.70711           15"
            %         "            0            0            1"

            % Remove the same number of leading spaces from each line. In
            % the above sample, for example, each line starts with at least
            % 6 spaces, so remove 6 spaces from each line.
            p = lineBoundary("start") + asManyOfPattern(" ");
            leading_spaces = extract(s,p);
            num_leading_spaces = strlength(leading_spaces);
            num_spaces_to_remove = min(num_leading_spaces);
            if num_spaces_to_remove > 0
                remove_pattern = lineBoundary("start") + ...
                    string(repmat(' ',1,num_spaces_to_remove));
                s = replace(s,remove_pattern,"");
            end

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "0.70711     -0.70711           10"
            %         "0.70711      0.70711           15"
            %         "      0            0            1"            

            % Add first line prefix and indent all other lines to match.
            prefix = "A: [";
            spaces = string(repmat(' ',1,strlength(prefix)));
            s(1) = prefix + s(1);
            s(2:end) = spaces + s(2:end);

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "A: [0.70711     -0.70711           10"
            %         "    0.70711      0.70711           15"
            %         "          0            0            1"                 

            % Figure out how many spaces are needed to align "A:" at the
            % colon, given the length of all the other properties. Consider
            % that there might be multiple property groups.
            max_prop_name_length = 0;
            g = getPropertyGroups(this_tform);
            for k = 1:length(g)
                n = max(strlength(g(k).PropertyList));
                max_prop_name_length = max(max_prop_name_length,n);
            end

            % Indent the whole block so that "A:" is right-aligned with the
            % other property names, include the extra spaces added by
            % MATLAB to all the property lines (3).
            s = string(repmat(' ',1,max_prop_name_length + 3)) + s;

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "                 A: [0.70711     -0.70711           10"
            %         "                     0.70711      0.70711           15"
            %         "                           0            0            1"            

            % Append suffix to last line.
            suffix = "]";
            s(end) = s(end) + suffix;

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "                 A: [0.70711     -0.70711           10"
            %         "                     0.70711      0.70711           15"
            %         "                           0            0            1]"             

            % Display mechanism expects a final newline, so append ""
            % before calling join.
            s(end+1) = "";

            % Sample s
            %
            % Column:  1234567890123456789012345678901234567890123456789012
            %
            %         "                 A: [0.70711     -0.70711           10"
            %         "                     0.70711      0.70711           15"
            %         "                           0            0            1]"  
            %         ""

            s = join(s,newline);

            % getFooter is required to return a char vector.
            footer_text = char(s);
        end
    end

    methods
        function varargout = transformPointsForward(self,varargin)
            coder.inline('always');
            coder.internal.prefer_const(self,varargin);
                        
            [varargout{1:nargout}] = transformPoints(self,"forward",varargin{:});
        end

        function varargout = transformPointsInverse(self,varargin)
            coder.inline('always');
            coder.internal.prefer_const(self,varargin);
                        
            [varargout{1:nargout}] = transformPoints(self,"inverse",varargin{:});
        end    

        function invtform = invert(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            invtform = self;
            invtform.A = inv(invtform.A);
        end   
    end

    %
    % Property set/get methods
    %
    methods
        function self = set.A(self,A_in)
            coder.inline('always');
            coder.internal.prefer_const(self,A_in);
                        
            % Make sure A_in has the right type and is one of the allowed
            % sizes and is not singular.

            % The following error check is implemented this way, instead of
            % using validateattributes, to support codegen and to eliminate
            % the printing of stack information when reporting an error for
            % setting an object property.
            valid_type = isa(A_in,"double") || isa(A_in,"single");
            pass_basic_checks = valid_type && isreal(A_in);
            msg_id = "images:geotrans:invalidTransformationMatrixType";
            if ~pass_basic_checks
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end

            % The checkA function forces A to be square, adding the extra
            % homogeneous affine row if needed.
            [A_in,err_msg_id] = checkA(A_in,self.Dimensionality);
            if err_msg_id ~= "" 
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(err_msg_id)));
                else
                    coder.internal.error("images:geotrans:invalidTransformationMatrix");
                end
            end

            % Constrain A to be exactly valid for the concrete subclass,
            % according to the concrete subclass's implementation of
            % constrainA. Also, capture the underlying parameters that are
            % derived from A.
            [Ac,params] = self.constrainA(A_in);

            % If the constrained matrix is not within floating-point
            % round-off error of the original matrix, then the original
            % matrix is not a valid transformation matrix for the subclass.
            is_valid_for_this_class = images.geotrans.internal.matricesNearlyEqual(Ac,A_in);
            msg_id = "images:geotrans:invalidTransformationMatrix";
            if ~is_valid_for_this_class
                if coder.target('MATLAB')
                    throwAsCaller(MException(message(msg_id)));
                else
                    coder.internal.error(msg_id);
                end
            end

            % Warn here if transformPointsInverse with this object will
            % throw a warning about a badly-conditioned or
            % singular-to-working-precision matrix.
            images.geotrans.internal.checkTransformationMatrixCondition(Ac);

            % Set the underlying parameters that are derived from A.
            self = setUnderlyingParameters(self,params);
        end

        function A_out = get.A(self)
            % Invoke the subclass's implementation of constructH.
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            A_out = constructA(self);
        end

        function obj = set.T(obj,val)
            coder.inline('always');
            coder.internal.prefer_const(obj,val);
                        
            obj.A = val.';
        end

        function value = get.T(obj)
            coder.inline('always');
            coder.internal.prefer_const(obj);
                        
            value = obj.A.';
        end
    end

    methods (Access = protected)
        function varargout = transformPoints(self,direction,varargin)
            % This method implements logic that works for both forward and
            % inverse point transformations. If the input points are
            % unpacked, it packs them. Then it calls transformPackedPoints
            % with the specified direction. Finally, if the input points
            % were unpacked, then the output arguments are unpacked as
            % well.

            coder.inline('always');
            coder.internal.prefer_const(self,direction,varargin);
                                            
            packed_points = (nargin == 3);

            if packed_points
                varargout{1} = transformPackedPoints(self,varargin{1},direction);
            else
                coder.internal.errorIf(length(varargin) ~= self.Dimensionality, ...
                    "images:geotrans:numCoordinatesMismatch");
                sz_1 = size(varargin{1});
                for k = 2:length(varargin)
                    if ~isequal(sz_1,size(varargin{k}))
                        coder.internal.error("images:geotrans:coordinatesSizeMismatch")
                    end
                end

                if self.Dimensionality == 2
                    [varargout{1},varargout{2}] = transformUnpackedPoints2D(self,...
                        varargin{1},varargin{2},direction);
                else
                    [varargout{1},varargout{2},varargout{3}] = transformUnpackedPoints3D(self,...
                        varargin{1},varargin{2},varargin{3},direction);
                end
            end
        end
        
        function X = transformPackedPoints(self,U,direction)

            coder.inline('always');
            coder.internal.prefer_const(self,U,direction);

            coder.internal.errorIf(size(U,2) ~= self.Dimensionality,...
                "images:geotrans:packedPointsSizeMismatch");

            if images.geotrans.internal.isAffine(self.A)
                A_linear_part = self.A(1:end-1,1:end-1);
                A_additive_part = self.A(1:end-1,end).';

                % Write the matrix operations below using an order that
                % avoids transposing U, which might be big if transforming
                % a large number of points.
                if direction == "forward"
                    X = U * A_linear_part.' + A_additive_part;
                else
                    X = (U - A_additive_part) / A_linear_part.';
                end
            else
                U = [U ones(size(U,1),1,'like',U)];

                % Write the matrix operations below using an order that
                % avoids transposing U, which might be big if transforming
                % a large number of points.
                if direction == "forward"
                    X = U * (self.A.');
                else
                    X = U / (self.A.');
                end
                p = self.Dimensionality;
                X(:,1:p) = X(:,1:p) ./ X(:,end);
                X = X(:,1:p);
            end
        end
    end

    %
    % Provide isRigid, isSimilarity, and isTranslation methods like those
    % provided by the old geometric transformation classes. The technique
    % is to see if the input object is convertable to the 2-D or 3-D
    % version of the class type that is being tested. For example, of
    % rigidtform2(matrix_transformation_obj) throws an error, then
    % matrix_transformation_obj is not rigid.
    methods (Hidden)
        function tf = isRigid(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            if self.Dimensionality == 2
                tf = rigidtform2d.isValidTransformationMatrix(self.A);
            else
                tf = rigidtform3d.isValidTransformationMatrix(self.A);
            end
        end

        function tf = isSimilarity(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            if self.Dimensionality == 2
                tf = simtform2d.isValidTransformationMatrix(self.A);
            else
                tf = simtform3d.isValidTransformationMatrix(self.A);
            end
        end

        function tf = isTranslation(self)
            coder.inline('always');
            coder.internal.prefer_const(self);
                        
            if self.Dimensionality == 2
                tf = transltform2d.isValidTransformationMatrix(self.A);
            else
                tf = transltform3d.isValidTransformationMatrix(self.A);
            end
        end
    end

end

function [u,v] = transformUnpackedPoints2D(tform,x,y,direction)
    coder.inline('always');
    coder.internal.prefer_const(tform,x,y,direction);

    if images.geotrans.internal.isAffine(tform.A)
        A_linear_part = tform.A(1:end-1,1:end-1);
        A_additive_part = tform.A(1:end-1,end).';

        % Write the matrix operations below using an order that
        % avoids transposing U, which might be big if transforming
        % a large number of points.
        if direction == "forward"
            u = A_linear_part(1,1)*x + A_linear_part(1,2)*y + A_additive_part(1);
            v = A_linear_part(2,1)*x + A_linear_part(2,2)*y + A_additive_part(2);
        else
            B = inv(A_linear_part);
            xp = x - A_additive_part(1);
            yp = y - A_additive_part(2);
            u = B(1,1)*xp + B(1,2)*yp;
            v = B(2,1)*xp + B(2,2)*yp;
        end
    else
        if direction == "forward"
            B = tform.A;
        else
            B = inv(tform.A);
        end
        alpha = ones(size(x),'like',x);
        up = B(1,1)*x + B(1,2)*y + B(1,3)*alpha;
        vp = B(2,1)*x + B(2,2)*y + B(2,3)*alpha;
        beta = B(3,1)*x + B(3,2)*y + B(3,3)*alpha;
        u = up ./ beta;
        v = vp ./ beta;
    end
end

function [u,v,w] = transformUnpackedPoints3D(tform,x,y,z,direction)
    coder.inline('always');
    coder.internal.prefer_const(tform,x,y,z,direction);

    if images.geotrans.internal.isAffine(tform.A)
        A_linear_part = tform.A(1:end-1,1:end-1);
        A_additive_part = tform.A(1:end-1,end).';

        % Write the matrix operations below using an order that
        % avoids transposing U, which might be big if transforming
        % a large number of points.
        if direction == "forward"
            u = A_linear_part(1,1)*x + A_linear_part(1,2)*y + A_linear_part(1,3)*z + A_additive_part(1);
            v = A_linear_part(2,1)*x + A_linear_part(2,2)*y + A_linear_part(2,3)*z + A_additive_part(2);
            w = A_linear_part(3,1)*x + A_linear_part(3,2)*y + A_linear_part(3,3)*z + A_additive_part(3);
        else
            B = inv(A_linear_part);
            xp = x - A_additive_part(1);
            yp = y - A_additive_part(2);
            zp = z - A_additive_part(3);
            u = B(1,1)*xp + B(1,2)*yp + B(1,3)*zp;
            v = B(2,1)*xp + B(2,2)*yp + B(2,3)*zp;
            w = B(3,1)*xp + B(3,2)*yp + B(3,3)*zp;
        end
    else
        if direction == "forward"
            B = tform.A;
        else
            B = inv(tform.A);
        end
        alpha = ones(size(x),'like',x);
        up = B(1,1)*x + B(1,2)*y + B(1,3)*z + B(1,4)*alpha;
        vp = B(2,1)*x + B(2,2)*y + B(2,3)*z + B(2,4)*alpha;
        wp = B(3,1)*x + B(3,2)*y + B(3,3)*z + B(3,4)*alpha;
        beta = B(4,1)*x + B(4,2)*y + B(4,3)*z + B(4,3)*alpha;
        u = up ./ beta;
        v = vp ./ beta;
        w = wp ./ beta;
    end
end

function [A_out,err_msg_id] = checkA(A_in,d)
    % If A is d-by-(d+1), then add a final row to A_out. Otherwise, A_out
    % is the same as A_in.
    %
    % If err_msg_args is returned as nonempty, then A_in is invalid, and
    % err_msg_args{:} can be passed directly to message().
    %
    % Error handling is implemented this to work for codegen and also to
    % minize the printing of irrelevant stack information in the case of an
    % invalid input.

    coder.inline('always');
    coder.internal.prefer_const(A_in,d);
                
    err_msg_id = "";

    % A is allowed to be a square matrix or a d-by-(d+1) matrix, where the
    % input argument d is the dimensionality of the transformation.
    sz = size(A_in);
    if ~isequal(sz,[d+1 d+1]) && ~isequal(sz,[d d+1])
        A_out = A_in;
        err_msg_id = "images:geotrans:invalidTransformationMatrixSize";
        return
    end 

    if (sz(1) == d)
        % Make the matrix square by adding a final row containing 0s and a
        % 1 in the final column.
        v = zeros(1,d+1,'like',A_in);
        v(1,d+1) = 1;
        A_out = cast([A_in ; v],class(A_in));
    else
        A_out = A_in;
    end
end

% Copyright 2021-2023 The MathWorks, Inc.