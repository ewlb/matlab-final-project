classdef SGDMSolver < handle
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties
        LearnRate
    end
    
    properties (Access = private)
        Velocity = [];
        Momentum
    end
    
    methods 
       
        function self = SGDMSolver(LearnRate,momentum)
            self.LearnRate = LearnRate;
            self.Momentum = momentum;
        end
        
        function net = update(self,net,grad)
                       
            [net,self.Velocity] = sgdmupdate(...
               net,grad,self.Velocity,self.LearnRate,self.Momentum);
            
        end 
    end
end