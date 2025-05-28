function requiresStatisticsToolbox(myFunction)
% Verify that the Statistics and Machine Learning Toolbox is available.

% Copyright 2018 The MathWorks, Inc.

% check if stats is installed first.
if ~isfolder(toolboxdir('stats'))
    exception = MException(message('images:validate:statsNotInstalled',myFunction));
    throwAsCaller(exception);
end

% check out a license. Request 2nd output to prevent message printing.
[isLicensePresent, ~] = license('checkout','Statistics_Toolbox');

if ~isLicensePresent
    exception = MException(message('images:validate:statsLicenseUnavailable',myFunction));
    throwAsCaller(exception);    
end
