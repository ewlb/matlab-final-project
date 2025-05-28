function varargout = dicomdict(command, varargin)

if (nargout > 1)
    error(message('images:dicomdict:tooManyOutputs'))
end

command = matlab.images.internal.stringToChar(command);
varargin = matlab.images.internal.stringToChar(varargin);

persistent dictionary

if (isempty(dictionary))
    % Prevent clearing the workspace from removing these values.
    dictionary = setup_dictionary;
    mlock
end

switch (lower(command))
case 'factory'
    
    dictionary = setup_dictionary;
    
case 'get'

    varargout{1} = dictionary.stored_dictionary;
    
case 'set'
    
    dictionary.stored_dictionary = validateFilename(varargin{1});
    dictionary.current_dictionary = dictionary.stored_dictionary;
    
case 'get_current'
    
    varargout{1} = dictionary.current_dictionary;
    
case 'reset_current'
    
    dictionary.current_dictionary = dictionary.stored_dictionary;
    
case 'set_current'
    
    dictionary.current_dictionary = validateFilename(varargin{1});
    
otherwise
    
    error(message('images:dicomdict:invalidCommand', command))
    
end



function dictionary = setup_dictionary
%SETUP_DICTIONARY  Reset the dictionary to its factory state.

dictionary.stored_dictionary = validateFilename('dicom-dict.txt');
dictionary.current_dictionary = dictionary.stored_dictionary;



function filenameWithPath = validateFilename(filenameIn)
%VALIDATEFILENAME  Validate the existence of a file and get full pathname.

validateattributes(filenameIn, {'char'}, {'nonempty', 'row'}, mfilename, 'DICTIONARY', 2)

fid = fopen(filenameIn);
if (fid < 0)
    error(message('images:dicomdict:fileNotFound', filenameIn));
end
filenameWithPath = fopen(fid);
fclose(fid);

% Take care of the case where the requested dictionary is in the current
% directory.  This file should use a full path, too.
if isempty(find((filenameWithPath == '/') | ...
                (filenameWithPath == '\'), 1))
    filenameWithPath = fullfile(pwd, filenameWithPath);
end

%   Copyright 1993-2022 The MathWorks, Inc.