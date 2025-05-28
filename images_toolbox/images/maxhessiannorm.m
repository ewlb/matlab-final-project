function C = maxhessiannorm(I, thickness)
%MAXHESSIANNORM Maximum of the Frobenius Norm of Hessian of a matrix.
%   C = maxhessiannorm(I) calculates the maximum of Frobenius norm of the
%   hessian of intensity image I. As this function is used in the context
%   of fibermetric, default thickness of 4 is used to find the hessian and
%   returns the obtained value as C.
%
%   C = maxhessiannorm(I, thickness) calculates the maximum of Frobenius
%   norm of the hessian of intensity image I using thickness. The value
%   thickness is a positive finite scalar integer in pixels which
%   characterizes the thickness of tubular structures. It should be of the
%   order of the width of the tubular structures in the image domain.
%
%   Class Support 
%   -------------
%   Input image A must be a 2D grayscale image and can be of class uint8,
%   int8, uint16, int16, uint32, int32, single, or double. It must be real
%   and nonsparse. The scalar output variable C is of class double.
%
%   Notes 
%   -----
%   maxhessiannorm serves as a helper function to FIBERMETRIC which changed
%   in version 9.4 (R2018b). In order to get the same results produced by
%   the previous fibermetric implementation use this function to find the
%   'StructureSensitivity' value which is 0.5*C and feed that as an input
%   to fibermetric. This is only supported for 2D images.
%
%   Reference 
%   ---------
%   [1] Frangi, Alejandro F., et al. "Multiscale vessel enhancement
%   filtering." Medical Image Computing and Computer-Assisted Intervention
%   -- MICCAI 1998. Springer Berlin Heidelberg, 1998. 130-137
%
%   Example 
%   -------
%       % Find fiberemetric default 'StructureSensitivity' using maxhessiannorm 
%       IM = imread('threads.png');
%       C = maxhessiannorm(IM, 7);
%       J = fibermetric(IM, 7, 'ObjectPolarity', 'dark', 'StructureSensitivity', 0.5*C); 
%       figure, imshow(J);
%       title('Possible tubular structures 7 pixels thick')
%
%   See also fibermetric, edge, imgradient.

%   Copyright 2017-2018 The MathWorks, Inc.
narginchk(1,2);
if nargin == 1
    thickness = 4;
end

validateInp(I);
validateThickness(thickness);
sigma = thickness/6;
[Gxx, Gyy, Gxy]     = images.internal.hessian2D(I, sigma);
[eigVal1, eigVal2]  = images.internal.find2DEigenValues(Gxx, Gyy, Gxy);
absEigVal1 = abs(eigVal1);
absEigVal2 = abs(eigVal2);
maxHessianNorm = max([max(absEigVal1(:)), max(absEigVal2)]);
C = maxHessianNorm;
end

function validateInp(I)

allowedImageTypes = {'uint8', 'uint16', 'uint32', 'double', 'single', 'int8', 'int16', 'int32'};
validateattributes(I, allowedImageTypes, {'nonempty',...
    'nonsparse', 'real', 'finite', '2d'}, mfilename, 'I', 1);
end


function validateThickness(thickness)

validateattributes(thickness, {'numeric'}, ...
    {'integer', 'nonsparse', 'nonempty', 'positive', 'finite', 'scalar'}, ...
    mfilename, 'THICKNESS', 2);

end