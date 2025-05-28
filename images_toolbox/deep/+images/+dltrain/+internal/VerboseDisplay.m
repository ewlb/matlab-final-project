classdef VerboseDisplay < handle
   % Live display of training progress to command window, similar to 'Verbose' option
   % in trainingOptions.

   % Copyright 2023 The MathWorks, Inc.
   
   properties
       ColumnNames string
       VerboseFrequency
   end
   
   methods
       
       function self = VerboseDisplay(columnNames,verboseFrequency)
            self.ColumnNames = columnNames;
            self.VerboseFrequency = verboseFrequency;
            sz = [1 length(self.ColumnNames)];
            t = table('Size',sz,'VariableNames',self.ColumnNames,'VariableTypes',repmat("double",sz)); %#ok<NASGU>
            s = string(evalc('disp(t)'));
            s = splitlines(s);
            s = string(s(1:3));
            disp(' ');
            disp(s(1));
            disp(s(2));
            disp(s(3));
       end

       function updateDisplay(self,evtData)
           % Display the next row of metrics at the given frequency.
           % evtData is a LogUpdate event.
           isVerboseFrequencyIteration = mod(evtData.MetricsStruct.Iteration,self.VerboseFrequency) == 0;
           isValidationIteration = evtData.IsValidationIteration;
           if isVerboseFrequencyIteration || isValidationIteration
               t = struct2table(evtData.MetricsStruct); %#ok<NASGU>
               s = string(evalc('disp(t)'));
               s = splitlines(s);
               s(strlength(s) == 0) = []; % remove blank lines
               s = replace(s(end),"NaN","   ");
               disp(s);
           end
       end
   end 
end

