classdef CheckpointSaver
    
    %   Copyright 2021 The MathWorks, Inc.

   properties
       CheckpointPath
       CheckpointFrequency
       CheckpointFrequencyUnit
   end
    
   methods
       
       function self = CheckpointSaver(chkPath,frequency,unit)
           self.CheckpointPath = chkPath;
           self.CheckpointFrequency = frequency;
           self.CheckpointFrequencyUnit = unit;
       end
       
       function saveCheckpoint(self, net, evt)
           timeStep = currentTimestep(self,evt);
           if ~mod(timeStep,self.CheckpointFrequency)
               name = iGenerateCheckpointName(evt.Iteration);
               fullPath = fullfile(self.CheckpointPath, name);
               iSaveNetwork(fullPath, net);
           end
       end

       function step = currentTimestep(self,evt)
            if self.CheckpointFrequencyUnit == "epoch"
                step = evt.Epoch;
            elseif self.CheckpointFrequencyUnit == "iteration"
                step = evt.Iteration;
            else
                assert(false,"Unexpected CheckpointFrequencyUnit.")
            end
       end
   end
end

function iSaveNetwork(fullPath, network)
try
    iSave(fullPath, 'net', network);
catch e
    warning('Checkpoint failed to save.');
end
end

function iSave(fullPath, name, value) 
S.(name) = value; 
save(fullPath, '-struct', 'S', name);
end

function name = iGenerateCheckpointName(iteration)
timestamp = string(datetime('now', 'Format', 'yyyy_MM_dd__HH_mm_ss'));
name = "net_checkpoint__" + iteration + "__" + timestamp + ".mat";
end