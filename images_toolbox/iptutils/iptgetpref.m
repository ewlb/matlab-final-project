function value = iptgetpref(prefName)

s = settings;

% Get IPT factory preference settings
factoryPrefs = iptprefsinfo;
allNames = factoryPrefs(:,1);
allNames = [allNames{:}];

value = [];
if nargin == 0
    % Display all current preference settings
    for k = 1:length(allNames)
        thisField = allNames{k};
        value.(thisField) = iptgetpref(thisField);
    end
    
else
    % Return specified preferences
    prefName = matlab.images.internal.stringToChar(prefName);
    validateattributes(prefName,{'char'},{},mfilename,'PREFNAME');
    preference = validatestring(prefName,allNames,mfilename,'PREFNAME');
    
    % Handle the mixed-data-type magnification preferences first
    switch (preference)
        case 'ImshowInitialMagnification'
            value = getInitialMag(s.matlab,'imshow');
        case 'ImtoolInitialMagnification'
            value = getInitialMag(s.images,'imtool');
        case 'ImtoolStartWithOverview'
            value = s.images.imtool.OpenOverview.ActiveValue;
        case 'UseIPPL'
            if strcmpi(computer,'maca64')
                % IPP is not supported on maca64.
                value = false;
            else
                value = s.images.UseIPPL.ActiveValue;
            end
        case 'VolumeViewerUseHardware'
            value = s.images.volumeviewertool.useHardwareOpenGL.ActiveValue;
        case 'ImshowAxesVisible'
            if s.matlab.imshow.ShowAxes.ActiveValue
                value = 'on';
            else
                value = 'off';
            end
        case 'ImshowBorder'
            value = s.matlab.imshow.BorderStyle.ActiveValue;
        otherwise
            
    end
end




function mag = getInitialMag(s,fun)
% Helper function to simplify the mixed type preferences

style = s.(fun).InitialMagnificationStyle.ActiveValue;
if strcmp(style,'numeric')
    mag = s.(fun).InitialMagnification.ActiveValue;
else
    mag = style;
end

%   Copyright 1993-2022 The MathWorks, Inc.
