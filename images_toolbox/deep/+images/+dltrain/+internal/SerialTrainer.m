classdef SerialTrainer < handle    
% Network trainer for serial training in dltrain

%   Copyright 2021 The MathWorks, Inc.
    
   properties (SetAccess = private)
       Network
       LossFcn
       IterationCount double
       EpochCount double
       TrainingOptions {isa(TrainingOptions,'nnet.cnn.TrainingOptions')}
       StartTime uint64
   end
   
   properties (Access = private)
       DataQueue minibatchqueue
       Solver
       L2RegularizationFactors
       StopTraining logical = false
       LRScheduler
   end
     
   events
      IterationEnd
      EpochEnd
      TrainingEnd
   end
      
   methods
      
       function self = SerialTrainer(trainQueue,network,lossFcn,options)
           self.DataQueue = copy(trainQueue);
           self.LossFcn = lossFcn;
           self.Network = network;
           self.Solver = images.dltrain.internal.solverFactory(options);
           self.LRScheduler = deep.internal.learnrate.createLearnRateSchedule(options);
           self.TrainingOptions = options;
           self.IterationCount = 0;
           self.EpochCount = 1;
           self.L2RegularizationFactors = images.dltrain.internal.buildL2FactorPerLearnable(network.Layers,network.Learnables,options.L2Regularization);              
       end
       
       function stop(self)
           self.StopTraining = true; 
       end

       function TF = keepTraining(self)
            TF = hasdata(self.DataQueue) && ~self.StopTraining;
       end
       
       function net = fit(self)
           
           import images.dltrain.internal.*
           
           % Always start from begin of queue
           reset(self.DataQueue);
           
           % Honor shuffle once if specified
           if self.TrainingOptions.Shuffle == "once"
               shuffle(self.DataQueue);
           end
           
           batch = cell(1,self.DataQueue.NumOutputs);
           numNetworkInputs = length(self.Network.InputNames);
           numNetworkOutputs = length(self.Network.OutputNames);
           self.IterationCount = 0;
           self.EpochCount = 1;
           
           clipGradientsFun = gradientThresholderFactory(self.TrainingOptions.GradientThresholdMethod,self.TrainingOptions.GradientThreshold);
           l2Regularizer = l2RegularizationFactory(self.TrainingOptions.L2Regularization);
           
           self.StartTime = tic;
           for epoch = 1:self.TrainingOptions.MaxEpochs      
               while keepTraining(self)
                   [batch{:}] = next(self.DataQueue);
                   inputs = batch(1:numNetworkInputs);
                   targets = batch(numNetworkInputs+1:end);
                   [loss,grad,state,networkOutputs,lossData] = dlfeval(@modelGradients,self.Network,self.LossFcn,...
                       numNetworkOutputs,inputs,targets,...
                       self.L2RegularizationFactors,clipGradientsFun, l2Regularizer);
                   
                   self.IterationCount = self.IterationCount + 1;

                   [self.LRScheduler,self.Solver.LearnRate] = deep.internal.learnrate.Utilities.safelyUpdate(self.LRScheduler,...
                       self.TrainingOptions.InitialLearnRate,...
                       self.IterationCount,...
                       self.EpochCount);

                   self.Network = self.Solver.update(self.Network,grad);
                   self.Network.State = state;
                                            
                   finalIteration = (~hasdata(self.DataQueue) && epoch == self.TrainingOptions.MaxEpochs);
                   isValidationIteration = ~isempty(self.TrainingOptions.ValidationData) &&...
                           (~mod(self.IterationCount,self.TrainingOptions.ValidationFrequency) ||...
                           (self.IterationCount == 1) ||...
                           self.StopTraining ||...
                           finalIteration);
                   
                   data = IterationEndEventData(self.IterationCount,...
                       loss,networkOutputs,targets,self.Network,self.EpochCount,...
                       self.TrainingOptions.MaxEpochs,self.StartTime,isValidationIteration,lossData,...
                       self.Solver.LearnRate);
                         
                   notify(self,'IterationEnd',data);
               end

               self.EpochCount = self.EpochCount + 1;
               data.Epoch = self.EpochCount;

               data.IsValidationIteration = false;
               notify(self,'EpochEnd',data);
                     
               reset(self.DataQueue);
               if self.TrainingOptions.Shuffle == "every-epoch"
                   shuffle(self.DataQueue);
               end 
           end
           
           data.IsValidationIteration = true;
           notify(self,'TrainingEnd',data);
           net = self.Network;
       end
   end
end

function [loss,grad,state,networkOutputs,lossData] = modelGradients(net,lossFcn,numNetworkOutputs,inputs,targets,...
    regularizationFactors,clipGradients,l2Regularizer)
% Expects lossFcn of the form: loss =
% lossFcn(Y1,Y2,YN,T1,T2,TN) where Yx are outputs from network and Tx are
% target values.
%
% Order of inputs and outputs is are described by net.InputNames and
% net.OutputNames.

networkOutputs = cell(1,numNetworkOutputs);
[networkOutputs{:},state] = forward(net,inputs{:});

if isa(lossFcn,'images.dltrain.internal.Loss')
    [loss,lossData] = lossFcn.lossFcn(networkOutputs{:},targets{:});
else % a function
    loss = lossFcn(networkOutputs{:},targets{:});
    lossData = struct([]);
end

grad = dlgradient(loss,net.Learnables);

% Apply L2 regularization to gradients
grad = l2Regularizer(grad,net.Learnables,regularizationFactors);

% Apply gradient clipping
grad = clipGradients(grad);

end