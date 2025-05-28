function [img,H] = iradon(varargin)
%IRADON Inverse Radon transform.
%   I = iradon(R,THETA) reconstructs the image I from projection data in
%   the 2-D gpuArray R.  The columns of R are parallel beam projection
%   data. IRADON assumes that the center of rotation is the center point of
%   the projections, which is defined as ceil(size(R,1)/2).
%
%   THETA describes the angles (in degrees) at which the projections were
%   taken.  It can be either a vector (or gpuArray vector) containing the
%   angles or a scalar specifying D_theta, the incremental angle between
%   projections. If THETA is a vector, it must contain angles with equal
%   spacing between them.  If THETA is a scalar specifying D_theta, the
%   projections are taken at angles THETA = m * D_theta; m =
%   0,1,2,...,size(R,2)-1.  If the input is the empty matrix ([]), D_theta
%   defaults to 180/size(R,2).
%
%   IRADON uses the filtered backprojection algorithm to perform the inverse
%   Radon transform.  The filter is designed directly in the frequency
%   domain and then multiplied by the FFT of the projections.  The
%   projections are zero-padded to a power of 2 before filtering to prevent
%   spatial domain aliasing and to speed up the FFT.
%
%   I = IRADON(R,THETA,INTERPOLATION,FILTER,FREQUENCY_SCALING,OUTPUT_SIZE)
%   specifies parameters to use in the inverse Radon transform.  You can
%   specify any combination of the last four arguments.  IRADON uses default
%   values for any of these arguments that you omit.
%
%   INTERPOLATION specifies the type of interpolation to use in the
%   backprojection. The default is linear interpolation. Available methods
%   are:
%
%      'nearest' - nearest neighbor interpolation
%      'linear'  - linear interpolation (default)
%
%   FILTER specifies the filter to use for frequency domain filtering.
%   FILTER is a string or a character vector that specifies any of the
%   following standard filters:
%
%   'Ram-Lak'     The cropped Ram-Lak or ramp filter (default).  The
%                 frequency response of this filter is |f|.  Because this
%                 filter is sensitive to noise in the projections, one of
%                 the filters listed below may be preferable.
%   'Shepp-Logan' The Shepp-Logan filter multiplies the Ram-Lak filter by
%                 a sinc function.
%   'Cosine'      The cosine filter multiplies the Ram-Lak filter by a
%                 cosine function.
%   'Hamming'     The Hamming filter multiplies the Ram-Lak filter by a
%                 Hamming window.
%   'Hann'        The Hann filter multiplies the Ram-Lak filter by a
%                 Hann window.
%   'none'        No filtering is performed.
%
%   FREQUENCY_SCALING is a scalar in the range (0,1] that modifies the
%   filter by rescaling its frequency axis.  The default is 1.  If
%   FREQUENCY_SCALING is less than 1, the filter is compressed to fit into
%   the frequency range [0,FREQUENCY_SCALING], in normalized frequencies;
%   all frequencies above FREQUENCY_SCALING are set to 0.
%
%   OUTPUT_SIZE is a scalar that specifies the number of rows and columns in
%   the reconstructed image.  If OUTPUT_SIZE is not specified, the size is
%   determined from the length of the projections:
%
%       OUTPUT_SIZE = 2*floor(size(R,1)/(2*sqrt(2)))
%
%   If you specify OUTPUT_SIZE, IRADON reconstructs a smaller or larger
%   portion of the image, but does not change the scaling of the data.
%
%   If the projections were calculated with the RADON function, the
%   reconstructed image may not be the same size as the original image.
%
%   [I,H] = iradon(...) returns the frequency response of the filter in the
%   vector H.
%
%   Class Support
%   -------------
%   R can be a gpuArray of underlying class double or single. All other
%   numeric input arguments must be double or gpuArray of underlying class
%   double. I has the same class as R. H is a gpuArray of underlying class
%   double.
%
%   Notes
%   -----
%   The GPU implementation of this function supports only nearest neighbor
%   and linear interpolation methods for the backprojection. 
%
%   Examples
%   --------
%   Compare filtered and unfiltered backprojection.
%
%       P = gpuArray(phantom(128));
%       R = radon(P,0:179);
%       I1 = iradon(R,0:179);
%       I2 = iradon(R,0:179,'linear','none');
%       subplot(1,3,1), imshow(P), title('Original')
%       subplot(1,3,2), imshow(I1), title('Filtered backprojection')
%       subplot(1,3,3), imshow(I2,[]), title('Unfiltered backprojection')
%
%   Compute the backprojection of a single projection vector. The IRADON
%   syntax does not allow you to do this directly, because if THETA is a
%   scalar it is treated as an increment.  You can accomplish the task by
%   passing in two copies of the projection vector and then dividing the
%   result by 2.
%
%       P = gpuArray(phantom(128));
%       R = radon(P,0:179);
%       r45 = R(:,46);
%       I = iradon([r45 r45], [45 45])/2;
%       imshow(I, [])
%       title('Backprojection from the 45-degree projection')
%
%   See also FAN2PARA, FANBEAM, IFANBEAM, PARA2FAN, PHANTOM,
%            GPUARRAY/RADON,GPUARRAY.

%   Copyright 2013-2023 The MathWorks, Inc.

%   References:
%      A. C. Kak, Malcolm Slaney, "Principles of Computerized Tomographic
%      Imaging", IEEE Press 1988.

narginchk(2,6);

args = matlab.images.internal.stringToChar(varargin);
%Dispatch to CPU if needed.
if ~isgpuarray(args{1})
    [args{:}] = gather(args{:});
    [img,H] = iradon(args{:});
    return;
end

[p,theta,filter,d,interp,N] = images.internal.iradon.parseInputs(args{:});

[p, theta, useSingleForComp, isMixedInputs] = images.internal.iradon.postProcessInputs(p, theta);

[p,H] = images.internal.iradon.filterProjections(p, filter, d, useSingleForComp, isMixedInputs);

% Zero pad the projections to size 1+2*ceil(N/sqrt(2)) if this
% quantity is greater than the length of the projections
imgDiag = 2*ceil(N/sqrt(2))+1;  % largest distance through image.
if size(p,1) < imgDiag
    rz = imgDiag - size(p,1);  % how many rows of zeros
    top = gpuArray.zeros(ceil(rz/2),size(p,2));
    bot = gpuArray.zeros(floor(rz/2),size(p,2));
    p = [top; p; bot];
end

% Backprojection
switch interp
    case images.internal.iradon.InterpModes.Nearest
        img = images.internal.gpu.iradon(N, theta, p, false);

    case images.internal.iradon.InterpModes.Linear
        img = images.internal.gpu.iradon(N, theta, p, true);
end
