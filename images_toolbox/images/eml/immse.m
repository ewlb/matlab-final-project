function err = immse(x, y) %#codegen

% Copyright 2015-2018 The MathWorks, Inc.

%#ok<*EMCA>

validateattributes(x,{'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', ...
    'single','double'},{'nonsparse'},mfilename,'A',1);
validateattributes(y,{'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', ...
    'single','double'},{'nonsparse'},mfilename,'B',1);

% x and y must be of the same class
coder.internal.errorIf(~isa(x,class(y)),'images:validate:differentClassMatrices','A','B');

% x and y must have the same size
coder.internal.errorIf(~isequal(size(x),size(y)),'images:validate:unequalSizeMatrices','A','B');

if isa(x,'single')
    % if the input is single, return a single
    classToUse = 'single';
else
    % otherwise, return a double
    classToUse = 'double';
end

if isempty(x) % If x is empty, y must also be empty
    err = cast([],classToUse);
    return;
end

err = cast(0,classToUse);

numElems = numel(x);
if coder.isColumnMajor
    for i = 1:numElems
        a = cast(x(i),classToUse);
        b = cast(y(i),classToUse);
        err = err + (a-b)*(a-b);
    end
else % Row-major
    if numel(size(x)) == 2
        for i = 1:size(x,1)
            for j = 1:size(x,2)
                a = cast(x(i,j),classToUse);
                b = cast(y(i,j),classToUse);
                err = err + (a-b)*(a-b);
            end
        end
    elseif numel(size(x)) == 3
        for i = 1:size(x,1)
            for j = 1:size(x,2)
                for k = 1:size(x,3)
                    a = cast(x(i,j,k),classToUse);
                    b = cast(y(i,j,k),classToUse);
                    err = err + (a-b)*(a-b);
                end
            end
        end
    else
        for i = 1:numElems
            a = cast(x(i),classToUse);
            b = cast(y(i),classToUse);
            err = err + (a-b)*(a-b);
        end
    end
end
err = err/cast(numElems,classToUse);
