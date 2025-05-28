function outStruct = dicomupdate(varargin)

    narginchk(2,3);

    options = parseInputs(varargin{:});

    if (nargin == 2)
        outStruct = updateStructureAttributeInfo(options.S,options.A); 
    elseif (nargin == 3)
        outStruct = updateStructure(options.S, options.A, varargin{3});
    end
  
end

function options = parseInputs(varargin)

    % Check if the inputs have valid data type
    validateattributes(varargin{1},{'struct'},{'nonempty'}); 


    parser = inputParser();
    options = parser.Results;
    options.S = varargin{1};
    options.A = varargin{2};

    if (nargin == 2)

        validateattributes(options.A,{'table'},{'nonempty','ncols',2});

    elseif (nargin == 3)

        validateattributes(options.A,{'string','char'},{'nonempty'});
        validateattributes(varargin{3},{'struct','string','char','numeric'},{'nonempty'});
    end

end



% If input includes the output from 'dicomfind' or if the input is a table
function out = updateStructureAttributeInfo(in, inputTable)
    out = in;
    for i = 1:height(inputTable)
        % separate the field names
        levels = split(inputTable{i,1},'.');
        % calculate how many levels
        sizeLevels = size(levels); 
        % reassign values
        if iscell(inputTable{i,2})
            out = setfield(out,levels{1:sizeLevels(1)},inputTable{i,2}{1}); 
        else
            out = setfield(out,levels{1:sizeLevels(1)},inputTable{i,2});
        end      
    end
end

% If the input includes new value and target attribute
function out = updateStructure(in, targetAttribute, newValue)
    outTable = dicomfind(in,targetAttribute);
    numOutput = height(outTable);
    for i = 1:numOutput
        outTable.Value(i) = {newValue};
    end
    out = updateStructureAttributeInfo (in, outTable);
end

% Copyright 2020-2022 The MathWorks, Inc.