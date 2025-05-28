function t = isNonnegativeRealVector(P) %#codegen
    %   isNonnegativeRealVector(P) returns 1 if P is a real,
    %   vector greater than 0 and returns 0 otherwise.

    % Copyright 2021-2023 The MathWorks, Inc.
  coder.inline('always');
  t = images.internal.imnoise.isReal(P) && ...
      images.internal.imnoise.isVector(P) && ...
      all(P>=0); % P is a vector so don't need to specify "all"
end