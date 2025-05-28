function propNames = createControlsList(classInfo, controlSuffix)
% Helper function that determines the names of the properties that
% correspond to controls in the specified tab
%
%   classInfo - Meta class information about a specific class
%   controlSuffix - Suffixes that correspond to controls

%   Copyright 2023 The MathWorks, Inc.

    % Obtain list of class properties
    classProps = string({classInfo.PropertyList.Name})';

    % Pre-allocate the maximum number of controls that can be present
    propNames = strings(numel(classProps), 1);

    startIdx = 1;
    for cnt = 1:numel(controlSuffix)
        % Identify properties with the specific suffix and add it to the
        % property list
        names = classProps(endsWith(classProps, controlSuffix(cnt)));
        propNames(startIdx:startIdx+numel(names)-1) = names;
        startIdx = startIdx + numel(names);
    end

    % Remove extra entries
    propNames(propNames == "") = [];
end