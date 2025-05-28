function fun = l2RegularizationFactory(l2GlobalFactor)
% Return a function which takes the l2 global regularization factor and
% returns an appropriate function which performs l2Regularization:

%   gradOut = fun(gradIn);

%   Copyright 2021 The MathWorks, Inc.

if l2GlobalFactor
    regFun = @(g,w,l2Factor) g + l2Factor*w;
    fun = @(grad, learnables, regularizationFactors) dlupdate(regFun,grad, learnables, regularizationFactors);
else % Optimization when global L2 regularization is zero
    fun = @(grad,learnables, regularizationFactors) grad;
end

end