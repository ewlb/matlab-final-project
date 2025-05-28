%BlockFunctionException  Capture error information from errors executing block definition functions. 
%   BlockFunctionException methods:
%      throw         - Issue exception and terminate function
%      rethrow       - Reissue existing exception and terminate function
%      throwAsCaller - Issue exception as if from calling function
%      addCause      - Record additional causes of exception
%      getReport     - Get error message for exception
%      last          - Return last uncaught exception
%
%   BlockFunctionException properties:
%      identifier  - Character string that uniquely identifies the error
%      message     - Formatted error message that is displayed
%      cause       - Cell array of MExceptions that caused the error
%      HiddenCause - Underlying wrapped cause, not displayed by getReport
%      stack       - Structure containing stack trace information
%
%   See also try, catch, MException, BigDataException

%   Copyright 2020 The MathWorks, Inc.
classdef BlockFunctionException < MException
    
    methods (Hidden)
        
        function obj = BlockFunctionException()
            errid = 'images:blockedNetwork:badFunctionDef';
            errstr = getString(message(errid));
            obj = obj@MException(errid,errstr);
        end
        
        function str = getReport(obj,varargin)
            str = getString(message('images:blockedNetwork:causeOfError'));
            str = sprintf('%s\n\n%s\n\n%s',...
                obj.message,str,obj.cause{1}.getReport());
            
        end % getReport
        
    end % public methods
    
end