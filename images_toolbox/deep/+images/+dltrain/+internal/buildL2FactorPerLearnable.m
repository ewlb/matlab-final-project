function regularizationFactor = buildL2FactorPerLearnable(layers,learnables,globalFactor)

regularizationFactor = learnables;

if(istable(learnables))
    for idx = 1:size(learnables,1)
       localFactor = getL2Factor(layers({layers.Name} == learnables(idx,:).Layer),learnables(idx,:).Parameter);
       regularizationFactor.Value{idx} = localFactor * globalFactor; 
    end

    return;

elseif(isstruct(learnables))
    % If learnables is a struct (which may have fields of varying depths),
    % perform a dfs recursively and use subsref and subsasgn to update the
    % regularizationFactor values.
    regularizationFactor = updateRegFactorStructure(layers,learnables,globalFactor,[], regularizationFactor);

else
    error("UnsupportedFormat");
end

end


function regularizationFactor = updateRegFactorStructure(layers,learnables,globalFactor,structurePath, regularizationFactor )
    % layers, learnables, globalFactor & regularizationFactor have the same
    % meaning as in parent function.
    % structurePath is an array of substruct which builds a path through the
    % fields of the structure until a table is encountered.

    if(isempty(structurePath))
        % handle the first run of the recursive function
        currField = learnables;
    else
        currField = subsref(learnables, structurePath);
    end
    
    % Recursion terminal condition
    if(istable(currField))

        for idx = 1:size(currField,1)
           localFactor = getL2Factor(layers({layers.Name} == currField(idx,:).Layer),currField(idx,:).Parameter);
           %regularizationFactor.Value{idx} = localFactor * globalFactor; 
           assignPath = [structurePath substruct('.', 'Value', '{}', {idx,1})];
           regularizationFactor = subsasgn(regularizationFactor, assignPath, localFactor * globalFactor);
        end

        return;
    end

    fields = fieldnames(currField);

    for i = 1:numel(fields)
        % recurse through all fields at each stage, while building a new
        % structurePath.
        regularizationFactor = updateRegFactorStructure(...
                                        layers,learnables,...
                                        globalFactor,[structurePath substruct('.', fields{i})],...
                                        regularizationFactor );

    end

end