function mustBeListOfStrings(strList)
% Helper function that validates the input is a vector of strings. A valid
% vector of strings can be:
% 1. Row-vector of characters 
% 2. String vector
% 3. cellstr

%   Copyright 2022, The MathWorks,Inc.

    if isempty(strList)
        return;
    end

    validateattributes(strList,["char","string","cell"],"vector");

    if iscell(strList)
        % Ensure that every element of the cell array is a scalar text
        cellfun(@(x) validateattributes(x,"char","row"),strList);
    end

    if ischar(strList)
        validateattributes(strList,"char","row");
    end

