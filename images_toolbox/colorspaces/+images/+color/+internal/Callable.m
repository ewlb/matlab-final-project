% Mixin class to implement the behavior of using () to indicate function
% evaluation.

% Copyright 2014-2020 The MathWorks, Inc.

classdef Callable < matlab.mixin.internal.indexing.Paren & ...
                    matlab.mixin.internal.Scalar
    
    methods (Abstract)
        evaluate(this_callable,varargin)
    end
    
    methods
        function varargout = parenReference(self, varargin)
            [varargout{1:nargout}] = self.evaluate(varargin{:});
        end
    end
end
