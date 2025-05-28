classdef ValidationTimeInferable
        % Copyright 2023, The MathWorks, Inc.

    methods (Abstract)
        varargout = predictForValidation(varargin);
        N = numOutputsPredictForValidation(self);  % The number of outputs that predictForValidation will output for initialization
    end
end