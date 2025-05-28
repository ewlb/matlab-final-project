function out = lincomb(r,g,b,TR,TG,TB,offset)
%LINCOMB Private function to calculate linear combination of images.
%   OUT = LINCOMB(K1,A1,K2,A2, ..., Kn,An,K) computes K1*A1 + K2*A2 +
%   ... + Kn*An + K.  A1, A2, ..., An are real, nonsparse, numeric arrays
%   of the same size, and K1, K2, ..., Kn are scalars.

%  Copyright 1993-2020 The MathWorks, Inc.

out = TR*r + TG*g + TB*b + offset;

end
