function TF = useIPPLibrary()

%useIPPL check if IPP is enabled and ready-to-use.

%   Copyright 2014-2021 The MathWorks, Inc.

% Querying the JAVA preference for IPP use is computationally expensive,
% particularly in cases where the function is called in a loop. As a
% performance optimization, store the preference as a persistent state.
% This state is reset whenever iptsetpref('UseIPPL',__) is called.

persistent prefFlag;
needToQueryJavaPreference = isempty(prefFlag);
if needToQueryJavaPreference
    if strcmp(computer, 'MACA64')
        prefFlag = false;
    else
        prefFlag = iptgetpref('UseIPPL');
    end
end

TF = prefFlag;
end
