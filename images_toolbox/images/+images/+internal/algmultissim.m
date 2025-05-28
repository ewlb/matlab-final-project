function [score,qualityMap] = algmultissim(I,Iref,...
    gaussFilter,lowpassFilter,C,numScales,scaleWeights,useHalide,numSpatialDims)
% Main algorithm used by the multissim and multissim3 functions. 

% No input validation is done in this function.
% I                - Grayscale image or 3D volume
% Iref             - Grayscale image or 3D volume
% gaussFilter      - Function handle for 2D or 3D Gaussian filter or gaussian kernel if useHalide = true
% lowpassFilter    - Function handle for 2D or 3D lowpass filter or empty if useHalide = true
% C                - Vector of nonnegative real numbers
% numScales        - Nonnegative integer
% scaleWeights     - Array of nonnegative real numbers
% useHalide        - Boolean
% numSpatialDims   - Positive integer specifying the number of spatial dims in the input

% Copyright 2019-2023 The MathWorks, Inc.

sizeI = size(I);

if ndims(I) <= numSpatialDims
    % Single "image" syntax
    msssimval = zeros(1,numScales,'like',I);
else
    % Batched syntax
    msssimval = zeros([prod(size(I,numSpatialDims+1:ndims(I))),numScales],'like',I);
    newShape = [sizeI(1:numSpatialDims),prod(sizeI(numSpatialDims+1:end))];
    I = reshape(I,newShape);
    Iref = reshape(Iref,newShape);
end

qualityMap = cell(1,numScales);
mode = '';

% Get the score per scale for all scales except the last one. For these
% scales, the score is calculated from the contrast and structural
% comparison measures
for i = 1:numScales-1
    if useHalide
        [ssimmap,I,Iref] = images.internal.builtins.multissim_halide(I,Iref,...
            gaussFilter,C,mode);
    else
        [ssimmap,I,Iref] = computeSSIM(I,Iref,gaussFilter,lowpassFilter,...
            C,false,numSpatialDims);
    end
    
    % Clamp values of ssimmap to 1
    ssimmap(ssimmap > 1) = 1;
    % Calculate ssimval using the corresponding scale weight
    ssimval = clampedExponent(mean(ssimmap,1:numSpatialDims),scaleWeights(i));
    qualityMap{i} = ssimmap;
    msssimval(:,i) = ssimval;
end

% Calculate the score for the smallest scale. For this scale, the score is
% calculated using luminance, contrast and structural comparison measure
if useHalide
    mode = 'Lum'; % Include luminance in the calculation
    [ssimmap,~,~] = images.internal.builtins.multissim_halide(I,Iref,gaussFilter,C,mode);
else
    ssimmap = computeSSIM(I,Iref,gaussFilter,lowpassFilter,C,true,numSpatialDims);
end

% Clamp values of ssimmap to 1
ssimmap(ssimmap > 1) = 1;
% Calculate ssimval using the corresponding scale weight
ssimval = clampedExponent(mean(ssimmap,1:numSpatialDims),scaleWeights(numScales));
qualityMap{numScales} = ssimmap;
msssimval(:,numScales) = ssimval;

% Equation (7) in [1], vectorized to account for batch behavior
score = prod(msssimval,2);

% If batched syntax, reshape the score and map to match the input size
if length(sizeI) > numSpatialDims
    newShape = [ones(1,numSpatialDims),sizeI(numSpatialDims+1:end)];
    score = reshape(score,newShape);
    % No need to reshape map output unless this output has actually been requested
    if nargout > 1
        for scale = 1:numScales
            newQualityMapShape = [size(qualityMap{scale},1:numSpatialDims),sizeI(numSpatialDims+1:end)];
            qualityMap{scale} = reshape(qualityMap{scale},newQualityMapShape);
        end
    end
end
end


function [ssimmap,I,Iref] = computeSSIM(I,Iref,...
    gaussFilterFcn,lowpassFilter,C,includeLuminance,numSpatialDims)

% Mean of I and Iref
mux2 = gaussFilterFcn(I);
muy2 = gaussFilterFcn(Iref);

% Mean squared
muxy = mux2.*muy2;
mux2 = mux2.^2;
muy2 = muy2.^2;

% Variance of I and Iref. Guard against floating point math resulting in
% -eps.
sigmax2 = max(gaussFilterFcn(I.^2) - mux2,0);
sigmay2 = max(gaussFilterFcn(Iref.^2) - muy2,0);

% Covariance of I and Iref
sigmaxy = gaussFilterFcn(I.*Iref) - muxy;

% Simplification of equation (6) in [1] without luminance
num2 = 2 * sigmaxy + C(2);
den2 = sigmax2 + sigmay2 + C(2);

if (includeLuminance)
    % Include luminance component of equation (6) in [1]
    num1 = 2*muxy + C(1);
    den1 = mux2 + muy2 + C(1);
    ssimmap = (num1.*num2) ./ (den1.*den2);
else
    ssimmap = num2./den2;
    % Filter and downsample the images for the next scale
    I = lowpassFilter(I);
    Iref = lowpassFilter(Iref);    
    
    I = downsampleSpatialDims(I,numSpatialDims);
    Iref = downsampleSpatialDims(Iref,numSpatialDims);
end

end

function out = downsampleSpatialDims(in,numSpatialDims)

if numSpatialDims == 2
    out = in(1:2:end,1:2:end,:);
elseif numSpatialDims == 3
    out = in(1:2:end,1:2:end,1:2:end,:);
else
    assert(false,"Unexpected number of spatial dimensions");
end

end

function out = clampedExponent(base, exponent)
if exponent~=floor(exponent)
    % Raising a negative value to a non integer exponent results in
    % undesirable complex values.
    % Note: exponent is always >0, and is usually <1.

    % The following commented code returns NaNs in the backward pass for
    % certain inputs likely due to the discontinuity of the derivative at 0
    % (see g2931235).
    base(base<0) = 0;
end
out = base.^exponent;
end