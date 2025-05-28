function t = isRealScalar(P) %#codegen
    %   isRealScalar(P) returns 1 if P is a real,
    %   scalar number and returns 0 otherwise.

    % Copyright 2021-2023 The MathWorks, Inc.
  coder.inline('always');
  t = images.internal.imnoise.isReal(P) && isscalar(P);
end