function t = isVector(P) %#codegen
    %   isVector(P) returns 1 if P is a vector and returns 0 otherwise.

    % Copyright 2021 The MathWorks, Inc.
  coder.inline('always');
  t = ((numel(P) >= 2) && ((size(P,1) == 1) || (size(P,2) == 1)));
end