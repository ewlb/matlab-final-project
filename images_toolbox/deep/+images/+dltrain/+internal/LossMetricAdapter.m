classdef LossMetricAdapter < images.dltrain.internal.Metric
    % This class adapts the images.dltrain.internal.Loss object to a metric for
    % use in validation metric computation. The main use case of this object is
    % computation of a LossFcn where the intermediate computation(s) from which
    % the LossFcn derived are themselves metrics of interest. This way we can
    % avoid recomputation of metrics that are used to compute the loss.


    properties
        Function
        Name
        AccumulatedMetrics
        NumObservations
    end

    methods
        function this = LossMetricAdapter(lossObj)
            this.Function = @(varargin) iCallFcn(lossObj,varargin{:});
            this.Name = lossObj.MetricNames;

            this = reset(this);
        end

        function this = update(this,varargin)
            Yexample = varargin{1};
            
            % This code handles special cases (solov2) where the predict output is
            % packages into cell arrays. Here we keep indexing into the
            % cell array till we reach a dlarray.
            if(iscell(Yexample))
                while(iscell(Yexample))
                    Yexample = Yexample{1};
                end
            end

            dim = finddim(Yexample,'B');
            thisBatchSize = size(Yexample,dim);
            this.NumObservations = this.NumObservations + thisBatchSize;
            
            outputs = cell(1,length(this.Name));
            [outputs{:}] = this.Function(varargin{:});

            % For each metric value keep a running weighted accumulation
            this.AccumulatedMetrics = cellfun(@(thisOutput,thisAccum) thisOutput*thisBatchSize+thisAccum,outputs,this.AccumulatedMetrics,UniformOutput=false);
        end

        function varargout = evaluate(this)
            varargout = cellfun(@(c) c./this.NumObservations,this.AccumulatedMetrics,UniformOutput=false);
        end

        function this = reset(this)
            this.AccumulatedMetrics = cell(1,length(this.Name));
            this.AccumulatedMetrics = cellfun(@(c) 0,this.AccumulatedMetrics,UniformOutput=false);
            this.NumObservations = 0;
        end

        function this = aggregate(~,~)
            % Stub for now
        end

    end

end

function varargout = iCallFcn(lossObj,varargin)
metricNames = lossObj.MetricNames;
outputs = cell(1,length(metricNames));
[~,metrics] = lossFcn(lossObj,varargin{:}); % Assume loss itself is included as a metric as desired
for idx = 1:length(metricNames)
    outputs{idx} = metrics.(metricNames(idx));
end
varargout = outputs;
end

