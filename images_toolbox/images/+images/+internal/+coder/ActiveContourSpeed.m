%ActiveContourSpeed Speed function for active contour evolution.
% 
%   See also ActiveContourEvolver, ActiveContourSpeedChanVese, ActiveContourSpeedEdgeBased

% Copyright 2023 The MathWorks, Inc.

%#codegen

classdef ActiveContourSpeed
% Purely abstract class for now.     
       
    % Required Methods 
    % ---------------- 
    methods (Abstract = true)
       
        speed = calculateSpeed(obj, I, phi, pixIdx)
                            
    end  % End of required methods   
 
    
    % Optional Methods 
    % ----------------         
    % These methods need not be implemented by inheriting classes. Classes
    % that do not override these methods will inherit the default NO-OP
    % implementations.
    methods
        
        function obj = initalizeSpeed(obj, ~, ~) 
            
        end
        
        function obj = updateSpeed(obj, ~, ~, ~) 
            
        end
        
    end % End of optional methods
    
end