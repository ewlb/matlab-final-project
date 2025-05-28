function lightness = algrgb2lightness(I) %#codegen
%ALGRGB2LIGHTNESS Algorithm to convert RGB color values to lightness.

% Copyright 2018 The MathWorks, Inc.

gamma = 2.4;
a = 1/1.055;
b = 0.055/1.055;
c = 1/12.92;
d = 0.04045;
isCodegen = ~coder.target('MATLAB');
if isCodegen
    % Inverse companding
    linearR = zeros(size(I,1),size(I,2),class(I));
    linearG = zeros(size(I,1),size(I,2),class(I));
    linearB = zeros(size(I,1),size(I,2),class(I));
    for rows = 1:size(I,1)
        for cols = 1:size(I,2)
            [linearR(rows,cols),linearG(rows,cols),linearB(rows,cols)] = ...
                images.color.internal.coder.linearizeSRGB( I(rows,cols,1),...
                I(rows,cols,2), I(rows,cols,3));
        end
    end
    I = cat(3, linearR, linearG, linearB);
else
    I = images.color.parametricCurveA(I, gamma, a, b, c, d);
end
rgb1 = reshape(I, [], size(I,3));

% sRGB to XYZ transformation matrix
% This transformation matrix is computed using images.color.internal.linearRGBToXYZTransform.m
M =  [0.41245643908969226165694976771192,  0.21267285140562255940643865415041, ...
    0.019333895582329303081126070651408; 0.35757607764390891835759589412191, ...
    0.71515215528781783671519178824383,  0.11919202588130294040436041314024;...
    0.18043748326639891255140923931322, 0.072174993306559562245006134162395, ...
    0.95030407853636766901672672247514];
XYZ = rgb1*M;

% Computation of luminance component
Y = XYZ(:,2);

% Computation of lightness component
fY = f(Y);
lightV = 116 * fY - 16;
lightness = reshape(lightV, [size(I,1) size(I,2)]);
end


function out = f(in)
out = zeros(size(in),'like',in);

lin_range = (in <= (6/29)^3);
gamma_range = ~lin_range;

% exp(1/3 * log(x)) is a faster way of computing x.^(1/3).
out(gamma_range) = exp((1/3) * log(in(gamma_range)));
out(lin_range) = ((24389/27) * in(lin_range) + 16)/116;
end