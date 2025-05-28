% Using normalized gradient correlation, find the scale factor and rotation
% angle (in degrees) to align image I1 with image I2.
%
% Mathematical symbols used for variable names are from Tzimiropoulos 2010,
% particularly Algorithm 1, p. 1903.
%
% Inputs: Two images I_i, i = 1,2 of size X_i x Y_i related by a
% translation t, rotation r, and scaling s.

function [s,r] = findScaleRotationNGC(I1,I2) %#codegen

    [Y1,X1] = size(I1);
    [Y2,X2] = size(I2);
    Np = max([X1 Y1 X2 Y2]);

    N = images.internal.coder.fftPadSize(Np);  

    % Compute the log-polar resampling of the magnitude of the Fourier
    % transform for each input image.
    [L1,base,thetad] = images.internal.coder.logPolarResample(...
        abs(fft2(images.internal.coder.complexGradientImage(I1),N,N)));
    L2 = images.internal.coder.logPolarResample(...
        abs(fft2(images.internal.coder.complexGradientImage(I2),N,N)));

    % Use NGC to find the translation to align L1 with L2.
    tform_translation_L1_L2 = images.internal.coder.findTranslationNGC(L1,L2);
    tx = tform_translation_L1_L2.Translation(1);
    ty = tform_translation_L1_L2.Translation(2);

    % Use the radial dimension and angular sampling info returned by
    % logPolarResample to convert the horizontal and vertical shift values
    % to scale factor and rotation angle.
    sTmp = base^(-tx);
    P = length(thetad);
    if (ty >= 0)
        rTmp = interp1(0:(P-1),thetad,ty);
    else
        rTmp = -interp1(0:(P-1),thetad,-ty);
    end

    % Always return double-precision parameters.
    if isa(sTmp,'double')
        s = sTmp;
    else
        s = double(sTmp);
    end
    if isa(rTmp,'double')
        r = rTmp;
    else
        r = double(rTmp);
    end
    
end

% Copyright 2024 The MathWorks, Inc.