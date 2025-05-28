% Copyright 2023 The MathWorks, Inc.

% Compute the complex gradient image, as defined by equation (12) in
% Tzimiropoulos et al., "Robust FFT-Based Scale-Invariant Registration with
% Image Gradients," IEEE Pattern Analysis and Machine Intelligence, vol.
% 32, no. 10, October 2010, pp. 1899-1906. DOI: 10.1109/TPAMI.2010.107
%
% Equation (12)
%
% G = G_{x} + j G_{y}, where G_x = \nabla_x I, and G_y = \nabla_y I.
%
% \nabla_x I and \nabla_y I are the horizontal and vertical gradient
% components of I. 
% 
% Tzimiropoulos 2010 is not specific about how the gradients are to be
% computed for an image. Experiments suggest using the same method as used
% by the MATLAB gradient function: a centered, first-order difference in
% the middle on the image, and a one-sided first-order difference at the
% image boundaries.
%
% Instead of calling gradient directly, an inline implementation using the
% conv2 function is used for speed.
%
% The input is assumed be a floating-point matrix with minimum dimensions
% 2x2. These conditions are not checked here.

function G = complexGradientImage(I)
    [M,N] = size(I);

    hx = [0.5 0 -0.5];
    hy = hx.';

    Gx = [I(:,2) - I(:,1), conv2(I,hx,"valid"), I(:,N) - I(:,N-1)];
    Gy = [I(2,:) - I(1,:); conv2(I,hy,"valid"); I(M,:) - I(M-1,:)];

    % Experiments show the following form to be slightly faster than G =
    % complex(Gx,Gy).
    G = Gx + 1j * Gy;
end
