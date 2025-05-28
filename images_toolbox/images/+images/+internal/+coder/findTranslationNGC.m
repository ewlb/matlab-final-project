% Find translation that shifts the "moving" image to align it with the
% "fixed" image using the normalized gradient correlation (NGC) method.
%
% The two input images are expected to be floating-point and real, with a
% minimum dimension size of 2 (no vectors or empty matrices). These
% conditions are not checked here.

function [tform,peak,NGC] = findTranslationNGC(moving,fixed) %#codegen

    % Compute the normalized gradient correlation. The outputs shift_x and
    % shift_y give the moving image shift offset values (positive and
    % negative) corresponding to each column and row of NGC.
    
    [NGC,shift_x,shift_y] = images.internal.coder.normalizedGradientCorrelation( ...
        moving, fixed);
    
    % Estimate the subpixel location of the peak value of NGC.
    
    [NGC_xpeak,NGC_ypeak,peakTmp] = images.internal.coder.peakLocation2D(NGC);
    
    % Always return the peak value as a double. This matches the behavior
    % of the original phase correlation implementation.
    if isa(peakTmp,'double')
        peak = peakTmp;
    else
        peak = double(peakTmp);
    end
    
    % Compute the subpixel peak location and NGC shift offset values to
    % compute the horizontal and vertical translation values.
    
    dx = interp1(1:length(shift_x),shift_x,NGC_xpeak);
    dy = interp1(1:length(shift_y),shift_y,NGC_ypeak);
    
    % Always return tform with double-precision parameters.
    
    tform = transltform2d(double([dx dy]));
    
end

% Copyright 2024 The MathWorks, Inc.