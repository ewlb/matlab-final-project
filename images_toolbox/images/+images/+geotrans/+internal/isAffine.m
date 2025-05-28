function tf = isAffine(A) %#codegen
    coder.inline('always');
    coder.internal.prefer_const(A);
    
    tf = (A(end,end) == 1) && ...
        all(A(end,1:end-1) == 0);
end

% Copyright 2022 The MathWorks, Inc.