function [A,ref,perm] = manageDlarrayLabels(A,ref,dataFormatNameValue)

dataFormatSpecified = ~isempty(dataFormatNameValue);

bothInputsLabeled = ~isempty(dims(A)) && ~isempty(dims(ref));
if bothInputsLabeled && ~isequal(dims(A),dims(ref))
    error(message('images:psnr:dlarrayFormatMismatch'));
end

if dataFormatSpecified && ~(isempty(dims(A)) && isempty(dims(ref)))
    error(message('images:psnr:dataFormatSpecifiedWithLabeledInputs'));
end

if dataFormatSpecified
    [A,perm] = deep.internal.dlarray.validateDataFormatArg(A, dataFormatNameValue);
    ref = deep.internal.dlarray.validateDataFormatArg(ref, dataFormatNameValue);
else
    perm = 1:ndims(A);
end

% Only support 'SCB' format for now.
unsupportedFormat = any(ismember(A.dims,'TU'));
if unsupportedFormat
   error(message('images:qualitymetric:InvalidDimLabel'));
end

numSpatialDims = numel(finddim(A,'S'));
unsupportedNumDims = ~isempty(A.dims) && ((numSpatialDims < 2) || (numSpatialDims > 3));
if unsupportedNumDims
    error(message('images:ssim:unsupportedDataFormatSpatialDims'));
end