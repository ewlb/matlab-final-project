function validateInputDataPropsWideGamut(in, supportedClasses, srcFileName, inputVarName) %#codegen
% Helper function that validates the input data dimensions and class for
% the RGBWIDE2XYZ and XYZ2RGBWIDE functions

%   Copyright 2020, The MathWorks, Inc.

    validateattributes(in, supportedClasses, {});
    
    isYCbCrFunc = coder.const(contains(srcFileName, 'ycbcr'));
    
    % The conversion functions to/from YCbCr do not support image stack
    % inputs.
    if isYCbCrFunc
        maxInputDims = 3;
    else
        maxInputDims = 4;
    end
    
    if numel(size(in)) <= maxInputDims && ... % Ensure that either single image or image stack is permitted
       ( (ismatrix(in) && size(in, 2) == 3) || ... % Color List
          size(in, 3) == 3 ) ... % Three channel image. Can be a stack of them
          
        return;
    end
    
    if isYCbCrFunc
        errorID = coder.const('images:commonColor:InputDimsForRGBYCbCrConv');
    else
        errorID = coder.const('images:commonColor:InputDimsForRGBXYZConv');
    end
    
    % INPUTNAME function is not supported in codegen time.
    if isempty(coder.target())
        inputVarName = inputname(1);
    end
    
    reportedErrorID = coder.const(replace(errorID, 'commonColor', srcFileName));
    coder.internal.errorIf( true, 'CatalogID', errorID, ...
                                'ReportedID', reportedErrorID, inputVarName );
                            