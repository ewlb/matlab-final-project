% Compute log-polar sampling of input matrix, F. 
%
% F is assumed to be the output of fft2, without preprocessing by fftshift,
% with size NxN, where N is even. These assumptions are not checked here.
%
% The horizontal dimension of L (columns) samples the radial axis of the
% log-polar resampling. The output b is the exponent base that is used to
% compute the scale factor corresponding to a shift in the horizontal
% dimension: s = b^shift_x.
%
% The vertical dimension of L (rows) samples the angular axis. The output
% vector thetad gives the angle, in degrees, for each corresponding row.
%
% Note that the radial sampling grid only goes to the horizontal and
% vertical boundary of the fundamental frequency domain period. It does not
% go all the way to the frequency domain corner. This is OK because, in the
% normalized gradient correlation method, the gradient computation is
% equivalent to filtering with a filter, [0.5 0 -0.5], that has a zero at
% the Nyquist frequency. That means that the highest frequencies are mostly
% suppressed anyway, doubly so (horizontally and vertically) for the high
% frequencies in the corners. For the purpose of NGC-based registration,
% the most meaningful information lies with the sampling circle that
% doesn't include the corners.

function [L,b,thetad] = logPolarResample(F) %#codegen

    % Assume that F is N x N where N is even.
    N = size(F,1);

    % In Tzimiropoulos 2010, the algorithm description says to resample the
    % Fourier transform on an N/2 x N/2 log-polar grid. However, there is
    % no particular reason to use the same sampling grid size in the radial
    % and angular dimensions, and experiments during algorithm assessment
    % showed benefit for using more grid samples in the angular dimension,
    % as well as for enforcing a minimum number of grid samples in the
    % radial dimension.

    % Define the radial dimension sampling.
    % 
    % K is the number of grid samples in the radial dimension.
    K = max(N/2,256);
    rho = 0:(K-1);
    %
    % Calculate the exponential base based on the size of F and the number
    % of grid samples.
    b = (N/2)^(1/(K-1));    

    % Define the angular dimension sampling.
    %
    % Use vertical dimension (rows) of L as the angular axis (theta). Use
    % degrees. Sample from 0 to 179.9 degrees with a 0.1-degree spacing.
    thetad = (0:1799)/10;
    thetad = thetad';    

    % Circularly shift the input FFT2 matrix so that the zero-frequency
    % element is in the center. For an even dimension, N, fftshift places
    % the zero-frequency element at index (N/2) + 1.
    F = fftshift(F);
    x_c = (N/2) + 1;
    y_c = (N/2) + 1;    


    % Compute the interpolation coordinates based on the radial and angular
    % dimension sampling.
    r = b.^rho;
    xq = r .* cosd(thetad) + x_c;
    yq = r .* sind(thetad) + y_c;

    % Floating-point round-off error in the above computations could result
    % in xq and yq values slightly out of bounds, which will cause interp2
    % to return NaNs. To prevent that, clip the values.
    xq = min(max(xq,1),N);
    yq = min(max(yq,1),N);
    
    % Use bilinear interpolation to compute the log-polar result.
    L = images.internal.interp2d(F,xq,yq,'bilinear',0);
end

% Copyright 2024 The MathWorks, Inc.