function info = readAllIPTFormatsInfo(filename, options)
% readAllIPTFormatsInfo read all image formats supported by IPT
%  info = readAllIPTFormatsInfo(FILENAME) attempts to read image
%  information from FILENAME using this list of readers:
%       * Previously cached reader function handle
%       * Coarse level of a blockedImage if its a .tif, .tiff file
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
% Note: Caches last successfully used image info function. This improves
% performance of reading a list of similar format files.
%
% Note: keep in sync with supportedFormats()

% Copyright 2020-2022 The MathWorks, Inc.

arguments
    filename (1,1) string
    options.ImageIndex (1, 1) double {mustBeInteger, mustBePositive}
end

% Read information about all frames in the image for a multiframe image
isReadAllInfo = ~isfield(options, "ImageIndex");

ME = [];

% Verify if the file exists
try
    filename = images.internal.io.absolutePathForReading(filename);
catch ME
    throwAsCaller(ME);
end

persistent cachedInfoReader;

allWarnsOff = warning('off');
restoreWarnObj = onCleanup(@()warning(allWarnsOff));

prevInfoReader = cachedInfoReader;

try
    % A few checks to perform before trying the cached reader

    % Some RAW files are read by IMREAD. However, these return the preview
    % image instead.
    if isequal(cachedInfoReader, @imfinfo) && hasRAWExtn(filename) 
        % No need to translate as it is caught internally
        throw("Cannot use IMFINFO for these files");
    end
            
    % with the previously cached reader first
    info = cachedInfoReader(filename);
catch 
    % That failed, so do a fresh search using all known readers
    [info, cachedInfoReader, ME] = findReaderAndReadInfo(filename);
end

if ~isempty(ME)
    cachedInfoReader = prevInfoReader;
    throwAsCaller(ME);
end

% Provide the INFO struct for the specific image index
if ~(isReadAllInfo || isdicom(filename) || isnitf(filename))
    if options.ImageIndex > numel(info)
        error("Image Index requested is greater than number of images in the file");
    end
    info = info(options.ImageIndex);
end


end

%------------------------------------------------------------
function [info, cachedInfoReader, ME] = findReaderAndReadInfo(fileName)

    cachedInfoReader = [];
    ME = MException.empty();

    info = struct.empty();

    try
        % Unfortunately, there is no isRAW function. Hence, an exception
        % can be due to a corrupt RAW file or not a RAW file. Going to
        % treat it as the latter.
        info = rawinfo(fileName);
        cachedInfoReader = @rawinfo;
    catch MEraw
        % If the file does not have a recognized RAW format extension, then
        % try other readers. If not, report the exception received.
        if ~hasRAWExtn(fileName)
            [info, cachedInfoReader, ME] = tryImfinfoAndIPTInfoReads(fileName);
        else
            ME = MEraw;
        end
    end
end


%------------------------------------------------------------
function [info, cachedInfoReader, ME] = tryImfinfoAndIPTInfoReads(fileName)
% Read this image using IMFINFO and other supported IPT image info readers.

    ME = MException.empty();
    info = struct.empty();
    cachedInfoReader = [];
    
    try 
        % Since there is no way to detect if a file can be read by IMFINFO,
        % we have to try and read it
        info = imfinfo(fileName);
        cachedInfoReader = @imfinfo;
        
    catch MEimfinfo
        % Try other IPT format readers
        try 
            [info, cachedInfoReader] = readIPTFormatsInfo(fileName);
    
            % Indicates the file name was not detected as a supported IPT
            % format
            if isempty(info)
                ME = MEimfinfo;
            end
            
        catch MEipt
            % Exception generated indicates the fileName was detected as
            % being a supported file format but reading the file failed.
            ME = MEipt;
        end
    end
end

%------------------------------------------------------------
function [info, cachedReader] = readIPTFormatsInfo(fileName)
% Try to read information for other IPT file formats. 

% This function will throw an exception only if the fileName was infact
% detected as a supported file but reading the file failed.

% If the file was not detected as a supported format, it will return an
% empty struct array.

    info = struct.empty();
    cachedReader = [];
    
    if isdicom(fileName)
        info = dicominfo(fileName);
        cachedReader = @dicominfo;
    elseif isexr(fileName)
        info = exrinfo(fileName);
        cachedReader = @exrinfo;
    elseif images.internal.hdr.ishdr(fileName)
        % No hdrinfo function
        fileInfo = dir(fileName);
        info = struct( "Filename", fileName, ...
                       "FileModeDate", datestr(fileInfo.datenum), ...
                       "FileSize",  fileInfo.bytes, ...
                       "Format", "hdr" );

        cachedReader = [];
    elseif isnitf(fileName)
        info = nitfinfo(fileName);
        cachedReader = @nitfinfo;
    elseif isdpx(fileName)
        info = dpxinfo(fileName);
        cachedReader = @dpxinfo;
    end
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

