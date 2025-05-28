function varargout = dicomwrite(X, varargin)

if (nargin < 2)
    error(message('images:dicomwrite:tooFewInputs'))
elseif (nargout > 1)
    error(message('images:dicomwrite:tooManyOutputs'))
end

varargin = matlab.images.internal.stringToChar(varargin);

checkDataDimensions(X);
[filename, map, metadata, options] = parse_inputs(varargin{:});
checkOptionConsistency(options, metadata);

%
% Register SOP classes, dictionary, etc.
%

dicomdict('set_current', options.dictionary);
dictionary = dicomdict('get_current');

%
% Write the DICOM file.
%

try
    
    [status, options] = write_message(X, filename, map, metadata, options);

    if (nargout == 1)
        varargout{1} = status;
    end
    
catch ME
    
    dicomdict('reset_current');
    rethrow(ME)
    
end

dicomdict('reset_current');

% If (0028,0008) is set, it's pair (0028,0009) must also be set.
% Warn if it isn't, since we can't make up a value for it.
if (isfield(metadata, dicom_name_lookup('0028', '0008', dictionary)) && ...
    ~isfield(metadata, dicom_name_lookup('0028', '0009', dictionary)) && ...
    requires00280009(options, metadata, dictionary))
  
    warning(message('images:dicomwrite:missingFrameIncrementPointer', dicom_name_lookup( '0028', '0009', dictionary ), dicom_name_lookup( '0028', '0008', dictionary )))
    
end



function varargout = write_message(X, filename, map, metadata, options)
%WRITE_MESSAGES  Write the DICOM message.

%
% Abstract syntax negotiation.
% (SOP class and transfer syntax)
%

if (isequal(options.createmode, 'create'))
    SOP_UID = determine_IOD(options, metadata, X);
    options.sopclassuid = SOP_UID;
else
    SOP_UID = '';
end

options.txfr = determine_txfr_syntax(options, metadata);

checkArgConsistency(options, SOP_UID, X);

specificCharacterSet = images.internal.dicom.dicom_get_SpecificCharacterSet(metadata, options.dictionary);

%
% Construct, encode, and write SOP instance.
%

if (~isequal(options.createmode, 'create') && ...
    ~isequal(options.createmode, 'copy'))
  
    error(message('images:dicomwrite:badCreateMode'));
  
end

if (options.multiframesinglefile)
  
    % All frames will go into one file.
    if (isequal(options.createmode, 'create'))

        [attrs, status] = dicom_create_IOD(SOP_UID, X, map, ...
                                           metadata, options, specificCharacterSet);
        
    else
        
        [attrs, status] = dicom_copy_IOD(X, map, ...
                                         metadata, options, specificCharacterSet);
        
    end
    
    encodeAndWriteAttrs(attrs, options, filename, specificCharacterSet);
    
else

    % Each file will contain only one frame.
    num_frames = size(X, 4);
    for p = 1:num_frames
      
        % Construct the SOP instance's IOD.
        if (isequal(options.createmode, 'create'))
        
            [attrs, status] = dicom_create_IOD(SOP_UID, X(:,:,:,p), map, ...
                                                    metadata, options, specificCharacterSet);
        
        else
        
            [attrs, status] = dicom_copy_IOD(X(:,:,:,p), map, ...
                                                  metadata, options, specificCharacterSet);
        
        end
    
        encodeAndWriteAttrs(attrs, options, get_filename(filename, p, num_frames), specificCharacterSet);
    
    end
    
end

varargout{1} = status;
varargout{2} = options;



function encodeAndWriteAttrs(attrs, options, filename, specificCharacterSet)
%encodeAndWriteAttrs   Convert attributes to DICOM representation and write them.
    
attrs = sort_attrs(attrs);
attrs = remove_duplicates(attrs);

% Encode the attributes.
data_stream = images.internal.dicom.dicom_encode_attrs(attrs, options.txfr, images.internal.dicom.dicom_uid_decode(options.txfr), specificCharacterSet);

% Write the SOP instance.
destination = filename;
msg = write_stream(destination, data_stream);
if (~isempty(msg))
    %msg is already translated at source.
    error(message('images:dicomwrite:streamWritingError', msg));
end



function [filename, map, metadata, options] = parse_inputs(varargin)
%PARSE_INPUTS   Obtain filename, colormap, and metadata values from input.

metadata = struct([]);
options.writeprivate = false;  % Don't write private data by default.
options.createmode = 'create';  % Create/verify data by default.
options.dictionary = dicomdict('get_current');
options.multiframesinglefile = true;  % Put multiframe images into one file
options.usemetadatabitdepths = false;  % Compute bit depths based on datatype

[filename, map, currentArg] = getFilenameAndColormap(varargin{:});

% Process metadata.
%
% Structures containing multiple values can occur anywhere in the
% metadata information as long as they don't split a parameter-value
% pair.  Any number of structures can appear.

while (currentArg <= nargin)

    if (ischar(varargin{currentArg}))
        
        % Parameter-value pair.
        
        if (currentArg ~= nargin)  % Make sure it's part of a pair.

            [metadata, options] = processPair(metadata, options, ...
                                      varargin{currentArg:(currentArg + 1)});
            
        else

            error(message('images:dicomwrite:missingValue', varargin{ currentArg }))
            
        end
        
        currentArg = currentArg + 2;
        
    elseif (isstruct(varargin{currentArg}))
        
        % Structure of parameters and values.

        str = varargin{currentArg};
        fields = fieldnames(str);
        
        for p = 1:numel(fields)
            
            [metadata, options] = processPair(metadata, options, ...
                                              fields{p}, str.(fields{p}));
        end
        
        currentArg = currentArg + 1;
        
    else
        
        error(message('images:dicomwrite:expectedFilenameOrColormapOrMetadata'))
        
    end

end

% make sure options.createmode is lower case.
options.createmode = lower(options.createmode);

validateattributes(options.usemetadatabitdepths, ["logical", "numeric"], "scalar")
validateattributes(options.multiframesinglefile, ["logical", "numeric"], "scalar")
validateattributes(options.writeprivate, ["logical", "numeric"], "scalar")




function SOP_UID = determine_IOD(options, metadata, X)
%DETERMINE_IOD   Pick the DICOM information object to create.
  
if (options.multiframesinglefile)
  nFrames = size(X,4);
  nSamples = size(X,3);
  needsFix = false;
else
  nFrames = 1;
  nSamples = size(X,3);
  needsFix = true;
end

if (isfield(options, 'objecttype'))
  
    switch (lower(options.objecttype))
    case 'ct image storage'
      
        SOP_UID = '1.2.840.10008.5.1.4.1.1.2';

    case 'mr image storage'
      
        SOP_UID = determineMRStorage(nFrames, options.multiframesinglefile);
     
    case 'secondary capture image storage'

        SOP_UID = determineSCStorage(nFrames, nSamples, X);
        
    otherwise
        
        error(message('images:dicomwrite:unsupportedObjectType', num2str( options.objecttype )))
     
    end
    
elseif (isfield(options, 'sopclassuid'))

    if (ischar(options.sopclassuid))
      
        SOP_UID = options.sopclassuid;
        
    else
      
        error(message('images:dicomwrite:InvalidSOPClassUID'))
        
    end
    
    if (needsFix)
        SOP_UID = fixForMultiFile(SOP_UID);
    end
    
elseif (isfield(metadata, 'SOPClassUID'))

    if (ischar(options.SOPClassUID))
      
        SOP_UID = options.SOPClassUID;
        
    else
      
        error(message('images:dicomwrite:InvalidSOPClassUID'))
        
    end
    
    if (needsFix)
        SOP_UID = fixForMultiFile(SOP_UID);
    end
  
elseif ((isfield(metadata, 'Modality')) && (isequal(metadata.Modality, 'CT')))
      
    SOP_UID = '1.2.840.10008.5.1.4.1.1.2';
    
elseif ((isfield(metadata, 'Modality')) && (isequal(metadata.Modality, 'MR')))
      
    SOP_UID = '1.2.840.10008.5.1.4.1.1.4';
    
else
  
    % Create SC Storage objects by default.
    SOP_UID = determineSCStorage(nFrames, nSamples, X);
    
end




function txfr = determine_txfr_syntax(options, metadata)
%DETERMINE_TXFR_SYNTAX   Find the transfer syntax from user-provided options.
%
% The rules for determining transfer syntax are followed in this order:
%
% (1) Use the command line option 'TransferSyntax'.
%
% (2) Use the command line option 'CompressionMode'.
%
% (3) Use a combination of the command line options 'VR' and 'Endian'.
%
% (4) Use the metadata's 'TransferSyntaxUID' field.
%
% (5) Use the default implicit VR, little-endian transfer syntax.


% Rule (1): 'TransferSyntax' option.
if (isfield(options, 'transfersyntax'))

    txfrStruct = images.internal.dicom.dicom_uid_decode(options.transfersyntax);
    
    if (~isempty(txfrStruct) && ...
        isequal(txfrStruct.Type, 'Transfer Syntax'))
      
        txfr = options.transfersyntax;
        
    else
      
        error(message('images:dicomwrite:unsupportedTransferSyntax', num2str( options.transfersyntax )))
        
    end
    
    return
    
end

% Rule (2): 'CompressionMode' option.
if (isfield(options, 'compressionmode'))
    
    switch (lower(options.compressionmode))
    case 'none'
        
        % Pick transfer syntax below.
        
    case 'rle'
        
        txfr = '1.2.840.10008.1.2.5';
        return
    
    case 'jpeg lossless'
        
        txfr = '1.2.840.10008.1.2.4.70';
        return
        
    case 'jpeg lossy'

        txfr = '1.2.840.10008.1.2.4.50';
        return
    
    case 'jpeg2000 lossless'
        
        txfr = '1.2.840.10008.1.2.4.90';
        return
        
    case 'jpeg2000 lossy'

        txfr = '1.2.840.10008.1.2.4.91';
        return
    
    otherwise
        
        error(message('images:dicomwrite:unrecognizedCompressionMode', num2str( options.compressionmode )));
        
    end
    
end

% Handle rules (3), (4), and (5) together.
if ((isfield(options, 'vr')) || (isfield(options, 'endian')))
    
    override_txfr = true;
    
else
    
    override_txfr = false;
    
end

if (~isfield(options, 'vr'))
    options(1).vr = 'implicit';
end

    
if (~isfield(options, 'endian'))
    options(1).endian = 'ieee-le';
end
        
switch (options.vr)
case 'explicit'
    
    switch (lower(options.endian))
    case 'ieee-be'
        txfr = '1.2.840.10008.1.2.2';
    case 'ieee-le'
        txfr = '1.2.840.10008.1.2.1';
    otherwise
        error(message('images:dicomwrite:invalidEndianValue'));
    end
    
case 'implicit'
    
    switch (lower(options.endian))
    case 'ieee-be'
        error(message('images:dicomwrite:invalidVREndianCombination'))
    case 'ieee-le'
        txfr = '1.2.840.10008.1.2';
    otherwise
        error(message('images:dicomwrite:invalidEndianValue'));
    end

otherwise

    error(message('images:dicomwrite:invalidVRValue'))
    
end

if (override_txfr)
    
    % Rule (3): 'VR' and/or 'Endian' options provided.
    return
    
else
    
    if (isfield(metadata, 'TransferSyntaxUID'))
        
        % Rule (4): 'TransferSyntaxUID' metadata field.
        txfr = metadata.TransferSyntaxUID;
        return
        
    else
        
        % Rule (5): Default transfer syntax.
        return
        
    end
    
end



function out = sort_attrs(in)
%SORT_ATTRS   Sort the attributes by group and element.

attr_pairs = [[in(:).Group]', [in(:).Element]'];
[~, idx_elt] = sort(attr_pairs(:, 2));
[~, idx_grp] = sort(attr_pairs(idx_elt, 1));

out = in(idx_elt(idx_grp));



function out = remove_duplicates(in)
%REMOVE_DUPLICATES   Remove duplicate attributes.
  
attr_pairs = [[in(:).Group]', [in(:).Element]'];
delta = sum(abs(diff(attr_pairs, 1)), 2);

out = [in(1), in(find(delta ~= 0) + 1)];



function status = write_stream(destination, data_stream)
%WRITE_STREAM   Write an encoded data stream to the output device.

% NOTE: Currently local only.
file = images.internal.dicom.dicom_create_file_struct;
file.Filename = destination;
    
file = images.internal.dicom.dicom_open_msg(file, 'w');
    
[file, status] = images.internal.dicom.dicom_write_stream(file, data_stream);

images.internal.dicom.dicom_close_msg(file);



function filename = get_filename(file_base, frame_number, max_frame)
%GET_FILENAME   Create the filename for this frame.

if (max_frame == 1)
    filename = file_base;
    return
end

% Create the file number.
num_length = ceil(log10(max_frame + 1));
format_string = sprintf('%%0%dd', num_length);
number_string = sprintf(format_string, frame_number);

% Look for an extension.
idx = max(strfind(file_base, '.'));

if (~isempty(idx))
    
    base = file_base(1:(idx - 1));
    ext  = file_base(idx:end);  % Includes '.'
    
else
    
    base = file_base;
    ext  = '';
    
end

% Put it all together.
filename = sprintf('%s_%s%s', base, number_string, ext);



function [filename, map, currentArg] = getFilenameAndColormap(varargin)
% Filename and colormap.
if (ischar(varargin{1}))
    
    filename = varargin{1};
    map = [];
    currentArg = 2;
    
elseif (isnumeric(varargin{1}))
    
    map = varargin{1};
    
    if ((nargin > 1) && (ischar(varargin{2})))
        filename = varargin{2};
    else
        error(message('images:dicomwrite:filenameMustBeString'))
    end
    
    currentArg = 3;
    
else
    
    % varargin{1} is second argument to DICOMWRITE.
    error(message('images:dicomwrite:expectedFilenameOrColormap'))
    
end



function [metadata, options] = processPair(metadata, options, param, value)

dicomwrite_fields = {'colorspace'
                     'vr'
                     'endian'
                     'compressionmode'
                     'transfersyntax'
                     'objecttype'
                     'sopclassuid'
                     'dictionary'
                     'writeprivate'
                     'createmode'
                     'multiframesinglefile'
                     'usemetadatabitdepths'};

%idx = strmatch(lower(param), dicomwrite_fields);
idx = find(strncmpi(param, dicomwrite_fields, numel(param)));
            
if (numel(idx) > 1)
    error(message('images:dicomwrite:ambiguousParameter', param));
end
            
if (~isempty(idx))
  
    % It's a DICOMWRITE option.
    options(1).(dicomwrite_fields{idx}) = value;
  
    if (isequal(dicomwrite_fields{idx}, 'transfersyntax'))
      
        % Store TransferSyntax in both options and metadata.
        metadata(1).TransferSyntax = value;
                    
    end
    
else
  
    % It's a DICOM metadata attribute.
    metadata(1).(param) = value;
    
end
            


function checkDataDimensions(data)

% How many bytes does each element occupy in the file?  This assumes
% pixels span the datatype.
switch (class(data))
case {'uint8', 'int8', 'logical'}

    elementSize = 1;
    
case {'uint16', 'int16', 'double'}

    elementSize = 2;
    
case {'uint32', 'int32'}

    elementSize = 4;
    
otherwise

    % Let a later function error about unsupported datatype.
    elementSize = 1;
    
end

% Validate that the dataset/image will fit within 32-bit offsets.
max32 = double(intmax('uint32'));

if (any(size(data) > max32))
    
    error(message('images:dicomwrite:sideTooLong'))
    
elseif ((numel(data) * elementSize) > max32)
    
    error(message('images:dicomwrite:tooMuchData'))
    
end



function uid = determineSCStorage(nFrames, nSamples, X)

if (nFrames == 1)
  
    % Single frame.
    uid = '1.2.840.10008.5.1.4.1.1.7';
    
elseif (nSamples == 3)
  
    % RGB.
    uid = '1.2.840.10008.5.1.4.1.1.7.4';
    
else
  
    % Grayscale.
    switch (class(X))
    case 'logical'
        uid = '1.2.840.10008.5.1.4.1.1.7.1';
    case {'uint8', 'int8'}
        uid = '1.2.840.10008.5.1.4.1.1.7.2';
    case {'uint16', 'int16'}
        uid = '1.2.840.10008.5.1.4.1.1.7.3';
    otherwise
        error(message('images:dicomwrite:badSCBitDepth'))
    end
    
end


function uid = determineMRStorage(nFrames, singleFile)

% Only Single-frame is currently supported from scratch
if (nFrames > 1) && (singleFile)
    uid = '1.2.840.10008.5.1.4.1.1.4.1';
else
    uid = '1.2.840.10008.5.1.4.1.1.4';
end


function checkArgConsistency(options, SOPClassUID, X)

if (isequal(options.createmode, 'create') && ...
    options.multiframesinglefile && ...
    (size(X,4) > 1) && ...
    ~isSC(SOPClassUID))
  
    error(message('images:dicomwrite:multiFrameCreateMode'))

end


function tf = isSC(UID)

scUID = '1.2.840.10008.5.1.4.1.1.7';
tf = strncmp(UID, scUID, length(scUID));



function tf = requires00280009(options, metadata, dictionary)

% See PS 3.3 A.1.1 for IODs that require the Multi-Frame module.

if (isequal(options.createmode, 'create') && isfield(options, 'sopclassuid'))
    
    UID = options.sopclassuid;
    
elseif (isfield(metadata, dicom_name_lookup('0002','0002', dictionary)))

    UID = metadata.(dicom_name_lookup('0002','0002', dictionary));
  
elseif (isfield(metadata, dicom_name_lookup('0008','0016', dictionary)))

    UID = metadata.(dicom_name_lookup('0008','0016', dictionary));
  
else
  
    UID = '';
  
end


switch (UID)
case {'1.2.840.10008.5.1.4.1.1.3.1'
      '1.2.840.10008.5.1.4.1.1.7.1'
      '1.2.840.10008.5.1.4.1.1.7.2'
      '1.2.840.10008.5.1.4.1.1.7.3'
      '1.2.840.10008.5.1.4.1.1.7.4'
      '1.2.840.10008.5.1.4.1.1.12.1'
      '1.2.840.10008.5.1.4.1.1.12.2'
      '1.2.840.10008.5.1.4.1.1.20'
      '1.2.840.10008.5.1.4.1.1.77.1.1.1'
      '1.2.840.10008.5.1.4.1.1.77.1.2.1'
      '1.2.840.10008.5.1.4.1.1.77.1.4.1'
      '1.2.840.10008.5.1.4.1.1.77.1.5.1'
      '1.2.840.10008.5.1.4.1.1.77.1.5.2'
      '1.2.840.10008.5.1.4.1.1.481.1'}
  
    tf = true;
  
otherwise
  
    tf = false;
  
end


function SOP_UID = fixForMultiFile(SOP_UID)
% When the option to write to multiple files is present, switch to the
% explicitly single-frame versions of supported "creatable" SOP classes.

switch (SOP_UID)
case '1.2.840.10008.5.1.4.1.1.4.1'
    
    SOP_UID = '1.2.840.10008.5.1.4.1.1.4';
    
case '1.2.840.10008.5.1.4.1.1.2.1'
    
    SOP_UID = '1.2.840.10008.5.1.4.1.1.2';

end


function checkOptionConsistency(options, metadata)

if (~isequal(options.createmode, 'copy'))
    return;
end

if (isfield(options, 'sopclassuid') && ...
    (~isfield(metadata, 'SOPClassUID') && ~isfield(metadata, 'MediaStorageSOPClassUID')))
    
    warning(message('images:dicomwrite:inconsistentIODAndCreateModeOptions'))
        
elseif (isfield(options, 'objecttype'))
    
    warning(message('images:dicomwrite:inconsistentIODAndCreateModeOptions'))
        
end

%   Copyright 1993-2022 The MathWorks, Inc.