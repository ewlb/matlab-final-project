classdef IterationEndEventData < event.EventData
    % EventData passed by IterationEnd events of trainers
    
    % Copyright 2021 The MathWorks, Inc.
    
   properties
      Iteration
      Loss
      NetworkOutputs
      Targets
      Network
      Epoch
      MaxEpochs
      StartTime
      IsValidationIteration
      LossData
      LearnRate
   end
   
   methods
       function data = IterationEndEventData(iter,loss,networkOut,targets,...
               network,epoch,maxEpochs,startTime,isValidationItr,lossData,learnRate)
           
         data.Iteration = iter;
         data.Loss = loss;
         data.NetworkOutputs = networkOut;
         data.Targets = targets;
         data.Network = network;
         data.Epoch = epoch;
         data.MaxEpochs = maxEpochs;
         data.StartTime = startTime;
         data.IsValidationIteration = isValidationItr;
         data.LossData = lossData;
         data.LearnRate = learnRate;
      end
   end
end