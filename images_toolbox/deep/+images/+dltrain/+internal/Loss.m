classdef Loss
    % This class allows users with use cases in which intermediate training metrics of
    % interest are computed during computation of the loss to cache those
    % intermediate quantities so that they can be used by the MetricLogger,
    % avoiding the need for recomputation as an optimization.

    %   Copyright 2021 The MathWorks, Inc.


    methods (Abstract)

        % Compute loss and intermediate metrics
        [loss,metrics] = lossFcn(~,varargin);
        
    end

    properties (Abstract)
        MetricNames
    end

end

