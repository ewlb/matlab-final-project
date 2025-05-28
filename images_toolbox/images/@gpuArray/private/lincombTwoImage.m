function out = lincombTwoImage(x,y,k1,k2,k0)
%LINCOMBTWOIMAGE used by imlincomb.
%   Private helper function to compute a two-image linear combination.

%  Copyright 1993-2020 The MathWorks, Inc.

out = k0 + k1*double(x) + k2*double(y);