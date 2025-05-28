function wp = canonicalizeDegreeAngle(w)    %#codegen
    % canonicalizeDegreeAngle(w) returns degree angles that have been
    % modified to be within the half-open interval [-180,180). Also, any
    % angles that extremely close to integer values are replaced by those
    % integer values.

    coder.inline('always');
    coder.internal.prefer_const(w);

    
    wp = w;
    wp = mod(wp + 180,360) - 180;

    wpr = round(wp);
    close_enough = images.geotrans.internal.nearlyEqual(wp,wpr);
    wp(close_enough) = wpr(close_enough);
end

% Copyright 2021-2022 The MathWorks, Inc.