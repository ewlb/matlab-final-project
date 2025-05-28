classdef RMSPropSolver < handle
    
    properties (Access = private)
        SquaredGradientDecayFactor
        Epsilon
    end
    
    properties
        LearnRate
    end
    
    % Solver state
    properties (Access = private)
        AveragedSquaredGradients = [];
    end
    
    methods
        
        function self = RMSPropSolver(learnRate,squaredGradientDecayFactor,epsilon)
            self.SquaredGradientDecayFactor = squaredGradientDecayFactor;
            self.Epsilon = epsilon;
            self.LearnRate = learnRate;
        end
        
        function net = update(self,net,grad)
            [net,self.AveragedSquaredGradients] = rmspropupdate(...
                net,grad,self.AveragedSquaredGradients,...
                self.LearnRate,self.SquaredGradientDecayFactor,...
                self.Epsilon);
        end
    end
end