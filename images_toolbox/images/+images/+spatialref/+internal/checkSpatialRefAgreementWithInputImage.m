function checkSpatialRefAgreementWithInputImage(A,RA)
% Check agreement of input spatial referencing object with input image.

%   Copyright 2019-2020 The MathWorks, Inc.

if ~sizesMatch(RA,A)
    error(message('images:imwarp:spatialRefDimsDisagreeWithInputImage','ImageSize','RA','A'));
end

end