function attr_str = dicom_add_attr(attr_str, group, element, dictionary, specificCharacterSet, varargin)
%DICOM_ADD_ATTR   Add an attribute to a structure of attributes.
%   OUT = DICOM_ADD_ATTR(IN, GROUP, ELEMENT, DICTIONARY, DATA, VR) add
%   the attribute (GROUP,ELEMENT) with DATA and value representation
%   VR to the structure IN.
%
%   OUT = DICOM_ADD_ATTR(IN, GROUP, ELEMENT, DICTIONARY, DATA) add the
%   attribute (GROUP,ELEMENT) with DATA to the structure IN.  The
%   value representation for this attribute is inferred from the data
%   dictionary; if the VR value is not unique, an error will be
%   issued.
%
%   OUT = DICOM_ADD_ATTR(IN, GROUP, ELEMENT, DICTIONARY) add the empty
%   attribute specified by (GROUP, ELEMENT) to IN.  The VR value for
%   the attribute will be picked from the data dictionary.
%
%   See also DICOM_ADD_ITEM.

%   Copyright 1993-2022 The MathWorks, Inc.

       
pos = length(attr_str) + 1;

%
% Group and Element.
%

attr_str(pos).Group = get_group_or_element(group);
attr_str(pos).Element = get_group_or_element(element);


% Get attribute's properties from dictionary.
attr_dict = images.internal.dicom.dicom_dict_lookup(attr_str(pos).Group, ...
                              attr_str(pos).Element, ...
                              dictionary);

if ((isempty(attr_dict)) && (rem(group, 2) == 1))

    % Private data needs certain values to be set.
    if (nargin < 7)
        if (element >= 16 && element <= 255)
            attr_dict(1).VR = 'LO';
        else
            attr_dict(1).VR = 'UN';
        end
    end
    
    attr_dict(1).VM = [0 inf];

end


%
% VR.
%

if (nargin == 7)  
    
    % VR provided.
    attr_str(pos).VR = varargin{2};
    
elseif ((nargin == 6) && ...
        ((iscell(attr_dict.VR)) && (length(attr_dict.VR) > 1)))

    % Data provided, but multiple possible VR values.
    error(message('images:dicom_add_attr:attributeRequiresVRArg', sprintf( '(%04X,%04X)', attr_str( pos ).Group, attr_str( pos ).Element )))
    
else
    
    % Single VR value or empty data.  Use first VR value.
    if (iscell(attr_dict.VR))
        
        attr_str(pos).VR = attr_dict.VR{1};
        
    else
        
        attr_str(pos).VR = attr_dict.VR;
        
    end
    
end


%
% VM
%

attr_str(pos).VM = attr_dict.VM;


%
% Data.
%

% Get data from varargin or create default empty data.
if (nargin > 5)
    data = varargin{1};
else
    data = [];
end


%
% Convert MATLAB data to DICOM's type and style.
%

attr_str(pos).Data = validate_data(data, attr_str(pos), specificCharacterSet);



function data_out = validate_data(data_in, attr_str, specificCharacterSet)
%VALIDATE_DATA   Validate user-provided data and massage to acceptable form.

vr_details = get_vr_details(attr_str.VR);

if (~isempty(data_in))
    
    attr_tag = sprintf('(%04X,%04X)', attr_str.Group, attr_str.Element);
    
    % Check type.
    if (~has_correct_data_type(class(data_in), vr_details.Types_accept))
        error(message('images:dicom_add_attr:attributeHasWrongType', attr_tag))
    end
    
    % Convert data.
    data_out = massage_data(data_in, attr_str);
    
    % Check VM.
    if (~has_correct_vm(data_out, attr_str.VM, vr_details))
        
	warning(message('images:dicom_add_attr:wrongAttribNum', attr_tag));

    end
    
    % Check lengths.
    if (~has_correct_lengths(data_out, vr_details))
        
	warning(message('images:dicom_add_attr:wrongAttribData', attr_tag));
    end
    
    % Validate data, if appropriate.
    if (ischar(data_out))
        
        if (~isempty(find_invalid_chars(data_out, vr_details, specificCharacterSet)))
            warning(message('images:dicom_add_attr:invalidAttribChar', attr_tag));
        end
    end

    % Pad data, if necessary.
    switch (class(data_out))
    case {'uint8', 'int8', 'char'}
        if (rem(numel(data_out), 2) == 1)
            data_out = pad_data(data_out, vr_details);
        end
    end
    
else
    
    data_out = data_in;
    
end



function val = get_group_or_element(in)

if (isempty(in))

    error(message('images:dicom_add_attr:groupElementNotHexOrInt'))
    
elseif (ischar(in))

    val = sscanf(in, '%x');
    
elseif (isnumeric(in))
    
    val = in;
    
else
    
    error(message('images:dicom_add_attr:groupElementNotHexOrInt'))
    
end



function details = get_vr_details(vr_in)
%GET_VR_DETAILS   Get properties of a Value Representation.

persistent vr_hash;
persistent vr_details;

if (isempty(vr_hash))
    
    % Build up the hash table and details structures.
    [vr_hash, vr_details] = build_vr_details;
    
    % Get the details from the new hash.
    details = get_vr_details(vr_in);
    
else
    
    % Find the VR passed in.
    idx = strmatch(vr_in, vr_hash);
    
    if (isempty(idx))
        
        details = [];
        
    else
        
        details = vr_details(idx);
        
    end
    
end



function [vr_hash, vr_details] = build_vr_details
%BUILD_VR_DETAILS   Create a hash table of VR properties.

% Character categories.
ASCII_UPPER     = 65:90;
ASCII_NUMS      = 48:57;
ASCII_LF        = 10;
ASCII_FF        = 12;
ASCII_CR        = 13;
ASCII_ESC       = 27;
DICOM_CTRL      = [ASCII_LF, ASCII_FF, ASCII_CR, ASCII_ESC];
DICOM_NONCTRL   = 32:126;
DICOM_DEFAULT   = [DICOM_CTRL, DICOM_NONCTRL];
DICOM_EXTENDED  = 127:255;
DICOM_ALL       = [DICOM_DEFAULT, DICOM_EXTENDED];

% Datatype categories.
TYPES_SIGNED   = {'int8', 'int16', 'int32'};
TYPES_UNSIGNED = {'uint8', 'uint16', 'uint32'};
TYPES_FLOATING = {'double', 'single'};
TYPES_INTEGRAL = [TYPES_SIGNED, TYPES_UNSIGNED];
TYPES_NUMERIC  = [TYPES_INTEGRAL, TYPES_FLOATING, {'logical'}];

% Hash of VRs.
vr_hash = {'AE'
           'AS'
           'AT'
           'CS'
           'DA'
           'DS'
           'DT'
           'FD'
           'FL'
           'IS'
           'LO'
           'LT'
           'OB'
           'OW'
           'PN'
           'SH'
           'SL'
           'SQ'
           'SS'
           'ST'
           'TM'
           'UI'
           'UL'
           'UN'
           'US'
           'UT'
           'OD'
           'OF'
           'OL'
           'UC'
           'UR'};

% Struct of VR details.

vr_details(1).VR_name         = 'AE';
vr_details(1).Types_accept    = {'char'};
vr_details(1).Types_output    = 'char';
vr_details(1).Size_range      = [0 16];
vr_details(1).Separator       = '\';
vr_details(1).Char_repertoire = DICOM_NONCTRL;

vr_details(2).VR_name         = 'AS';
vr_details(2).Types_accept    = {'char'};
vr_details(2).Types_output    = 'char';
vr_details(2).Size_range      = [0 4];
vr_details(2).Separator       = '\';
vr_details(2).Char_repertoire = [ASCII_NUMS, 'D', 'W', 'M', 'Y'];

vr_details(3).VR_name         = 'AT';
vr_details(3).Types_accept    = TYPES_NUMERIC;
vr_details(3).Types_output    = 'uint16';
vr_details(3).Size_range      = [2 2];
vr_details(3).Separator       = [];
vr_details(3).Char_repertoire = '';

vr_details(4).VR_name         = 'CS';
vr_details(4).Types_accept    = {'char'};
vr_details(4).Types_output    = 'char';
vr_details(4).Size_range      = [0 16];
vr_details(4).Separator       = '\';
vr_details(4).Char_repertoire = [ASCII_UPPER, ASCII_NUMS, ' ', '_'];

vr_details(5).VR_name         = 'DA';
vr_details(5).Types_accept    = {'char', 'double'};
vr_details(5).Types_output    = 'char';
vr_details(5).Size_range      = [8 10];  % 10 ALLOWS FOR PRE 3.0.
vr_details(5).Separator       = '\';
vr_details(5).Char_repertoire = [ASCII_NUMS, '.'];

vr_details(6).VR_name         = 'DS';
vr_details(6).Types_accept    = [{'char'}, TYPES_NUMERIC];
vr_details(6).Types_output    = 'char';
vr_details(6).Size_range      = [0 16];
vr_details(6).Separator       = '\';
vr_details(6).Char_repertoire = [ASCII_NUMS, '+', '-', 'E', 'e', '.', ' '];

vr_details(7).VR_name         = 'DT';
vr_details(7).Types_accept    = {'char', 'double'};
vr_details(7).Types_output    = 'char';
vr_details(7).Size_range      = [0 26];
vr_details(7).Separator       = '\';
vr_details(7).Char_repertoire = [ASCII_NUMS, '+', '-', '.'];

vr_details(8).VR_name         = 'FD';
vr_details(8).Types_accept    = TYPES_NUMERIC;
vr_details(8).Types_output    = 'double';
vr_details(8).Size_range      = [1 1];
vr_details(8).Separator       = [];
vr_details(8).Char_repertoire = '';

vr_details(9).VR_name         = 'FL';
vr_details(9).Types_accept    = TYPES_NUMERIC;
vr_details(9).Types_output    = 'single';
vr_details(9).Size_range      = [1 1];
vr_details(9).Separator       = [];
vr_details(9).Char_repertoire = '';

vr_details(10).VR_name         = 'IS';
vr_details(10).Types_accept    = TYPES_NUMERIC;
vr_details(10).Types_output    = 'char';
vr_details(10).Size_range      = [0 12];
vr_details(10).Separator       = '\';
vr_details(10).Char_repertoire = [ASCII_NUMS, '-', ' '];

vr_details(11).VR_name         = 'LO';
vr_details(11).Types_accept    = {'char'};
vr_details(11).Types_output    = 'char';
vr_details(11).Size_range      = [0 64];
vr_details(11).Separator       = '\';
vr_details(11).Char_repertoire = [DICOM_NONCTRL, DICOM_EXTENDED, ASCII_ESC];

vr_details(12).VR_name         = 'LT';
vr_details(12).Types_accept    = {'char'};
vr_details(12).Types_output    = 'char';
vr_details(12).Size_range      = [0 10240];
vr_details(12).Separator       = '';
vr_details(12).Char_repertoire = DICOM_ALL;

vr_details(13).VR_name         = 'OB';
vr_details(13).Types_accept    = {'uint8', 'int8', 'logical'};
vr_details(13).Types_output    = 'uint8';
vr_details(13).Size_range      = [0 inf];
vr_details(13).Separator       = [];
vr_details(13).Char_repertoire = '';

vr_details(14).VR_name         = 'OW';
vr_details(14).Types_accept    = [TYPES_INTEGRAL, {'logical'}];
vr_details(14).Types_output    = 'uint16';
vr_details(14).Size_range      = [0 inf];
vr_details(14).Separator       = [];
vr_details(14).Char_repertoire = '';

vr_details(15).VR_name         = 'PN';
vr_details(15).Types_accept    = {'char', 'struct', 'uint8'};
vr_details(15).Types_output    = 'char';
vr_details(15).Size_range      = [0 (64 * 3)];  % 64 chars / component group.
vr_details(15).Separator       = '\';
vr_details(15).Char_repertoire = [DICOM_NONCTRL, ASCII_ESC, DICOM_EXTENDED];

vr_details(16).VR_name         = 'SH';
vr_details(16).Types_accept    = {'char'};
vr_details(16).Types_output    = 'char';
vr_details(16).Size_range      = [0 16];
vr_details(16).Separator       = '\';
vr_details(16).Char_repertoire = [DICOM_NONCTRL, ASCII_ESC, DICOM_EXTENDED];

vr_details(17).VR_name         = 'SL';
vr_details(17).Types_accept    = TYPES_NUMERIC;
vr_details(17).Types_output    = 'int32';
vr_details(17).Size_range      = [1 1];
vr_details(17).Separator       = [];
vr_details(17).Char_repertoire = '';

vr_details(18).VR_name         = 'SQ';
vr_details(18).Types_accept    = {'struct'};
vr_details(18).Types_output    = 'struct';
vr_details(18).Size_range      = [1 1];  % All SQ attributes have VM of 1.
vr_details(18).Separator       = [];
vr_details(18).Char_repertoire = '';

vr_details(19).VR_name         = 'SS';
vr_details(19).Types_accept    = TYPES_NUMERIC;
vr_details(19).Types_output    = 'int16';
vr_details(19).Size_range      = [1 1];
vr_details(19).Separator       = [];
vr_details(19).Char_repertoire = '';

vr_details(20).VR_name         = 'ST';
vr_details(20).Types_accept    = {'char'};
vr_details(20).Types_output    = 'char';
vr_details(20).Size_range      = [0 1024];
vr_details(20).Separator       = '';
vr_details(20).Char_repertoire = DICOM_ALL;

% ':' allowed for backward compatibility.
% See note for TM in PS-3.5 Sec. 6.2.0.
vr_details(21).VR_name         = 'TM';
vr_details(21).Types_accept    = {'char', 'double'};
vr_details(21).Types_output    = 'char';
vr_details(21).Size_range      = [0 16];
vr_details(21).Separator       = '\';
vr_details(21).Char_repertoire = [ASCII_NUMS, '.', ' ', ':'];

vr_details(22).VR_name         = 'UI';
vr_details(22).Types_accept    = {'char'};
vr_details(22).Types_output    = 'char';
vr_details(22).Size_range      = [0 64];
vr_details(22).Separator       = '\';
vr_details(22).Char_repertoire = [ASCII_NUMS, '.', 0];

vr_details(23).VR_name         = 'UL';
vr_details(23).Types_accept    = TYPES_NUMERIC;
vr_details(23).Types_output    = 'uint32';
vr_details(23).Size_range      = [1 1];
vr_details(23).Separator       = [];
vr_details(23).Char_repertoire = '';

vr_details(24).VR_name         = 'UN';
vr_details(24).Types_accept    = [TYPES_NUMERIC, {'char'}, {'struct'}];
vr_details(24).Types_output    = 'uint8';  % Don't convert raw data.
vr_details(24).Size_range      = [0 inf];
vr_details(24).Separator       = [];
vr_details(24).Char_repertoire = 0:255;  % Anything is allowed.

vr_details(25).VR_name         = 'US';
vr_details(25).Types_accept    = TYPES_NUMERIC;
vr_details(25).Types_output    = 'uint16';
vr_details(25).Size_range      = [1 1];
vr_details(25).Separator       = [];
vr_details(25).Char_repertoire = '';

vr_details(26).VR_name         = 'UT';
vr_details(26).Types_accept    = {'char'};
vr_details(26).Types_output    = 'char';
vr_details(26).Size_range      = [0 (2^32 - 2)];
vr_details(26).Separator       = '';
vr_details(26).Char_repertoire = DICOM_ALL;

vr_details(27).VR_name         = 'OD';
vr_details(27).Types_accept    = TYPES_NUMERIC;
vr_details(27).Types_output    = 'double';
vr_details(27).Size_range      = [0 inf];
vr_details(27).Separator       = [];
vr_details(27).Char_repertoire = '';

vr_details(28).VR_name         = 'OF';
vr_details(28).Types_accept    = TYPES_NUMERIC;
vr_details(28).Types_output    = 'single';
vr_details(28).Size_range      = [0 inf];
vr_details(28).Separator       = [];
vr_details(28).Char_repertoire = '';

vr_details(29).VR_name         = 'OL';
vr_details(29).Types_accept    = [TYPES_INTEGRAL, {'logical'}];
vr_details(29).Types_output    = 'uint32';
vr_details(29).Size_range      = [0 inf];
vr_details(29).Separator       = [];
vr_details(29).Char_repertoire = '';

vr_details(30).VR_name         = 'UC';
vr_details(30).Types_accept    = {'char'};
vr_details(30).Types_output    = 'char';
vr_details(30).Size_range      = [0 (2^32 - 2)];
vr_details(30).Separator       = '\';
vr_details(30).Char_repertoire = [DICOM_NONCTRL, DICOM_EXTENDED, ASCII_ESC];

vr_details(31).VR_name         = 'UR';
vr_details(31).Types_accept    = {'char'};
vr_details(31).Types_output    = 'char';
vr_details(31).Size_range      = [0 (2^32 - 2)];
vr_details(31).Separator       = '';
vr_details(31).Char_repertoire = [DICOM_NONCTRL, DICOM_EXTENDED];



function tf = has_correct_data_type(datatype, acceptable)
%HAS_CORRECT_DATA_TYPE   Verify that the data is of the right type.

switch (datatype)
case acceptable
    tf = true;
otherwise
    tf = false;
end



function tf = has_correct_vm(data, vm, vr_details)
%HAS_CORRECT_VM   Verify that data has correct number of components.

switch (class(data))
case 'char'

    if (isempty(vr_details.Separator))
        tf = true;
    else
        idx = find(data == vr_details.Separator);
        
        tf = ((length(idx) + 1) >= vm(1)) & ...
             ((length(idx) + 1) <= vm(2));
    end
    
case 'struct'

    tf = true;
    
case {'uint8', 'int8', 'uint16', 'int16', 'uint32', 'int32', ...
      'double', 'single'}
    
    tf = (numel(data) >= vm(1) * vr_details.Size_range(1)) & ...
         (numel(data) <= vm(2) * vr_details.Size_range(2));
    
otherwise
    
    tf = false;
    
end



function data_out = massage_data(data_in, attr_str)
%MASSAGE_DATA   Convert data to its DICOM type.

% We assume that this won't be called on data that can't be converted.
% The function HAS_CORRECT_DATA_TYPE permits this assumption.

switch (attr_str.VR)
case 'AT'
    
    % Attribute tags must be stored as UINT16 pairs.
    data_out = uint16(data_in);
    
    if (numel(data_out) ~= length(data_in))

        if (size(data_out, 2) ~= 2)
            error(message('images:dicom_add_attr:AttributeNeedsPairsOfUint16Data', sprintf( '(%04X,%04X)', attr_str.Group, attr_str.Element )))
            
        end
        
        data_out = data_out';
        
    end
    
    data_out = data_out(:);
    
case 'DA'
    
    % Convert a MATLAB serial date to a string.
    if (isa(data_in, 'double'))
        
        %
	warning(message('images:dicom_add_attr:serialDateToString', sprintf( '(%04X,%04X)', attr_str.Group, attr_str.Element )))
	
        
        tmp = datestr(data_in, 30);  % yyyymmddTHHMMSS
        data_out = tmp(1:8);
        
    else
        
        data_out = data_in;
        
    end
    
case 'DS'
    
    % Convert numeric values to strings.
    if (~ischar(data_in))

        data_out = images.internal.dicom.convertNumericToString(data_in);
        
    else
        
        data_out = data_in;
        
    end
    
case 'DT'
    
    % Convert a MATLAB serial date to a string.
    if (isa(data_in, 'double'))
        

        %
	warning(message('images:dicom_add_attr:serialDateToString', sprintf( '(%04X,%04X)', attr_str.Group, attr_str.Element )))

	
    
        data_out = '';
        
        for p = 1:length(data_in)
            
            tmp_base = datestr(data_in, 30);  % yyyymmddTHHMMSS
            tmp_base(9) = '';
            
            v = datevec(data_in);
            tmp_fraction = sprintf('%0.6f', (v(end) - round(v(end))));
            tmp_fraction(1) = '';  % Remove leading 0.
            
            data_out = [data_out '\' tmp_base tmp_fraction(2:end)]; %#ok<AGROW>
            
        end
        
    else
        
        data_out = data_in;
        
    end
    
case {'FD','OD'}
    
    data_out = double(data_in);
    
case {'FL','OF'}
    
    data_out = single(data_in);
        
case 'IS'
    
    % Convert numeric values to strings.
    if (~ischar(data_in))
        
        data_out = sprintf('%d\\', round(data_in));
        data_out(end) = '';

    else
        
        data_out = data_in;
        
    end

case 'OB'
 
    % Convert logical values to packed UINT8 arrays.
    if (islogical(data_in))

        data_out = images.internal.dicom.packLogical(data_in, 8);
        
    else
        data_out = data_in;
    end
    
case 'OW'
 
    if (islogical(data_in))

        % Convert logical values to packed UINT8 arrays.
        data_out = images.internal.dicom.packLogical(data_in, 16);
        
    elseif (isa(data_in, 'int32') || isa(data_in, 'uint32'))
      
        % 32-bit values need to be swapped as 16-bit short words not
        % 32-bit words (e.g., "1234" byte order on LE should become
        % "2143" on BE machines, and vice versa).
        data_out = images.internal.dicom.typecast(data_in, 'uint16');
        
    else
        data_out = data_in;
    end

case 'OL'

    if (islogical(data_in))

        % Convert logical values to packed UINT8 arrays.
        data_out = images.internal.dicom.packLogical(data_in, 32);
    else
        data_out = data_in;
    end
    
case 'PN'
    
    % Convert person structures to strings.
    if (isstruct(data_in))
        
        data_out = struct_to_pn(data_in);
        
    else
        
        data_out = data_in;
        
    end
    
case 'SL'
    
    data_out = int32(data_in);
    
case 'SS'
    
    data_out = int16(data_in);
    
case 'TM'
    
    % Convert a MATLAB serial date to a string.
    if (isa(data_in, 'double'))
        
        %
	warning(message('images:dicom_add_attr:serialDateToString', sprintf( '(%04X,%04X)', attr_str.Group, attr_str.Element )))

        
        tmp = datestr(data_in, 30);  % yyyymmddTHHMMSS
        data_out = tmp(10:end);
        
    else
        
        data_out = data_in;
    end
    
case 'UL'
    
    data_out = uint32(data_in);
    
case 'UN'

    if (isnumeric(data_in))
        data_out = images.internal.dicom.typecast(data_in, 'uint8');
    else
        data_out = data_in;
    end
    
case 'US'
    
    data_out = uint16(data_in);

case 'UR'
    hasSpace = isspace(data_in);
    if any(hasSpace)
        % Space characters are permitted only as trailing padding in URL. 
        attr_tag = sprintf('(%04X,%04X)', attr_str.Group, attr_str.Element);
        warning(message('images:dicom_add_attr:removeSpace', attr_tag));
        data_in(hasSpace) = '';
    end
    % Assuming the URL contains proper characters. URL encoding and
    % decoding are not supported.
    data_out = data_in;

otherwise
    
    data_out = data_in;
    
end



function pn_string = struct_to_pn(pn_struct)
%STRUCT_TO_PN  Convert a person name in a struct to a character string.

pn_string = '';
    
for p = 1:length(pn_struct)
    
    % Build up the PN string for this value.
    tmp = '';
    
    if (isfield(pn_struct, 'FamilyName'))
        tmp = [tmp, pn_struct.FamilyName, '^']; %#ok<AGROW>
    else
        tmp = [tmp, '^']; %#ok<AGROW>
    end
    
    if (isfield(pn_struct, 'GivenName'))
        tmp = [tmp, pn_struct.GivenName, '^']; %#ok<AGROW>
    else
        tmp = [tmp, '^']; %#ok<AGROW>
    end
    
    if (isfield(pn_struct, 'MiddleName'))
        tmp = [tmp, pn_struct.MiddleName, '^']; %#ok<AGROW>
    else
        tmp = [tmp, '^']; %#ok<AGROW>
    end
    
    if (isfield(pn_struct, 'NamePrefix'))
        tmp = [tmp, pn_struct.NamePrefix, '^']; %#ok<AGROW>
    else
        tmp = [tmp, '^']; %#ok<AGROW>
    end
    
    if (isfield(pn_struct, 'NameSuffix'))
        tmp = [tmp, pn_struct.NameSuffix, '^']; %#ok<AGROW>
    else
        tmp = [tmp, '^']; %#ok<AGROW>
    end
    
    % Remove trailing null components.
    while ((~isempty(tmp)) && (isequal(tmp(end), '^')))
        tmp(end) = '';
    end
    
    % Add this value to the output string.
    pn_string = [pn_string, tmp, '\']; %#ok<AGROW>
    
end

% Remove trailing delimiter ('\').
pn_string(end) = '';



function bad_chars = find_invalid_chars(data, vr_details, specificCharacterSet)
%FIND_INVALID_CHARS   Look for invalid characters

if shouldCheckForInvalidCharacters(specificCharacterSet)
    bad_chars = setdiff(data, [vr_details.Char_repertoire, vr_details.Separator]);
else
    bad_chars = {};
end



function tf = shouldCheckForInvalidCharacters(specificCharacterSet)

% Only check for invalid characters if the default character set is used.

% The specificCharacterSet field will have 0, 1, or 2 cells. If there are
% none, then it uses the default character set. If there are two, then at
% least one of them will require localization. If there is one field, it
% will need localization *unless* it's the default character set (ISO IR
% 100).

if numel(specificCharacterSet) == 2
    tf = false;
elseif isempty(specificCharacterSet)
    tf = true;
elseif isempty(specificCharacterSet{1})
    tf = true;
elseif isequal(specificCharacterSet{1}, 'ISO_IR 100')
    tf = true;
else
    tf = false;
end



function out = pad_data(in, vr_details)
%PAD_DATA   Pad data to an even length

switch (vr_details.VR_name)
case {'AE', 'CS', 'DS' 'DT', 'IS', 'LO', 'LT', 'PN', 'SH', 'ST', 'TM', 'UT', 'UC'}

    out = in;
    out(end + 1) = ' ';
    
case {'OB', 'UI', 'UN'}

    out = in;
    out(end + 1) = 0;
    
otherwise
    
    % If it's numeric, it's even-byte aligned unless its 8-bit.
    if ((isa(in, 'uint8')) || (isa(in, 'int8')))
        
        out = in;
        out(end + 1) = 0;

    else
        
        out = in;
        
    end
    
end



function tf = has_correct_lengths(data, vr_details)
%HAS_CORRECT_LENGTHS  Determine if data components are correctly sized.

if (isempty(vr_details.Separator))
    
    % If there's no separator, then data lengths are unimportant (except
    % for attributes with a VR of "AT", which have two UINT16 components.)
    
    if (isnumeric(data))
        
        if (isequal(vr_details.VR_name, 'AT'))
            
            if (rem(numel(data), 2) == 1)
                tf = 0;
            else
                tf = 1;
            end

        else
            
            tf = 1;
            
        end

    elseif (isstruct(data))
        
        tf = 1;
        
    else
        
        tf = ((numel(data) >= vr_details.Size_range(1)) & ...
              (numel(data) <= vr_details.Size_range(2)));
        
    end
    
else

    % Find the separators.
    idx = find(data == vr_details.Separator);
    component_start = 1;

    tf = 1;
    
    % Test lengths for all but last component.
    for p = 1:length(idx)
        
        component_end = idx(p) - 1;
        
        data_length = component_end - component_start + 1;
        
        tf = tf * ...
             ((data_length >= vr_details.Size_range(1)) & ...
              (data_length <= vr_details.Size_range(2)));
        
        component_start = component_end + 2;
        
    end
    
    % Test length of the last (or only) component.
    data_length = numel(data) - component_start + 1;
    
    tf = tf * ...
         ((data_length >= vr_details.Size_range(1)) & ...
          (data_length <= vr_details.Size_range(2)));
    
end
