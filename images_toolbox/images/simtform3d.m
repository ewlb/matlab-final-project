%

%#codegen
classdef simtform3d < images.geotrans.internal.simtform3dImpl
    
    methods
        function self = simtform3d(varargin)
            self = self@images.geotrans.internal.simtform3dImpl(varargin{:});
        end
    end

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %      
    methods (Hidden)
        function S = saveobj(self)
            S = struct('Scale',self.Scale,...
                'R',self.R,...
                'Translation',self.Translation,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            if (S.Scale < 0)
                % In earlier versions of simtform3d, the object could be
                % created with a negative scale factor. This was considered
                % to be bug because such a transformation has an inherent
                % orientation-reversing reflection. It was fixed for
                % R2024a. This code handles the situation where a
                % simtform3d object with a negative scale factor was saved
                % to a MAT-file. A valid simtform3d object cannot be
                % constructed, so instead, issue a warning message and
                % return an affinetform3d object. MathWorks engineers: see
                % g3101363.
                warning(message("images:geotrans:loadSimilarity3DNegativeScale"))
                A = [S.Scale * S.R, S.Translation(:) ; 0 0 0 1];
                self = affinetform3d(A);
            else
                self = simtform3d(S.Scale,S.R,S.Translation);
            end
        end
    end    

    methods(Access=public, Static, Hidden)
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.simtform3d';
        end
    end
end

% Copyright 2021-2023 The MathWorks, Inc.
