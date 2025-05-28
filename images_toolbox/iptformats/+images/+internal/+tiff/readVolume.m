function V = readVolume(args, details)

% "PixelRegion" is used by readtif. Rows, Columns, Slices are used for
% one-pass volume reading here.
[details(1).isImageJ, details(1).NumImageJFrames] = images.internal.tiff.isImageJTiff(details);
args.PixelRegionNoInfs = convertInfToMax(args.PixelRegion, details);
regionStruct = process_region(args.PixelRegionNoInfs);
if numel(regionStruct) > 0
    args.Rows = regionStruct(1);
    args.Columns = regionStruct(2);
end
if numel(regionStruct) == 3
    args.Slices = regionStruct(3);
end

% Load the data.
if details(1).isImageJ
    V = loadBigImageJ(details, args);
elseif usesImageDepth(details)
    V = loadUsingImageDepth(details, args);
else
    V = loadUsingImfinfoAndLoop(details, args);
end
end


function tf = shouldSubset(args)
tf = ~isempty(args.PixelRegion);
end

function tf = usesImageDepth(details)
tf = isfield(details, 'ImageDepth');
end


function V = loadUsingImfinfoAndLoop(details, args)

% Gather metadata about image.
validateSliceSizes(details);

if shouldSubset(args)
    V = subsetUsingImfinfoAndLoop(details, args);
else
    V = loadFullUsingImfinfoAndLoop(details);
end
end


function V = loadFullUsingImfinfoAndLoop(details)

% Use the same TIFF loader as imread.
persistent tifLoader
if isempty(tifLoader)
    fmts = imformats('tif');
    tifLoader = fmts.read;
end

% Load the first slice/frame to get sizes, datatypes, etc.
firstSlice = tifLoader(details(1).Filename, 'info', details, 'index', 1); 

[origRows, origCols, ~] = size(firstSlice); 
origClass = class(firstSlice); 
numImages = numel(details); 
numChannels = numel(details(1).BitsPerSample); 

% Expand output to contain all slices.
V(origRows, origCols, numImages, numChannels) = cast(0, 'like', firstSlice); 
V(:,:,1,:) = firstSlice; 

% Loop through all slices, adding to output. 
for idx = 2:numImages 
    oneSlice = tifLoader(details(1).Filename, 'info', details, 'index', idx); 
    if ~isequal(class(oneSlice), origClass) 
        error(message('images:tiffreadVolume:inconsistentPixelClass', idx)) 
    elseif size(oneSlice,3) ~= numChannels 
        error(message('images:tiffreadVolume:inconsistentChannels', idx)) 
    end 
     
    V(:,:,idx,:) = oneSlice; 
end 
end 


function [args, idx] = args2idx(details, args)

% Assumes IFD-based slices (not ImageDepth or ImageJ).
if ~isfield(args, 'Slices')
    args.Slices.start = 1;
    args.Slices.incr = 1;
    args.Slices.stop = numel(details);
elseif ~isempty(args.Slices)
    if isinf(args.Slices.stop)
        args.Slices.stop = numel(details);
    end
else
    assert(false);  % Should not be able to reach this codepath with subsetting.
end

idx = args.Slices.start:args.Slices.incr:args.Slices.stop;
end


function V = subsetUsingImfinfoAndLoop(details, args)

persistent tifLoader
if isempty(tifLoader)
    fmts = imformats('tif');
    tifLoader = fmts.read;
end

% Set up and check subsetting arguments.
[args, slicesToRead] = args2idx(details, args);
numImages = numel(slicesToRead);
validateIndices(slicesToRead, details, args)

validateSubsetOptionsIFD(details, args)

numChannels = numel(details(1).BitsPerSample);

% Read first slice.
args.index = slicesToRead(1);

V = tifLoader(details(1).Filename, 'info', details, 'index', slicesToRead(1), ...
    'PixelRegion', args.PixelRegion(1:2));
V = permute(V, [1 2 4 3]);  % Should be zero cost to permute. Can't reshape because ndims can change.

[origRows, origCols, ~] = size(V);
origClass = class(V);

if numImages == 1
    return
end

% Expand output to contain all slices and read them.
V(origRows, origCols, numImages, numChannels) = 0;

sliceCounter = 2;
for idx = slicesToRead(2:end)
    oneSlice = tifLoader(details(1).Filename, 'info', details, ...
        'index', idx, 'PixelRegion', args.PixelRegion(1:2));
    
    if ~isequal(class(oneSlice), origClass)
        error(message('images:tiffreadVolume:inconsistentPixelClass', idx));
    elseif size(oneSlice,3) ~= numChannels
        error(message('images:tiffreadVolume:inconsistentChannels', idx));
    end
    
    V(:,:,sliceCounter,:) = oneSlice;
    sliceCounter = sliceCounter + 1;
end
end


function V = loadBigImageJ(details, args)

if numel(details) > 1
    error(message('images:tiffreadVolume:ImageJMustBeOneIFD'))
elseif ~isequal(details.Compression, 'Uncompressed')
    error(message('images:tiffreadVolume:ImageJMustBeUncompressed'))
elseif details.SamplesPerPixel > 1
    error(message('images:tiffreadVolume:ImageJMustBeGrayscale'))
elseif isfield(details, 'TileOffsets') && ~isempty(details.TileOffsets)
    error(message('images:tiffreadVolume:ImageJMustBeStriped'))
end

if shouldSubset(args)
    V = subsetBigImageJ(details, args);
else
    V = loadFullBigImageJ(details);
end
end


function V = loadFullBigImageJ(details)

numFrames = details(1).NumImageJFrames;
dtype = determineDatatype(details);

% Go to the beginning of the data, which is stored in one massive
% big-endian block starting at StripOffsets. (Be aware: The number of bytes
% in the "strip" does not match the total amount of data to read.)
fid = fopen(details.Filename);
oc = onCleanup(@() fclose(fid));

fseek(fid, details.StripOffsets, 'bof');

V = ones(details.Height, details.Width, numFrames, dtype);
for idx = 1:numFrames
    oneFrame = fread(fid, details.Width * details.Height, [dtype '=>' dtype], 'ieee-be');
    oneFrame = reshape(oneFrame, [details.Width details.Height]);
    V(:,:,idx) = oneFrame';
end

% V = reshape(V, [details.Width, details.Height, numFrames]);
% V = permute(V, [2 1 3]);
end


function output = subsetBigImageJ(details, args)

assert(isfield(args, 'Rows') && isfield(args, 'Columns') && isfield(args, 'Slices'))

% Determine number of frames from the ImageDescription field.
numFramesStr = regexp(details.ImageDescription, 'images=(\d*)', 'tokens');
numFrames = str2double(numFramesStr{1}{1});

if (args.Rows.stop > details(1).Height)
    error(message('images:tiffreadVolume:badRows', args.Rows.stop, details(1).Height))
elseif (args.Columns.stop > details(1).Width)
    error(message('images:tiffreadVolume:badColumns', args.Columns.stop, details(1).Width))
elseif (args.Slices.stop > numFrames)
    error(message('images:tiffreadVolume:badSlices', args.Slices.stop, numFrames))
end

[dtype, bitsPerSample] = determineDatatype(details);
sampleBytes = bitsPerSample/8;

% Set up subsetting indices.
if isempty(args.Slices)
    reqSlices = 1:numFrames;
else
    reqSlices = args.Slices.start:args.Slices.incr:args.Slices.stop;
end

rowStart = args.Rows.start;
rowStride = args.Rows.incr;
rowStop = args.Rows.stop;

colStart = args.Columns.start;
colStride = args.Columns.incr;
colStop = args.Columns.stop;

% Create the output.
output = zeros([numel(colStart:colStride:colStop), ...
                numel(rowStart:rowStride:rowStop), ...
                numel(reqSlices)], dtype);

dataOffset = details.StripOffsets(1);  % Should only be one value. Just in case.
bytesInScanline = details.Width * sampleBytes;

% Go to beginning of image data.
fid = fopen(details.Filename);
oc = onCleanup(@() fclose(fid));

readAllRows = rowStart == 1 && rowStride == 1 && rowStop == details.Height;
readAllCols = colStart == 1 && colStride == 1 && colStop == details.Width;
readFullSlice = readAllRows && readAllCols;

[pixelsPerRowToRead, numRows, numSlices] = size(output);

% Read/subset each slice.
outputSliceIdx = 1;
for sliceIdx = reqSlices
    offsetToSlice = dataOffset + (sliceIdx - 1) * bytesInScanline * details.Height;
    
    if readFullSlice
        fseek(fid, offsetToSlice, 'bof');
        thisSlice = fread(fid, [details.Width, details.Height], [dtype '=>' dtype], 'ieee-be');
        output(:,:,outputSliceIdx) = thisSlice;
    else
        outputRowIdx = 1;
        for rowIdx = rowStart:rowStride:rowStop
            offsetToFirstPixel = (rowIdx - 1) * bytesInScanline + (colStart - 1) * sampleBytes;
            fseek(fid, offsetToSlice + offsetToFirstPixel, 'bof');
            
            if readAllCols
                thisRow = fread(fid, details.Width, [dtype '=>' dtype], 'ieee-be');
            else
                skip = (colStride - 1) * sampleBytes;
                thisRow = fread(fid, pixelsPerRowToRead, [dtype '=>' dtype], skip, 'ieee-be');
            end
            
            output(:, outputRowIdx, outputSliceIdx) = thisRow;
            outputRowIdx = outputRowIdx + 1;
        end
    end
    
    outputSliceIdx = outputSliceIdx + 1;
end

% Convert to column-major.
output = reshape(output, [pixelsPerRowToRead, numRows, numSlices]);
output = permute(output, [2 1 3]);
end


function V = loadUsingImageDepth(details, args)

if numel(details) > 1
    error(message('images:tiffreadVolume:imageDepthMustBeOneIFD'))
end

% Must read full volume then subset if requested.
T = Tiff(details(1).Filename);
V = T.read();
V = permute(V, [1 2 4 3]);

if ~isfield(args, 'Slices')
    args.Slices.start = 1;
    args.Slices.incr = 1;
    args.Slices.stop = size(V,3);
end

if shouldSubset(args)
    rows = (args.Rows.start:args.Rows.incr:args.Rows.stop);
    cols = (args.Columns.start:args.Columns.incr:args.Columns.stop);
    slices = (args.Slices.start:args.Slices.incr:args.Slices.stop);
    
    validateSubsetOptionsDepth(details, args, rows, cols, slices)
    
    V = V(rows, cols, slices, :);
end
end


function [dtype, bitsPerSample] = determineDatatype(details)

T = matlab.io.internal.TiffReader(details(1).Filename);
dtype = char(T.MLType);
bitsPerSample = T.BitsPerSample;
end


function validateSubsetOptionsDepth(details, args, rows, cols, slices)

if rows(end) > details(1).Height
    error(message('images:tiffreadVolume:badRows', args.Rows.stop, details(1).Height))
elseif cols(end) > details(1).Width
    error(message('images:tiffreadVolume:badColumns', args.Columns.stop, details(1).Width))
elseif slices(end) > details(1).ImageDepth
    error(message('images:tiffreadVolume:badSlices', args.Slices.stop, details(1).ImageDepth))
end
end


function validateSubsetOptionsIFD(details, args)

assert(isstruct(args.Rows))

if ~isinf(args.Rows.stop) && (args.Rows.stop > details(1).Height)
    error(message('images:tiffreadVolume:badRows', args.Rows.stop, details(1).Height))
elseif ~isinf(args.Columns.stop) && (args.Columns.stop > details(1).Width)
    error(message('images:tiffreadVolume:badColumns', args.Columns.stop, details(1).Width))
elseif ~isinf(args.Slices.stop) && (args.Slices.stop > numel(details))
    error(message('images:tiffreadVolume:badSlices', args.Slices.stop, numel(details)))
end
end


function validateSliceSizes(details)

if isempty(details)
    return
end

allHeights = [details.Height];
allWidths = [details.Width];

heightIsDiffFromFirst = find(allHeights ~= allHeights(1), 1, 'first');
widthIsDiffFromFirst = find(allWidths ~= allWidths(1), 1, 'first');
firstDiff = min([heightIsDiffFromFirst, widthIsDiffFromFirst]);

if ~isempty(firstDiff)
    error(message('images:tiffreadVolume:inconsistentSize', firstDiff))
end

if (numel(details) > 1) && ...
        isfield(details, 'ImageDepth') && ...
        any([details.ImageDepth] > 1)
    error(message('images:tiffreadVolume:tooMuchImageDepth'))
end
end


function validateIndices(indices, details, args)

numSlices = numel(details);

if isempty(indices)
    error(message('images:tiffreadVolume:badSlices', args.Slices.start, numSlices))
elseif any(indices > numSlices)
    error(message('images:tiffreadVolume:badSlices', args.Slices.stop, numSlices))
end
end


function region_struct = process_region(region_cell)
%PROCESS_PIXELREGION  Convert a cells of pixel region info to a struct.

region_struct = struct([]);
if isempty(region_cell)
    % Not specified in call to readtif.
    return;
end

validateattributes(region_cell,{'cell'},{},'','PIXELREGION');
switch numel(region_cell)
    case {2 3}
        % No-op
    otherwise
        error(message('images:tiffreadVolume:wrongPixelRegionDescription'));
end

for p = 1:numel(region_cell)
    validateattributes(region_cell{p}, {'numeric'}, ...
        {'nonnan', 'real', 'finite', 'positive', 'integer'}, '', 'PIXELREGION');
    
    if (numel(region_cell{p}) == 2)
        
        start = region_cell{p}(1);
        incr = 1;
        stop = region_cell{p}(2);
        
    elseif (numel(region_cell{p}) == 3)
        
        start =region_cell{p}(1);
        incr = region_cell{p}(2);
        stop = region_cell{p}(3);
       
    else
        
        error(message('MATLAB:imagesci:readtif:tooManyPixelRegionParts'));
        
    end
    
    validateattributes(start, {'numeric'}, {'<=',stop}, '', 'START');

    region_struct(p).start = start;
    region_struct(p).incr = incr;
    region_struct(p).stop = stop;
end
end


function out = convertInfToMax(in, details)

out = in;
for idx = 1:numel(in)
    if isinf(out{idx}(end))
        switch idx
        case 1
            out{idx}(end) = details.Height;
        case 2
            out{idx}(end) = details.Width;
        case 3
            if details(1).isImageJ
                out{idx}(end) = details(1).NumImageJFrames;
            elseif isfield(details, 'ImageDepth')
                out{idx}(end) = details.ImageDepth;
            else
                out{idx}(end) = numel(details);
            end
        end
    end
end
end
% Copyright 2020-2024 The MathWorks, Inc.
