function [value1, value2] = dicomlookup(varargin)

dictionary = dicomdict('get_current');

% Check input values and call the correct syntax.
narginchk(1,2)

varargin = matlab.images.internal.stringToChar(varargin);

% Lightweight input validation (part 1).
if (isempty(varargin{1}))
  
    error(message('images:dicomlookup:emptyArg1'))
    
end

% Look up the tag or the name.
if (nargin == 1)
  
    if (~ischar(varargin{1}))
      
        error(message('images:dicomlookup:oneInputMustBeChar'))
        
    end
    
    [value1, value2] = images.internal.dicom.lookupActions(varargin{1}, dictionary);
    
elseif (nargin == 2)
  
    % Lightweight input validation (part 2).
    if (isempty(varargin{2}))
      
        error(message('images:dicomlookup:emptyArg2'))
        
    end
  
    % Convert group and element to integers if necessary.
    group   = getValue(varargin{1});
    element = getValue(varargin{2});

    [value1, value2] = images.internal.dicom.lookupActions(group, element, dictionary);

end



function int = getValue(hexOrInt)

% Get a hex or numeric value.
if (isnumeric(hexOrInt))

    int = hexOrInt;

elseif (ischar(hexOrInt))

    if (isValidHex(hexOrInt))
        int = sscanf(hexOrInt, '%x');
    else
        error(message('images:dicomlookup:badHex', hexOrInt));
    end
    
else
  
    error(message('images:dicomlookup:notIntOrHex'))

end    

% Make sure it is a single, valid uint16.
if (numel(int) > 1)
      
    error(message('images:dicomlookup:tooManyElements'))
      
elseif ((int < 0) || (int > intmax('uint16')))
  
    error(message('images:dicomlookup:badValue'))

end



function tf = isValidHex(hexChars)

tf = all(((hexChars >= '0') & (hexChars <= '9')) | ...
         ((hexChars >= 'a') & (hexChars <= 'f')) | ...
         ((hexChars >= 'A') & (hexChars <= 'F')));

%   Copyright 2006-2022 The MathWorks, Inc.