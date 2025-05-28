function requiresNeuralNetworkToolbox(myFunction)
% Verify that the Deep Learning Toolbox is available.

% Copyright 2017-2018 The MathWorks, Inc.

% check if nnet is installed first.
if ~isfolder(toolboxdir('nnet'))
    exception = MException(message('images:validate:nnetNotInstalled',myFunction));
    throwAsCaller(exception);
end

% check out a license. Request 2nd output to prevent message printing.
[isLicensePresent, ~] = license('checkout','Neural_Network_Toolbox');

if ~isLicensePresent
    exception = MException(message('images:validate:nnetLicenseUnavailable',myFunction));
    throwAsCaller(exception);    
end
