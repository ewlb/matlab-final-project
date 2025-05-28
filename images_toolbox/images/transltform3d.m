%

%#codegen
classdef transltform3d < images.geotrans.internal.transltform3dImpl
 
    methods
        function self = transltform3d(varargin)
            self = self@images.geotrans.internal.transltform3dImpl(varargin{:});
        end  
    end

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %      
    methods (Hidden)
        function S = saveobj(self)
            S = struct('Translation',self.Translation,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            self = transltform3d(S.Translation);
        end
    end   

    methods(Access=public, Static, Hidden)
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.transltform3d';
        end
    end
end

% Copyright 2021-2022 The MathWorks, Inc.