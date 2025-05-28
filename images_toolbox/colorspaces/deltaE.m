function delE = deltaE(I1, I2, NameValueArgs)
arguments
    I1 {mustBeReal, mustBeNonsparse} 
    I2 {mustBeReal, mustBeNonsparse}   
    NameValueArgs.isInputLab (1,1) {logical, mustBeNonsparse} = false  
end
%

%% validate the type of Input: L*a*b* or rgb
% s1 = size(I1); s2 = size(I2);
if NameValueArgs.isInputLab == true
    validateattributes(I2,{'single','double'}, {'finite'})
    validateattributes(I1,{'single','double'}, {'finite'})    
else    
    validateattributes(I2, {'single','double', 'uint8', 'uint16'}, {'finite'})
    validateattributes(I1, {'single','double', 'uint8', 'uint16'}, {'finite'})
end

%% reshaping the mx3 inputs into 3 channel input to suit the workflow
[I1,I2,out_size] = images.color.internal.checkAndReshapeColorArrays(I1,I2);

%% Check for double datatype
if isa(I1, 'double') || isa(I2, 'double')
    I1 = im2double(I1);
    I2 = im2double(I2);    
else
    I1 = im2single(I1);
    I2 = im2single(I2);
end

%% RGB to L*a*b* Conversion
if NameValueArgs.isInputLab == 0
    I1 = rgb2lab(I1);
    I2 = rgb2lab(I2);
end
delE = sqrt(sum((I1-I2).^2, 3));

%% reshape the final answer
delE = reshape(delE,out_size);
end

% Copyright 2020-2022 The MathWorks, Inc.

