classdef Rotate < handle
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    events
        
        ImageRotated
        
    end
    
    
    properties (Hidden, Transient)
        
        Current (1,1) double = 1;
        
    end
    
    
    properties (Access = protected, Constant)
        
        DecisionTree (8,4) double = [7 5 2 4; 6 8 3 1; 5 7 4 2; 8 6 1 3; 3 1 6 8; 2 4 7 5; 1 3 8 6; 4 2 5 7];
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Apply Forward
        %------------------------------------------------------------------
        function img = applyForward(self,img)

            % There are eight possible orientations
            switch self.Current
                case 1
                    % Image in the original orientation
                    %  ____________
                    % |            |
                    % |    @@@     |
                    % |    @@@@    |
                    % |    @@      |
                    % |    @       |
                    % |____________|
                    
                    % No-op
                    
                case 2
                    % Image rotated 90 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |    @@      |
                    % |   @@@@     |
                    % |   @@@@@@   |
                    % |            |
                    % |____________|
                    
                    img = rot90(img,1);
                    
                case 3
                    % Image rotated 180 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |       @    |
                    % |      @@    |
                    % |    @@@@    |
                    % |     @@@    |
                    % |____________|
                    
                    img = rot90(img,2);
                    
                case 4
                    % Image rotated 270 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |   @@@@@@   |
                    % |     @@@@   |
                    % |      @@    |
                    % |            |
                    % |____________|
                    
                    img = rot90(img,3);
                    
                case 5
                    % Image flipped horizontally from the original orientation
                    %  ____________
                    % |            |
                    % |     @@@    |
                    % |    @@@@    |
                    % |      @@    |
                    % |       @    |
                    % |____________|
                    
                    img = fliplr(img);
                    
                case 6
                    % Image flipped horizontally and rotated 90 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |   @@@@@@   |
                    % |   @@@@     |
                    % |    @@      |
                    % |            |
                    % |____________|
                    
                    img = permute(img,[2,1,3]);
                    
                case 7
                    % Image flipped horizontally and rotated 180 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |    @       |
                    % |    @@      |
                    % |    @@@@    |
                    % |    @@@     |
                    % |____________|
                    
                    img = flipud(img);
                    
                case 8
                    % Image flipped horizontally and rotated 270 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |      @@    |
                    % |     @@@@   |
                    % |   @@@@@@   |
                    % |            |
                    % |____________|
                    img = fliplr(rot90(img,1));
                    
            end
            
        end
        
        %------------------------------------------------------------------
        % Apply Backward
        %------------------------------------------------------------------
        function img = applyBackward(self,img)

            % There are eight possible orientations
            switch self.Current
                case 1
                    % Image in the original orientation
                    %  ____________
                    % |            |
                    % |    @@@     |
                    % |    @@@@    |
                    % |    @@      |
                    % |    @       |
                    % |____________|
                    
                    % No-op
                    
                case 2
                    % Image rotated 90 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |    @@      |
                    % |   @@@@     |
                    % |   @@@@@@   |
                    % |            |
                    % |____________|
                    
                    img = rot90(img,-1);
                    
                case 3
                    % Image rotated 180 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |       @    |
                    % |      @@    |
                    % |    @@@@    |
                    % |     @@@    |
                    % |____________|
                    
                    img = rot90(img,-2);
                    
                case 4
                    % Image rotated 270 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |   @@@@@@   |
                    % |     @@@@   |
                    % |      @@    |
                    % |            |
                    % |____________|
                    
                    img = rot90(img,-3);
                    
                case 5
                    % Image flipped horizontally from the original orientation
                    %  ____________
                    % |            |
                    % |     @@@    |
                    % |    @@@@    |
                    % |      @@    |
                    % |       @    |
                    % |____________|
                    
                    img = fliplr(img);
                    
                case 6
                    % Image flipped horizontally and rotated 90 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |   @@@@@@   |
                    % |   @@@@     |
                    % |    @@      |
                    % |            |
                    % |____________|
                    
                    img = permute(img,[2,1,3]);
                    
                case 7
                    % Image flipped horizontally and rotated 180 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |    @       |
                    % |    @@      |
                    % |    @@@@    |
                    % |    @@@     |
                    % |____________|
                    
                    img = flipud(img);
                    
                case 8
                    % Image flipped horizontally and rotated 270 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |      @@    |
                    % |     @@@@   |
                    % |   @@@@@@   |
                    % |            |
                    % |____________|
                    img = rot90(fliplr(img),-1);
                    
            end
            
        end

        %------------------------------------------------------------------
        % Apply Image Size Forward
        %------------------------------------------------------------------
        function sz = applyImageSizeForward(self,sz)
            % Apply rotation to image size to determine what the size of
            % the rotated image would be. This does not rotate the image,
            % but is a fast way to determine what the rotated size would
            % be.

            switch self.Current
                case {1, 3, 5, 7}
                    % Image in the original orientation, or flipped in a
                    % way that maintains the image size.
                    
                    % No-op
                    
                case {2, 4, 6, 8}
                    % Image rotated in a way that flips the image size.
                    % Swap the first and second values. Keep the third
                    % value if there.
                    sz([1,2]) = sz([2,1]);
                    
            end
            
        end
        
        %------------------------------------------------------------------
        % Apply Backward
        %------------------------------------------------------------------
        function offset = applyOffsetBackward(self,offset)

            % There are eight possible orientations
            switch self.Current
                case 1
                    % Image in the original orientation
                    %  ____________
                    % |            |
                    % |    @@@     |
                    % |    @@@@    |
                    % |    @@      |
                    % |    @       |
                    % |____________|
                    
                    % No-op
                    
                case 2
                    % Image rotated 90 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |    @@      |
                    % |   @@@@     |
                    % |   @@@@@@   |
                    % |            |
                    % |____________|
                    
                    offset = [-offset(2) offset(1)];
                    
                case 3
                    % Image rotated 180 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |       @    |
                    % |      @@    |
                    % |    @@@@    |
                    % |     @@@    |
                    % |____________|
                    
                    offset = -offset;
                    
                case 4
                    % Image rotated 270 degrees from the original orientation
                    %  ____________
                    % |            |
                    % |   @@@@@@   |
                    % |     @@@@   |
                    % |      @@    |
                    % |            |
                    % |____________|
                    
                    offset = [offset(2) -offset(1)];
                    
                case 5
                    % Image flipped horizontally from the original orientation
                    %  ____________
                    % |            |
                    % |     @@@    |
                    % |    @@@@    |
                    % |      @@    |
                    % |       @    |
                    % |____________|
                    
                    offset(1) = -offset(1);
                    
                case 6
                    % Image flipped horizontally and rotated 90 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |   @@@@@@   |
                    % |   @@@@     |
                    % |    @@      |
                    % |            |
                    % |____________|
                    
                    offset = [offset(2) offset(1)];
                    
                case 7
                    % Image flipped horizontally and rotated 180 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |    @       |
                    % |    @@      |
                    % |    @@@@    |
                    % |    @@@     |
                    % |____________|
                    
                    offset(2) = -offset(2);
                    
                case 8
                    % Image flipped horizontally and rotated 270 degrees 
                    % from the original orientation
                    %  ____________
                    % |            |
                    % |      @@    |
                    % |     @@@@   |
                    % |   @@@@@@   |
                    % |            |
                    % |____________|
                    offset = [-offset(2) -offset(1)];
                    
            end
            
        end
        
        %------------------------------------------------------------------
        % Resize
        %------------------------------------------------------------------
        function rotate(self,val)
                        
            switch val
                case 'ud'
                    idx = 1;
                case 'lr'
                    idx = 2;
                case 'ccw'
                    idx = 3;
                case 'cw'
                    idx = 4;
                case 'reset'
                    reset(self);
                    return;
                otherwise
                    return;
                    
            end
            
            currentState = self.Current;
            
            % The decision tree maps the current state and the requested
            % operation into the final new state. This is done to avoid
            % appending multiple redundant calls when a user flips and
            % rotates the image with an arbitrary number of gestures.
            self.Current = self.DecisionTree(currentState,idx);
            
            notify(self,'ImageRotated');
            
        end
        
        %------------------------------------------------------------------
        % Reset
        %------------------------------------------------------------------
        function reset(self)
            
            clear(self);
            notify(self,'ImageRotated');
            
        end
        
        %------------------------------------------------------------------
        % Clear
        %------------------------------------------------------------------
        function clear(self)
            
            self.Current = 1;
            
        end
        
    end
    
end