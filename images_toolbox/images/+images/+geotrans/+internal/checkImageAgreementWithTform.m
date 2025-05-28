function checkImageAgreementWithTform(A,tform)
% Check agreement of input image with dimensionality of tform.

% Copyright 2019-2020 The MathWorks, Inc.

if tform.Dimensionality == 3
    if ~isequal(ndims(A),3)
        error(message('images:imwarp:tformDoesNotAgreeWithSizeOfA','A'));
    end
end

end