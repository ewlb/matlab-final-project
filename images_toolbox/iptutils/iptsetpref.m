function varargout = iptsetpref(prefName, value)

s = settings;

prefName = matlab.images.internal.stringToChar(prefName);


validateattributes(prefName,{'char'},{},mfilename,'PREFNAME')

% Get factory IPT preference settings.
factoryPrefs = iptprefsinfo;
allNames = factoryPrefs(:,1);

validPrefs = [allNames{:}];
preference = validatestring(prefName,validPrefs,mfilename,'PREFNAME');
matchTF = strcmp(preference,validPrefs);

allowedValues = factoryPrefs{matchTF, 2};

if nargin == 1
    if nargout == 0
        % Print possible settings
        defaultValue = factoryPrefs{matchTF, 3};
        if isempty(allowedValues)
            str = getString(message('images:iptsetpref:hasNoFixedValues',preference));
            fprintf('%s\n',str);
        else
            fprintf('[');
            for k = 1:length(allowedValues)
                thisValue = allowedValues{k};
                isDefault = ~isempty(defaultValue) & ...
                    isequal(defaultValue{1}, thisValue);
                if (isDefault)
                    fprintf(' {%s} ', num2str(thisValue));
                else
                    fprintf(' %s ', num2str(thisValue));
                end
                notLast = k ~= length(allowedValues);
                if (notLast)
                    fprintf('|');
                end
            end
            fprintf(']\n');
        end
        
    else
        % Return possible values as cell array.
        varargout{1} = factoryPrefs{matchTF,2};
    end
    
elseif ~isempty(preference)
    % Syntax: IPTSETPREF(PREFNAME,VALUE)
    
    value = matlab.images.internal.stringToChar(value);
    
    if strcmpi(preference,'ImshowInitialMagnification')
        value = images.internal.checkInitialMagnification(value,{'fit'},mfilename,...
            'VALUE',2);
        setInitialMag(s.matlab,'imshow',value);
        
    elseif strcmpi(preference,'ImtoolInitialMagnification')
        value = images.internal.checkInitialMagnification(value,{'fit','adaptive'},...
            mfilename,'VALUE',2);
        setInitialMag(s.images,'imtool',value);
        
    elseif strcmpi(preference,'ImtoolStartWithOverview')
        validateattributes(value, {'logical', 'numeric'}, {'scalar'}, ...
            mfilename, 'VALUE',2);
        value = value ~= 0;
        s.images.imtool.OpenOverview.PersonalValue = value;
        
    elseif strcmpi(preference,'VolumeViewerUseHardware')
        validateattributes(value, {'logical', 'numeric'}, {'scalar'}, ...
            mfilename, 'VALUE',2);
        value = value ~= 0;
        s.images.volumeviewertool.useHardwareOpenGL.PersonalValue = value;
        
    elseif strcmpi(preference,'UseIPPL')
        validateattributes(value, {'logical', 'numeric'}, {'scalar'}, ...
            mfilename, 'VALUE',2);
        
        % Clear MEX-files so that the next time an IPPL MEX-file loads
        % it'll check this preference again.
        clear mex %#ok<CLMEX>
        
        % Some functions cache the Java preference 'UseIPPL' as persistent
        % state to avoid hitting the java preferences in each call. Clear
        % this persistent state if the preference for UseIPPL is changed.
        functionList = images.internal.functionsThatCacheIPPPref();
        clear(functionList{:});
        
        % convert to logical
        value = value ~= 0;
        s.images.UseIPPL.PersonalValue = value;
        
    elseif strcmpi(preference,'ImshowAxesVisible')
        value = validatestring(value,allowedValues,mfilename,'VALUE',2);
        % convert to logical
        value = strcmpi(value,'on');
        s.matlab.imshow.ShowAxes.PersonalValue = value;
        
    elseif strcmpi(preference,'ImshowBorder')
        value = validatestring(value,allowedValues,mfilename,'VALUE',2);
        s.matlab.imshow.BorderStyle.PersonalValue = value;
    end
    
end


function setInitialMag(s,fun,value)
% Helper function to simplify the mixed type preferences

if isnumeric(value)
    s.(fun).InitialMagnificationStyle.PersonalValue = 'numeric';
    s.(fun).InitialMagnification.PersonalValue = value;
else
    s.(fun).InitialMagnificationStyle.PersonalValue = value;
end

%   Copyright 1993-2022 The MathWorks, Inc.
