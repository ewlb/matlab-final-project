function delE = imcolordiff(I1, I2, NameValueArgs)

arguments
    I1 {mustBeReal, mustBeNonsparse} 
    I2 {mustBeReal, mustBeNonsparse}  
    NameValueArgs.Standard (1,:) {ischar} = "CIE94"    
    NameValueArgs.isInputLab (1,1) {logical, mustBeNonsparse} = false
    
    NameValueArgs.kL (1,1) single {mustBeGreaterThan(NameValueArgs.kL, 0), mustBeNonsparse}= 1
    NameValueArgs.kC (1,1) single {mustBeGreaterThan(NameValueArgs.kC, 0), mustBeNonsparse}= 1
    NameValueArgs.kH (1,1) single {mustBeGreaterThan(NameValueArgs.kH, 0), mustBeNonsparse}= 1
    NameValueArgs.K1 (1,1) single {mustBeGreaterThan(NameValueArgs.K1, 0), mustBeNonsparse}= 0.045
    NameValueArgs.K2 (1,1) single {mustBeGreaterThan(NameValueArgs.K2, 0), mustBeNonsparse}= 0.015
end
%

%% validate the type of Input: L*a*b* or rgb
if NameValueArgs.isInputLab == true
    validateattributes(I2,{'single','double'}, {'finite'})
    validateattributes(I1,{'single','double'}, {'finite'})    
else    
    validateattributes(I2, {'single','double', 'uint8', 'uint16'}, {'finite'})
    validateattributes(I1, {'single','double', 'uint8', 'uint16'}, {'finite'})
end

%% validation for the Standard
Stnd = validatestring(NameValueArgs.Standard, ["CIE94", "CIEDE2000"]);

%% reshaping the mx3 inputs into 3 channel input to suit the workflow
[I1,I2,out_size] = images.color.internal.checkAndReshapeColorArrays(I1,I2);

%% Check for double datatype
if isa(I1, 'double') || isa(I2, 'double')
    I1 = im2double(I1);
    I2 = im2double(I2);
    NameValueArgs.kL = double(NameValueArgs.kL);
    NameValueArgs.kC = double(NameValueArgs.kC);
    NameValueArgs.kH = double(NameValueArgs.kH);
    NameValueArgs.K1 = double(NameValueArgs.K1);
    NameValueArgs.K2 = double(NameValueArgs.K2);
else
    I1 = im2single(I1);
    I2 = im2single(I2);
end

%% RGB to L*a*b* Conversion
if NameValueArgs.isInputLab == 0
    I1 = rgb2lab(I1);
    I2 = rgb2lab(I2);
end

%% Compute Color difference
if Stnd == "CIEDE2000"
    delE = deltaE2000(I1, I2, NameValueArgs.kL, NameValueArgs.kC, ...
        NameValueArgs.kH, NameValueArgs.K1, NameValueArgs.K2);
elseif Stnd == "CIE94"
    delE = deltaE94(I1, I2, NameValueArgs.kL, NameValueArgs.kC, ...
        NameValueArgs.kH, NameValueArgs.K1, NameValueArgs.K2);
end

%% reshape the final answer
delE = reshape(delE,out_size);
end

%% Input Argument Validation function for the two input pairs
function validateInputSize(X)
if size(X,3) == 1
    if size(X,2) ~= 3
        error(message('images:deltaE:invalidInputFormat'));
    end
elseif size(X,3) == 2
    error(message('images:deltaE:invalidInputFormat'));
elseif size(X,3) > 3
    error(message('images:deltaE:invalidInputFormat'));
end
end

%% Function to compute Color difference in CIEDE2000 Standard
function dE = deltaE2000(I1, I2, kL, kC, kH, K1, K2)
    [L1,a1,b1] = labValues(I1);
    [L2,a2,b2] = labValues(I2);

    % Calculate Ci and hi's:
    
    C1 = sqrt(a1.^2 + b1.^2);
    C2 = sqrt(a2.^2 + b2.^2); 
    Cbar = (C1 + C2)./2;
    G = 0.5*(1 - ((sqrt((Cbar.^7)./(Cbar.^7 + 25^7)))));
    a1 = (1+G).*a1;
    a2 = (1+G).*a2;    
    C1d = sqrt(a1.^2 + b1.^2);
    C2d = sqrt(a2.^2 + b2.^2);
    
    % Calculating the Modified hue using the four-quadrant arctangent
    h1 = atan2(b1,a1); h2 = atan2(b2,a2);
    
    %Typically, these functions return an angular value in radians ranging
    %from -pi to pi. This must be converted to a hue angle in degrees between
    %0 and 360 by addition of 2*pi to negative hue angles.    
    h1(h1<0) = (h1(h1<0) + 2*pi);
    h2(h2<0) = (h2(h2<0) + 2*pi);        
    h1((a1 == 0 & b1 == 0)) = 0;
    h2((a2 == 0 & b2 == 0)) = 0;
    
    %% Calculate dL, dC and dH    
    % Here the following equations are laid to calculate the differences in
    % L, C and H values of the colors under consideration.
    dL = (L2 - L1);    
    dC = (C2d - C1d);    
    hsub = h2 - h1;    
    dh = zeros(size(h2));
    dh(C1d.*C2d ~= 0 & abs(hsub)<=pi) = hsub(C1d.*C2d ~= 0 & abs(hsub)<=pi);
    dh(C1d.*C2d ~= 0 & hsub > pi) = hsub(C1d.*C2d ~= 0 & hsub > pi) - 2*pi;
    dh(C1d.*C2d ~= 0 & hsub < -pi) = hsub(C1d.*C2d ~= 0 & hsub < -pi) + 2*pi;
    dh(C1d.*C2d == 0) = 0;    
    dH = 2*sqrt(C1d.*C2d).*sin(dh./2);
    
    %% Calculate CIEDE2000 Color-Difference dE00:    
    Lbar = (L1 + L2)./2;    
    Cdbar = (C1d + C2d)./2;    
    hadd = h1 + h2;    
    hbar = zeros(size(h1)) ;
    hbar(abs(hsub) <= pi & C1d.*C2d ~= 0) = hadd(abs(hsub) <= pi & C1d.*C2d ~= 0)./2;
    hbar(abs(hsub) > pi & hadd < 2*pi & C1d.*C2d ~= 0) = (hadd(abs(hsub) > pi & hadd < 2*pi & C1d.*C2d ~= 0) + 2*pi)./2;
    hbar(abs(hsub) > pi & hadd >= 2*pi & C1d.*C2d ~= 0) = (hadd(abs(hsub) > pi & hadd >= 2*pi & C1d.*C2d ~= 0) - 2*pi)./2;
    hbar(C1d.*C2d == 0) = hadd(C1d.*C2d == 0);        
    T = 1 - 0.17*cos(hbar - deg2rad(30)) + 0.24*cos(2*hbar) + 0.32*cos(3*hbar + deg2rad(6)) - 0.20*cos(4*hbar-deg2rad(63)); % check the format for cos    
    dTheta = deg2rad(30)*exp(-((hbar - deg2rad(275))./deg2rad(25)).^2);    
    RC = 2*sqrt((Cdbar.^7)./(Cdbar.^7 + 25^7));
    
    % Major parameters required to compute CIEDE2000:    
    SL = 1 + ((K2*(Lbar - 50).^2)./(sqrt(20 + (Lbar - 50).^2)));    
    SC = 1 + (K1*Cdbar);    
    SH = 1 + (K2*Cdbar.*T);
    RT = -sin(2*dTheta).*RC;
    
    % CIEDE2000 Final Formula:    
    dE = sqrt((dL./(kL*SL)).^2 + (dC./(kC*SC)).^2 + (dH./(kH*SH)).^2 + (RT.*((dC./(kC*SC)).*(dH./(kH*SH)))));
end

%% Function to compute Color difference in CIE94 Standard
function dE = deltaE94(I1, I2, kL, kC, kH, K1, K2)
    [L1,a1,b1] = labValues(I1);
    [L2,a2,b2] = labValues(I2);

    % Calculating intermediate parameters
    % This includes computing the difference in L, C and H values.
    dL = L1 - L2;
    C1s = sqrt(a1.^2 + b1.^2);
    C2s = sqrt(a2.^2 + b2.^2);
    dCab = C1s - C2s;   
    
    % Calculate the difference in Hue using the a and b channels of L*a*b*
    % space and not the deltaE76 value
    dHab = (a1 - a2).^2 + (b1 - b2).^2 - dCab.^2;  
    SL = 1; SC = 1+(K1).*C1s;
    SH = 1+(K2).*C1s;
    
    % Actual CIE94 Formula
    dE = sqrt((dL./((kL).*SL)).^2 + (dCab./((kC).*SC)).^2 + (dHab)./(kH.*SH).^2);
end

function [L,a,b] = labValues(I)
    % Extract L, a, and b values from the multidimensional input array in a
    % way so that the size of dimensions greater than 3 are preserved. For
    % example, if I is 50x40x3x5x6, then L, a, and b are all 50x40x1x5x6.
    
    out_size = size(I);
    out_size(3) = 1;
    L = reshape(I(:,:,1,:),out_size);
    a = reshape(I(:,:,2,:),out_size);
    b = reshape(I(:,:,3,:),out_size);
end

% Copyright 2020-2022 The MathWorks, Inc.
