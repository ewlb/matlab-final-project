function t = isNonnegativeRealScalar(P) %#codegen
    %   isNonnegativeRealScalar(P) returns 1 if P is a real,
    %   scalar number greater than 0 and returns 0 otherwise.

    % Copyright 2021-2023 The MathWorks, Inc.
  coder.inline('always');
  t = images.internal.imnoise.isReal(P) && isscalar(P) && P>=0;
end