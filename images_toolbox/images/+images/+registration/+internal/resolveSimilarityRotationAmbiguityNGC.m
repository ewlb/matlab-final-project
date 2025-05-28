% Find the best translation and final rotation angle to align the moving
% image to the fixed image given a scale and candidate rotation angle,
% where the rotation angle might be off by 180 degrees.

function [tform,peak] = resolveSimilarityRotationAmbiguityNGC(moving,fixed,S,thetad)
    % To find the translation in the most precise way, scale up the
    % lower-resolution image. If the input scale factor is less than 1,
    % swap the inputs, invert the scale factor, and negate the angle. Then,
    % after everything else is done, invert the resulting transformation.
    flip_inputs = S < 1;

    if flip_inputs
        S = 1/S;
        thetad = -thetad;
        [moving,fixed] = swap(moving,fixed);
    end

    % Create two candidate transformations, differing by 180 degrees in the
    % rotation.
    theta1d = thetad;
    theta2d = thetad+180;

    % This can be changed to use simtform2d after the simtform2d inversion
    % code is modified to be more robust.
    %
    % tform1 = simtform2d(S,theta1d,[0 0]);
    % tform2 = simtform2d(S,theta2d,[0 0]);
    %
    tform1 = affinetform2d([S.*cosd(theta1d) -S.*sind(theta1d) 0; S.*sind(theta1d) S.*cosd(theta1d) 0; 0 0 1]);
    tform2 = affinetform2d([S.*cosd(theta2d) -S.*sind(theta2d) 0; S.*sind(theta2d) S.*cosd(theta2d) 0; 0 0 1]);

    % Warp the moving image using both transformations. 
    [scaledRotatedMoving1,RrotatedScaled1] = imwarp(moving,tform1,'SmoothEdges', true);

    % Optimized equivalent to:
    %   [scaledRotatedMoving2,RrotatedScaled2] = imwarp(moving,tform2)
    %
    scaledRotatedMoving2 = rot90(scaledRotatedMoving1,2);
    RrotatedScaled2 = imref2d(size(scaledRotatedMoving1),...
        sort(-RrotatedScaled1.XWorldLimits),...
        sort(-RrotatedScaled1.YWorldLimits));

    % For both warped versions of the moving image, find the best
    % translation. Use the peak NGC value to choose which one to use.
    [tform_translation_1,peak1] = images.registration.internal.findTranslationNGC(scaledRotatedMoving1,fixed);
    [tform_translation_2,peak2] = images.registration.internal.findTranslationNGC(scaledRotatedMoving2,fixed);

    if peak1 >= peak2
        vec = tform_translation_1.Translation;
        tform = tform1;
        RrotatedScaled = RrotatedScaled1;
        peak = peak1;
    else
        vec = tform_translation_2.Translation;
        tform = tform2;
        RrotatedScaled = RrotatedScaled2;
        peak = peak2;
    end

    % The scale/rotation operation performed prior to the final
    % phase-correlation step results in a translation. The translation
    % added during scaling/rotation is defined by RrotatedScaled. Form the
    % final effective translation by summing the translation added during
    % rotation/scale to the translation recovered in the final translation
    % step.
    finalXOffset  = vec(1) + (RrotatedScaled.XIntrinsicLimits(1)-RrotatedScaled.XWorldLimits(1));
    finalYOffset  = vec(2) + (RrotatedScaled.YIntrinsicLimits(1)-RrotatedScaled.YWorldLimits(1));

    tform.A(1:2,3) = [finalXOffset; finalYOffset];

    if flip_inputs
        tform = invert(tform);
    end

    % This step will no longer be necessary after simtform2d inversion is
    % made more robust and the above calls to affinetform2d are replaced by
    % calls to simtform2d.
    tform = simtform2d(tform);

end

function [b,a] = swap(a,b)
end

% Copyright 2023-2024 The MathWorks, Inc.