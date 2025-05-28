%

%#codegen
classdef affinetform3d < images.geotrans.internal.affinetform3dImpl 
    
    methods
        function self = affinetform3d(varargin)
            self = self@images.geotrans.internal.affinetform3dImpl(varargin{:});
        end                                                        
    end

    %
    % Provide overloads for saveobj and loadobj to protect against future
    % changes to the class definition.
    %    
    methods (Hidden)
        function S = saveobj(self)
            S = struct('A34',self.A34,...
                'MATFormatVersion',1);
        end
    end
    
    methods (Static, Hidden)
        function self = loadobj(S)
            self = affinetform3d(S.A34);
        end
    end   

    methods(Access=public, Static, Hidden)
        function name = matlabCodegenRedirect(~)
            name = 'images.internal.coder.affinetform3d';
        end
    end
end

% Copyright 2021-2022 The MathWorks, Inc.
