function attributeInfo = dicomfind(input, targetAttribute)

arguments
    input {mustBeStructOrDICOM}
    targetAttribute char {mustBeSingleText}
end

if isempty(targetAttribute)
    error(message('images:dicomfind:emptyAttributeInput'))
end

if ischar(input)||isstring(input)
    input = dicominfo(input);
end

% Initialization
attributeInfoCell = {};
dfsCell = [];

% List all the field
fields = fieldnames(input);

% Create a n*3 cell array with: StructName(struct), AttributeName(string),
% Location(string)
for id = numel(fields):-1:1
    thisField = fields{id};
    n = size(dfsCell);
    dfsCell{n(1)+1, 1} = input;
    dfsCell{n(1)+1, 2} = thisField;
    dfsCell{n(1)+1, 3} = thisField;
end

% Iterate through the cell array
while ~isempty(dfsCell)
    n = size(dfsCell);
    parentStruct = dfsCell{n(1), 1};
    thisField = dfsCell{n(1), 2};
    location = dfsCell{n(1), 3};
    dfsCell(n(1),:) = [];
    thisStruct = parentStruct.(thisField);
    
    % If the field name is equal to the target attribute
    if isequal(thisField, targetAttribute)
        n = size(attributeInfoCell);
        attributeInfoCell{n(1)+1, 1} = location; %#ok<*AGROW> 
        attributeInfoCell{n(1)+1, 2} = getfield(parentStruct,thisField); %#ok<GFLD>
    end
    
    % If the field contains another struct
    if isstruct(thisStruct)
        childFields = fieldnames(thisStruct);
        for id = numel(childFields):-1:1
            childField = childFields{id};
            n = size(dfsCell);
            dfsCell{n(1)+1, 1} = thisStruct;
            dfsCell{n(1)+1, 2} = childField;
            dfsCell{n(1)+1, 3} = append(location,'.', childField);
        end
    end
end

if isempty(attributeInfoCell)
    error(message('images:dicomfind:cannotFindAttribute',targetAttribute))
else
    % Location and value of the target attribute in cell format
    location = attributeInfoCell(:,1);
    valueInCell = attributeInfoCell(:,2);
    attributeInfo = table(location, valueInCell,'VariableNames',{'Location','Value'});

end

end


% Custom validatior functions
function mustBeSingleText(targetAttribute)
    if ~isletter(targetAttribute)
        error(message('images:dicomfind:attributeMustBeSingleText'))
    elseif ~isvector(targetAttribute)
        error(message('images:dicomfind:attributeMustBeSingleText'))
    end
end

function mustBeStructOrDICOM(input)
    if ~isstruct(input) && ~ischar(input) && ~isstring(input)
        error(message('images:dicomfind:invalidInputFormat'))
    end
end
% Copyright 2020-2022 The MathWorks, Inc.