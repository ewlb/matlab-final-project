function Z = imabsdiff(varargin) %#codegen
%IMABSDIFF Absolute difference of two images.

%   Copyright 2015-2018 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(2,2);

X = varargin{1};
Y = varargin{2};

validateattributes(X, {'numeric','logical'}, {'real'}, mfilename, 'X', 1);
validateattributes(Y, {'numeric','logical'}, {'real'}, mfilename, 'Y', 2);

coder.internal.errorIf(~strcmp(class(X),class(Y)),...
    'images:checkForSameSizeAndClass:mismatchedClass');

coder.internal.errorIf(~isequal(size(X),size(Y)),...
    'images:checkForSameSizeAndClass:mismatchedSize');

if isempty(X)
    if islogical(X)
        Z = false(size(X));
    else
        Z = zeros(size(X), 'like', X);
    end
else
    Z = coder.nullcopy(X);
    
    switch (class(X))
        case 'logical'
            diffVal = coder.nullcopy(int16(1));
            Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal);
        case 'uint8'
            diffVal = coder.nullcopy(int16(1));
            Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal);
        case 'int8'
            diffVal = coder.nullcopy(int16(1));
            Z = absdiffIntGeneric(X,Y,Z,diffVal);
        case 'uint16'
            diffVal = coder.nullcopy(int32(1));
            Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal);
        case 'int16'
            diffVal = coder.nullcopy(int32(1));
            Z = absdiffIntGeneric(X,Y,Z,diffVal);
        case 'uint32'
            diffVal = coder.nullcopy(int64(1));
            Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal);
        case 'int32'
            diffVal = coder.nullcopy(int64(1));
            Z = absdiffIntGeneric(X,Y,Z,diffVal);
        case 'single'
            diffVal = coder.nullcopy(single(1));
            Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal);
        case 'double'
            diffVal = coder.nullcopy(double(1));
            Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal);
        otherwise
            assert(false,'Unsupported datatype')
    end
    
end
end

function Z = absdiffUIntOrFlpGeneric(X,Y,Z,diffVal)
% Calculate the absolute difference and cast to output datatype.

coder.inline('always');
coder.internal.prefer_const(X,Y,Z,diffVal);

if coder.isColumnMajor
    for idx = 1:numel(X)
        diffVal = cast(X(idx),'like',diffVal)-cast(Y(idx),'like',diffVal);
        if diffVal < 0
            diffVal = -diffVal;
        end
        
        Z(idx) = cast(diffVal,'like',Z);
    end
else % Row-major
    if numel(size(X)) == 2
        for i = 1:size(X,1)
            for j = 1:size(X,2)
                diffVal = cast(X(i,j),'like',diffVal)-cast(Y(i,j),'like',diffVal);
                if diffVal < 0
                    diffVal = -diffVal;
                end
                
                Z(i,j) = cast(diffVal,'like',Z);
            end
        end
    elseif numel(size(X)) == 3
        for i = 1:size(X,1)
            for j = 1:size(X,2)
                for k = 1:size(X,3)
                    diffVal = cast(X(i,j,k),'like',diffVal)-cast(Y(i,j,k),'like',diffVal);
                    if diffVal < 0
                        diffVal = -diffVal;
                    end
                    
                    Z(i,j,k) = cast(diffVal,'like',Z);
                end
            end
        end
    else
        for idx = 1:numel(X)
            diffVal = cast(X(idx),'like',diffVal)-cast(Y(idx),'like',diffVal);
            if diffVal < 0
                diffVal = -diffVal;
            end
            
            Z(idx) = cast(diffVal,'like',Z);
        end
    end
end

end

function Z = absdiffIntGeneric(X,Y,Z,diffVal)
% Calculate the absolute difference and saturate.

coder.inline('always');
coder.internal.prefer_const(X,Y,Z,diffVal);

if coder.isColumnMajor
    for idx = 1:numel(X)
        diffVal = cast(X(idx),'like',diffVal)-cast(Y(idx),'like',diffVal);
        if diffVal < 0
            diffVal = -diffVal;
        end
        
        % Saturate
        Z(idx) = diffVal;
    end
else% Row-major
    if numel(size(X)) == 2
        for i = 1:size(X,1)
            for j = 1:size(X,2)
                diffVal = cast(X(i,j),'like',diffVal)-cast(Y(i,j),'like',diffVal);
                if diffVal < 0
                    diffVal = -diffVal;
                end
                
                % Saturate
                Z(i,j) = diffVal;
            end
        end
    elseif numel(size(X)) == 3
        for i = 1:size(X,1)
            for j = 1:size(X,2)
                for k = 1:size(X,3)
                    diffVal = cast(X(i,j,k),'like',diffVal)-cast(Y(i,j,k),'like',diffVal);
                    if diffVal < 0
                        diffVal = -diffVal;
                    end
                    
                    % Saturate
                    Z(i,j,k) = diffVal;
                end
            end
        end
    else
        for idx = 1:numel(X)
            diffVal = cast(X(idx),'like',diffVal)-cast(Y(idx),'like',diffVal);
            if diffVal < 0
                diffVal = -diffVal;
            end
            
            % Saturate
            Z(idx) = diffVal;
        end
    end
end
end
