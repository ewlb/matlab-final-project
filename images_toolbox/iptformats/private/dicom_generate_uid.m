function uid = dicom_generate_uid(uid_type)
%DICOM_GENERATE_UID  Create a globally unique ID.
%   UID = DICOM_GENERATE_UID(TYPE) creates a unique identifier (UID) of
%   the specified type.  TYPE must be one of the following:
%
%      'instance'      - A UID for any arbitrary DICOM object
%      'ipt_root'      - The root of the Image Processing Toolbox's UID
%      'series'        - A UID for an arbitrary series of DICOM images
%      'study'         - A UID for an arbitrary study of DICOM series
%
%   See also MWGUIDGEN.

%   Copyright 1993-2023 The MathWorks, Inc.

% This is the UID root assigned to us.  It prevents collisions with UID
% generation schemes from other vendors.
ipt_root = '1.3.6.1.4.1.9590.100.1';

switch (uid_type)
case {'ipt_root'}

    uid = ipt_root;

case {'instance', 'series', 'study'}

    switch (lower(computer()))
    case {'pcwin', 'pcwin64', 'glnxa64', 'glnx86', 'maci', 'maci64', 'maca64'}

        tmp_guid = matlab.lang.internal.uuid();
        guid_32bit = sscanf(strrep(tmp_guid, '-', ''), '%08x');
        uid = guid_to_uid(ipt_root, guid_32bit);

    otherwise

        error(message('images:dicom_generate_uid:unsupportedPlatform'))

    end

otherwise

    error(message('images:dicom_generate_uid:inputValue', uid_type));

end



function uid = guid_to_uid(ipt_root, guid_32bit)

% Convert a group of numeric values into a concatenated string.
guid = '';
for p = 1:length(guid_32bit)

    guid = [guid sprintf('%010.0f', double(guid_32bit(p)))];  %#ok<AGROW>

end

% The maximum decimal representation of four concatenated 32-bit values
% is 40 digits long, which is one digit too many for the UID container in
% DICOM (after you add in the UID root).  Shorten it to fit in DICOM's
% length requirements by removing a value from the middle.  (As a result,
% 1 in every 10^39 values will be a duplicate.)
guid(13) = '';

% The DICOM standard requires the digit that follows a dot to be
% nonzero.  Removing the leading zeros does not cause duplication.
guid = remove_leading_zeros(guid);

% Append the GUID to the UID root. The intervening digit is the version
% number of the UID generation scheme.  Increment the version number if
% the rule/mechanism for generating "guid" changes. (The next scheme version
% number should be 5.)
uid = [ipt_root '.4.' guid];



function out = remove_leading_zeros(in)

out = in;
while (out(1) == '0')
    out(1) = '';
end
