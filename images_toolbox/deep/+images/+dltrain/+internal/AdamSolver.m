classdef AdamSolver < handle
   
    % Copyright 2021 The MathWorks, Inc.
    
    properties (Access = private)
        GradDecayFactor
        SquaredGradDecayFactor
        Epsilon        
    end
    
    properties
        LearnRate
    end
    
    % Solver state
    properties (Access = private)
        GradAvg = [];
        SquaredGradAvg = [];
        IterationCount = 0;
    end
    
    methods 
       
        function self = AdamSolver(LearnRate,gradientDecayFactor,squaredGradientDecayFactor,epsilon)
            self.LearnRate = LearnRate;
            self.GradDecayFactor = gradientDecayFactor;
            self.SquaredGradDecayFactor = squaredGradientDecayFactor;
            self.Epsilon = epsilon;
        end
        
        function net = update(self,net,grad)
   
            self.IterationCount = self.IterationCount + 1;
            
            [net,self.GradAvg,self.SquaredGradAvg] = adamupdate(...
                net,grad,self.GradAvg,self.SquaredGradAvg,self.IterationCount,...
                self.LearnRate,self.GradDecayFactor,self.SquaredGradDecayFactor,...
                self.Epsilon);
            
        end
        
    end
    
    
end