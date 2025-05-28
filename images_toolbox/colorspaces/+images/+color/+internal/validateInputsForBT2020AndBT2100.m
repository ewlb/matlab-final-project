function options = validateInputsForBT2020AndBT2100(options, fcnName)
% Helper function that validates function inputs for the BT.2020 and
% BT.2100 color conversion functions

%   Copyright 2020, The MathWorks Inc.

    % The TransferFcn N-V pair is supported only for BT.2100 colorspace.
    % If this is supplied for BT.2020, an error must be generated.
    if strcmp(options.ColorSpace, 'BT.2020')
        if isfield(options, 'LinearizationFcn')
            m = message('images:commonColor:LinearizationFcnUnsupportedForBT2020');
            errorID = replace(m.Identifier, 'commonColor', fcnName);
            throw( MException(errorID, getString(m)) );
        end
    end
    
    % For a BT.2100 colorspace, the default TransferFcn is 'PQ'.
    if strcmp(options.ColorSpace, 'BT.2100') && ~isfield(options, 'LinearizationFcn')
        options.LinearizationFcn = 'PQ';
    end
end