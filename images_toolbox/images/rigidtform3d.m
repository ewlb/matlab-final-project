%

%#codegen
classdef rigidtform3d < images.geotrans.internal.rigidtform3dImpl
 
    methods
        function self = rigidtform3d(varargin)
            self = self@images.geotrans.internal.rigidtform3dImpl(varargin{:});
        end                                                 
    end

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %      
    methods (Hidden)
        function S = saveobj(self)
            S = struct('R',self.R,...
                'Translation',self.Translation,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            self = rigidtform3d(S.R,S.Translation);
        end
    end   

    methods(Access=public, Static, Hidden)
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.rigidtform3d';
        end
    end
end

% Copyright 2021-2022 The MathWorks, Inc.