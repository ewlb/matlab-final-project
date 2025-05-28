function [peaksnr, snr] = psnr(A, ref, peakval,NameValueArgs)
%PSNR Peak Signal-To-Noise Ratio.
%   PEAKSNR = PSNR(A, REF) calculates the peak signal-to-noise ratio for
%   the image in array A, with the image in array REF as the reference. A
%   and REF can be N-D arrays, and must be of the same size and class.
% 
%   PEAKSNR = PSNR(A, REF, PEAKVAL) uses PEAKVAL as the peak signal value
%   for calculating the peak signal-to-noise ratio.
% 
%   [PEAKSNR, SNR] = PSNR(A, REF, __) also returns the simple
%   signal-to-noise in SNR, in addition to the peak signal-to-noise ratio.
%
%   [___] = PSNR(___,Name,Value) accepts name value pairs to control aspects
%   of computation. Supported options include:
%
%       'DataFormat'            Dimension labels of the input data A and REF
%                               specified as a string scalar or character
%                               vector. The format options 'S','C', and 'B' 
%                               are supported. The options 'S', 'C' and 'B' 
%                               correspond to spatial, channel, and batch 
%                               dimensions, respectively. For data with a 
%                               batch or 'B' dimension, the output PEAKSNR 
%                               and SNR will contain a separate result for 
%                               each index along the batch dimension.
%                               As an example, input RGB data with two
%                               spatial dimensions and one channel
%                               dimension would have a 'SSC' DataFormat.
%                               Default: All input dimensions in A treated as
%                               spatial dimensions.
%  
%   Notes
%   -----
%   1. When input contains a batch dimension, psnr yields a separate result
%   for each element along the batch dimension.
%
%   Class Support
%   -------------
%   Input arrays A and REF must be dlarray. Both A and REF must be of the same
%   class. They must be nonsparse. PEAKVAL is a scalar of any numeric
%   class. PEAKSNR and SNR are scalars of class double, unless A and REF
%   are of class single in which case PEAKSNR and SNR are scalars of class
%   single.
%
%   Example
%   ---------
%  % This example shows how to compute PSNR for noisy image given the
%  % original reference image.
% 
%   ref = im2single(imread('pout.tif'));
%   A = imnoise(ref,'salt & pepper', 0.02);
%   
%   [peaksnr, snr] = psnr(dlarray(A), ref);
%
%   See also dlarray, IMMSE, MEAN, MEDIAN, SSIM, SUM, VAR

%   Copyright 2020-2021 The MathWorks, Inc. 

arguments
    A dlarray {mustHaveValidUnderlyingData,mustBeNonsparse,mustBeReal}
    ref dlarray {mustHaveValidUnderlyingData,mustBeNonsparse,mustBeReal}
    peakval double = diff(getrangefromclass(A))
    NameValueArgs.DataFormat char
end

bothInputsLabeled = ~isempty(dims(A)) && ~isempty(dims(ref));
if bothInputsLabeled && ~isequal(dims(A),dims(ref))
    error(message('images:psnr:dlarrayFormatMismatch'));
end

dataFormatSpecified = isfield(NameValueArgs,'DataFormat');

if dataFormatSpecified && ~(isempty(dims(A)) && isempty(dims(ref)))
    error(message('images:psnr:dataFormatSpecifiedWithLabeledInputs'));
end

if dataFormatSpecified
    [A,perm] = deep.internal.dlarray.validateDataFormatArg(A, NameValueArgs.DataFormat);
    ref = deep.internal.dlarray.validateDataFormatArg(ref, NameValueArgs.DataFormat);
else
    perm = 1:ndims(A);
end

% Only support 'SCB' format in PSNR for now.
unsupportedFormat = any(ismember(A.dims,'TU'));
if unsupportedFormat
   error(message('images:qualitymetric:InvalidDimLabel'));
end

hasBatchDim = any(A.dims == 'B');

logFcn = @(x) log(x)./log(10); % Workaround lack of log10 in dlarray.

A = deep.internal.sdk.dlarray.errorOnComplexGradientInputs(A, 'psnr');
ref = deep.internal.sdk.dlarray.errorOnComplexGradientInputs(ref, 'psnr');

if nargout < 2
    peaksnr = images.internal.qualitymetric.psnralgo(A, ref, peakval,hasBatchDim,logFcn);
else
    [peaksnr,snr] = images.internal.qualitymetric.psnralgo(A, ref, peakval,hasBatchDim,logFcn);
    snr = deep.internal.sdk.dlarray.errorOnComplexGradientOutputs(snr, 'psnr');
end

peaksnr = deep.internal.sdk.dlarray.errorOnComplexGradientOutputs(peaksnr, 'psnr');

% Remove dimensions from the dlarray if it was passed as unformatted.
if dataFormatSpecified
    peaksnr = ipermute(stripdims(peaksnr),perm);
    if nargout > 1
        snr = ipermute(stripdims(snr),perm);
    end
end

end

function mustHaveValidUnderlyingData(x)
    supportedUnderlyingType = any(underlyingType(x) == ["single","double"]);
    if ~supportedUnderlyingType
       error(message('images:psnr:unsupportedUnderlyingDataType')) 
    end
end
