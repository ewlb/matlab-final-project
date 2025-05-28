function t = isReal(P) %#codegen
    %   isReal(P) returns 1 if P contains only real
    %   numbers and returns 0 otherwise.

    % Copyright 2021-2023 The MathWorks, Inc.
  coder.inline('always');
  t = isreal(P) && allfinite(P) && ~isempty(P);
end