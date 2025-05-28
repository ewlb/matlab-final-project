function [im, cmap] = readAllIPTFormats(filename, options)
% readAllIPTFormats read all image formats supported by IPT
%  [im, cmap] = readAllIPTFormats(FILENAME) attempts to read FILENAME
%  as an image file using this list of readers:
%       * Previously cached reader function handle
%       * RAW files
%       * IMREAD wrapper 
%       * DICOM wrapper 
%       * NITF
%       * DPX
%       * EXR
%       * HDR
%
%  On read failure, issues as informative an exception as possible to the
%  user.
%
% Note: Caches last successfully used image read function. This improves
% performance of reading a list of similar format files.
%
% Note: keep in sync with supportedFormats()

% Copyright 2020-2022 The MathWorks, Inc.

arguments
    filename (1,1) string

    % Supported input values are:
    % 1. integer-valued positive scalar
    % 2. Character vector or string scalar with the value "default"
    %
    % The "default" behaviour will be resolved by the specific reader used.
    options.ImageIndex  { mustBeA( options.ImageIndex, ...
                                   ["numeric", "char", "string"] ) } = "default"
end

ME = [];

% Verify if the file exists
try
    filename = images.internal.io.absolutePathForReading(filename);
catch ME
    throwAsCaller(ME);
end

options = convertContainedStringsToChars(options);
if ischar(options.ImageIndex)
    options.ImageIndex = validatestring(options.ImageIndex, "default");
else
    validateattributes( options.ImageIndex, "double", ...
                        ["integer", "positive"], "readAllIPTFormats" );
end

persistent cachedReader;

allWarnsOff = warning('off');
restoreWarnObj = onCleanup(@()warning(allWarnsOff));

prevReader = cachedReader;

try
    % A few checks to perform before trying the cached reader

    % Some RAW files are read by IMREAD. However, these return the preview
    % image instead. 
    if isequal(cachedReader, @imreadWrapper) && hasRAWExtn(filename)
        % No need to translate as it is caught internally
        throw("Cannot use IMREAD for these files");
    end
            
    % with the previously cached reader first
    [im, cmap] = cachedReader(filename, options.ImageIndex);
catch 
    % That failed, so do a fresh search using all known readers
    [im, cmap, cachedReader, ME] = ...
                        findReaderAndRead(filename, options.ImageIndex);
end

if ~isempty(ME)
    cachedReader = prevReader;
    throwAsCaller(ME);
end

end

%------------------------------------------------------------
function [im, cmap, cachedReader, ME] = ...
                        findReaderAndRead(fileName, idx)

    cachedReader = [];
    ME = MException.empty();

    im = [];
    cmap = [];

    try
        % Unfortunately, there is no isRAW function. Hence, an exception
        % can be due to a corrupt RAW file or not a RAW file. Going to
        % treat it as the latter.
        [im, cmap] = raw2rgbWrapper(fileName, idx);
        cachedReader = @raw2rgbWrapper;
    catch MEraw
        % If the file does not have a recognized RAW format extension, then
        % try other readers. If not, report the exception received.
        if ~hasRAWExtn(fileName)
            [im, cmap, cachedReader, ME] = tryImreadAndIPTreads(fileName, idx);
        else
            ME = MEraw;
        end
    end
end


%------------------------------------------------------------
function [im, cmap, cachedReader, ME] = tryImreadAndIPTreads(fileName, idx)
% Read this image using IMREAD and other supported IPT image readers.

ME = MException.empty();
im = [];
cmap = [];
cachedReader = [];

try 
    % Since there is no way to detect if a file can be read by IMREAD, we
    % have to try and read it
    [im, cmap] = imreadWrapper(fileName, idx);
    cachedReader = @imreadWrapper;
    
catch MEimread
    % Try other IPT format readers
    try 
        [im, cmap, cachedReader] = readIPTFormats(fileName, idx);

        % Indicates the file name was not detected as a supported IPT
        % format
        if isempty(im)
            ME = MEimread;
        end
        
    catch MEipt
        % Exception generated indicates the fileName was detected as being
        % a supported file format but reading the file failed.
        ME = MEipt;
    end
end
end

%------------------------------------------------------------
function [im, cmap, cachedReader] = readIPTFormats(fileName, idx)
% Try to read other IPT file formats. 

% This function will throw an exception only if the fileName was infact
% detected as a supported file but reading the file failed.

% If the file was not detected as a supported format, it will return an
% empty image array.

im = [];
cmap = [];
cachedReader = [];

if isdicom(fileName)
    [im, cmap] = dicomreadWrapper(fileName, idx);
    cachedReader = @dicomreadWrapper;
elseif isexr(fileName)
    [im, cmap] = exrreadWrapper(fileName, idx);
    cachedReader = @exrreadWrapper;
elseif images.internal.hdr.ishdr(fileName)
    [im, cmap] = hdrreadWrapper(fileName, idx);
    cachedReader = @hdrreadWrapper;
elseif isnitf(fileName)
    [im, cmap] = nitfreadWrapper(fileName, idx);
    cachedReader = @nitfreadWrapper;
elseif isdpx(fileName)
    [im, cmap] = dpxreadWrapper(fileName, idx);
    cachedReader = @dpxreadWrapper;
end
end


%------------------------------------------------------------
function [im, cmap] = raw2rgbWrapper(fileName, idx)
% Wrap raw2rgb

if isnumeric(idx) && idx > 1
    error(message("images:readAllIPTFormats:MultipageUnsupported"));
end

im = raw2rgb(fileName);
cmap = [];
end

%------------------------------------------------------------
function [im, cmap] = imreadWrapper(fileName, idx)
% Wrap IMREAD

% Perform default read when requested. IMREAD does not even accept an index
% argument = 1 for file formats that are not multi-page.
if isstring(idx)
    [im, cmap] = imread(fileName);
    return;
end

if endsWith(fileName, [".gif", ".pgm", ".ppm", ".pbm", ".ppm", ".cur", ".ico", ".tif", ".svs", ".hdf"])
    [im, cmap] = imread(fileName, idx);
else
    if idx > 1
        error(message("images:readAllIPTFormats:MultipageUnsupported"));
    end
    [im, cmap] = imread(fileName);
end

end

%------------------------------------------------------------
function [im, cmap] = dicomreadWrapper(fileName, idx)
% Wrap DICOMREAD, apply colormap if present

    if isstring(idx)
        % The default beheaviour of DICOMREAD is to read all the frames
        % from the file.
        idx = "all";
    end
    [im, cmap] = dicomread(fileName, Frames=idx);
    
    % DICOMREAD returns an empty matrix for any non-DICOM file.
    if isempty(im)
        error(message('images:readAllIPTFormats:NoImage'));
    end

end

%------------------------------------------------------------
function [im, cmap] = nitfreadWrapper(fileName, idx)
% Wrap NITF reading functionality

    if isstring(idx)
        idx = 1;
    end

    im = nitfread(fileName, idx);
    cmap = [];
end

%------------------------------------------------------------
function [im, cmap] = dpxreadWrapper(fileName, idx)
% Wrap DPX reading functionality

    if isnumeric(idx) && idx > 1
        error(message("images:readAllIPTFormats:MultipageUnsupported"));
    end
    
    im = dpxread(fileName);
    cmap = [];
end

%------------------------------------------------------------
function [im, cmap] = exrreadWrapper(fileName, idx)
% Wrap exrread

    if isstring(idx)
        idx = 1;
    end

    im = exrread(fileName, PartIdentifier=idx);
    cmap = [];
end

%------------------------------------------------------------
function [im, cmap] = hdrreadWrapper(fileName, idx)
% Wrap hdrread

    if isnumeric(idx) && idx > 1
        error(message("images:readAllIPTFormats:MultipageUnsupported"));
    end
    im = hdrread(fileName);
    cmap = [];
end

%------------------------------------------------------------
function tf = hasRAWExtn(fileName)
% Helper function that checks if the input file contains a known RAW file
% extension

    rawFormats =  [ ".dng",".nef",".cr2",".crw",".arw",".raf",".kdc", ...
                    ".mrw",".orf",".raw",".rw2",".srw",".pef",".x3f", ...
                    ".DNG",".NEF",".CR2",".CRW",".ARW",".RAF",".KDC", ...
                    ".MRW",".ORF",".RAW",".RW2",".SRW",".PEF",".X3F" ];

    tf = endsWith(fileName, rawFormats);
end
