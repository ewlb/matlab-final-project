function t = isNonnegativeReal(P) %#codegen
    %   isNonnegativeReal(P) returns 1 if P contains only real
    %   numbers greater than or equal to 0 and returns 0 otherwise.

    % Copyright 2021-2023 The MathWorks, Inc.
  coder.inline('always');
  t = images.internal.imnoise.isReal(P) && all(P>=0, "all");
end