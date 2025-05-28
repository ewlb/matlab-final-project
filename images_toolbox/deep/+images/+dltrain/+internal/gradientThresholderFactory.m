function fun = gradientThresholderFactory(method,threshold)
% Return a function which takes input gradients and returns clipped
% gradients according to GradientThreshold and GradientThresholdMethod.
%   gradOut = fun(gradIn);

%   Copyright 2021 The MathWorks, Inc.

% Optimization: If there is no gradient thresholding, then just the
% identity function.
if (threshold == inf)
    fun = @(gradients) gradients;
    return
end

if method == "l2norm"
    fun = @(gradients) dlupdate(@(g) thresholdL2Norm(g,threshold),gradients);
elseif method == "absolute-value"
    fun = @(gradients) dlupdate(@(g) thresholdAbsoluteValue(g,threshold),gradients);
elseif method == "global-l2norm"
    fun = @(gradients) thresholdGlobalL2Norm(gradients, threshold);
else
    assert(false,'Unexpected GradientThresholdMethod');
end
end

function gradients = thresholdL2Norm(gradients,gradientThreshold)
gradientNorm = sqrt(sum(gradients(:).^2));
if gradientNorm > gradientThreshold
    gradients = gradients * (gradientThreshold / gradientNorm);
end
end

function gradients = thresholdAbsoluteValue(gradients,gradientThreshold)
gradients(gradients > gradientThreshold) = gradientThreshold;
gradients(gradients < -gradientThreshold) = -gradientThreshold;
end 

function gradients = thresholdGlobalL2Norm(gradients,gradientThreshold)
globalL2Norm = 0;
for i = 1:numel(gradients)
    globalL2Norm = globalL2Norm + sum(gradients{i}(:).^2);
end
globalL2Norm = sqrt(globalL2Norm);

if globalL2Norm > gradientThreshold
    normScale = gradientThreshold / globalL2Norm;
    for i = 1:numel(gradients)
        gradients{i} = gradients{i} * normScale;
    end
end
end