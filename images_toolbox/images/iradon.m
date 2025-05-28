function [img,H] = iradon(varargin)

narginchk(2,6);

args = matlab.images.internal.stringToChar(varargin);

[p,theta,filter,d,interp,N] = images.internal.iradon.parseInputs(args{:});

% Determine if single precision computation has to be enabled. Cast the
% inputs p and theta accordingly.
[p, theta, useSingleForComp, isMixedInputs] = images.internal.iradon.postProcessInputs(p, theta);

% Design the filter used to filter the projections
[p,H] = images.internal.iradon.filterProjections(p, filter, d, useSingleForComp, isMixedInputs);

% Define the x & y axes for the reconstructed image so that the origin
% (center) is in the spot which RADON would choose.
center = floor((N + 1)/2);
xleft = -center + 1;
x = (1:N) - 1 + xleft;

ytop = center - 1;
y = (N:-1:1).' - N + ytop;

len = size(p,1);
ctrIdx = ceil(len/2);     % index of the center of the projections

% Zero pad the projections to size 1+2*ceil(N/sqrt(2)) if this
% quantity is greater than the length of the projections
imgDiag = 2*ceil(N/sqrt(2))+1;  % largest distance through image.
if size(p,1) < imgDiag
    rz = imgDiag - size(p,1);  % how many rows of zeros
    p = [zeros(ceil(rz/2),size(p,2)); p; zeros(floor(rz/2),size(p,2))];
    ctrIdx = ctrIdx+ceil(rz/2);
end

interpStr = images.internal.iradon.convertEnumsToInterpModes(interp);

% Backprojection - vectorized in (x,y), looping over theta
if (interp == images.internal.iradon.InterpModes.Linear) || ...
   (interp == images.internal.iradon.InterpModes.Nearest) 
    % Converting to a linear buffer to enable linear indexing in the halide
    % code
    p = reshape(p, numel(p), []);

    % Theta expected to be NumThetax1
    theta = reshape(theta, numel(theta), []);

    % Coordinates are expected to have dimensions NumCoordsx1
    x = reshape(x, numel(x), []);
    y = reshape(y, numel(y), []);

    img = images.internal.builtins.iradon_halide(p, theta, x, y, N, interpStr);
else
    % The builtin-code performs the math in double precision. Use this code
    % path to ensure all computatations are done in single precision.
    %'spline','pchip','cubic','v5cubic'
    interp_method = sprintf('*%s',interpStr); % Add asterisk to assert
    % even-spacing of taxis

    % Generate trigonometric tables
    costheta = cos(theta);
    sintheta = sin(theta);

    % Allocate memory for the image
    img = zeros(N,'like',p);

    for i=1:length(theta)
        proj = p(:,i);
        taxis = (1:size(p,1)) - ctrIdx;
        t = x.*costheta(i) + y.*sintheta(i);
        projContrib = interp1(taxis,proj,t(:),interp_method);
        img = img + reshape(projContrib,N,N);
    end

end

img = img*pi/(2*length(theta));

end

%   Copyright 1993-2022 The MathWorks, Inc.
