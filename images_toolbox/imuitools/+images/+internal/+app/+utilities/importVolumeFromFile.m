function [V,scaleTform] = importVolumeFromFile(filename,appname)
%

% Copyright 2020 The MathWorks, Inc.

% Suppress all file IO warnings
s = warning('off');
c = onCleanup(@() warning(s));

scaleTform = [];
if contains(filename,'.tif')
   % Read TIF stack
   V = readTiffStack(filename);    
elseif contains(filename,'.nrrd')
   [V,scaleTform] = readNRRD(filename);
elseif contains(filename,'.dcm')
   [V,scaleTform] = readDicom(filename);
elseif contains(filename,{'.nii' '.nii.gz'})		
   [V,scaleTform] = readNIFTI(filename);
elseif contains(filename,'.hdr')
   [V,scaleTform] = readAnalyze(filename);
elseif contains(filename,'.mat') && strcmp(appname,'VolumeSegmenter')
    V = readMatFile(filename);  
else
   [V,scaleTform] = readFileWithUnknownFormat(filename);
end

if strcmp(appname,'VolumeSegmenter')
        
    if ~images.internal.app.segmenter.volume.data.isVolume(V)
        
        ME = MException('images:volumeSegmenterRequiresVolumeData', ...
            getString(message('images:segmenter:invalidVolume')));
        throw(ME);
        
    end
    
elseif ~images.internal.app.volview.isVolume(V)
    ME = MException('images:volumeViewerRequiresVolumeData', ...
        getString(message('images:volumeViewer:requireVolumeData')));
    throw(ME);
end

end

function V = readMatFile(filename)

try
    % Try to load a mat file. If this files, assume the file is
    % an image file. If that fails, throw an error.
    m = matfile(filename);
    vars = whos(m);
    
    if isempty(vars)
        % Not a valid MAT file. Throw an error so we try to
        % load it as an image file
        error(message('images:segmenter:noCandidates'));
        
    elseif numel(vars) > 1
        
        numberofCandidateVolumes = 0;
        
        for idx = 1:numel(vars)
            
            if numel(vars(idx).size) == 3 || (numel(vars(idx).size) == 4 && vars(idx).size(4) == 3)
                
                if numberofCandidateVolumes == 0
                    
                    numberofCandidateVolumes = numberofCandidateVolumes + 1;
                    varname = vars(idx).name;
                    
                else
                    % If we hit this, there are more than one
                    % candidate volume that could be loaded.
                    % Error and explain to the user why.
                    error(message('images:segmenter:multipleCandidates'));
                end
                
            end
            
        end
        
        if numberofCandidateVolumes == 0
            % If we never found a candidate volume in the mat
            % file, error and explain to the user why.
            error(message('images:segmenter:noCandidates'));
        end
        
    elseif numel(vars) == 1
        varname = vars.name;
    else
        error(message('images:segmenter:noCandidates'));
    end
    
    % We have the variable name we want to try to load
    V = eval(['m.', varname]);
    
catch ME
    throw(ME);
end

end

function [V,tform] = readFileWithUnknownFormat(filename)

try
   [V,tform] = readDicom(filename);
catch
    throwInvalidFileException('')
end

end

function [V,tform] = readNRRD(filename)

try
    [V,meta] = images.internal.app.volview.fileformats.nrrdread(filename);
catch
    throwInvalidFileException('NRRD');
end
    
if isfield(meta,'spacedirections')
    directionsStr = meta.spacedirections;
    directionsStr = strsplit(directionsStr,{'(',')',',',' '});
    emptyInd = cellfun(@(c) isempty(c),directionsStr);
    directionsStr(emptyInd) = [];
    directions = abs(cellfun(@(c) str2double(c),directionsStr));
    directions = reshape(directions,[3 3]);
    if ~isdiag(directions) || any(~isfinite(directions(:)))
        % Obliquely oriented image grid relative to world coordinate system
        % or NaN values in directions.
        tform = [];
    else
        directionsDiag = diag(directions);
        minVoxelSize = min(directionsDiag);
        scale = directionsDiag ./ minVoxelSize;
        tform = makehgtform('scale',scale);
    end
else
    tform = [];
end

end

function [V,tform] = readNIFTI(filename)
try
    info = niftiinfo(filename);
    V = niftiread(filename);
catch
    throwInvalidFileException('NIFTI');
end

if isfield(info,'PixelDimensions')
    pixelDims = info.PixelDimensions(1:3);
    scaleFactors = pixelDims ./ min(pixelDims);
    tform = makehgtform('scale',scaleFactors);
end

end

function V = readTiffStack(filename)

try
    V = tiffreadVolume(filename);
catch
    throwInvalidFileException('TIFF');
end

end

function [V,tform] = readDicom(filename)

V = [];
try %#ok<TRYNC>
    [V, spatialDetails, sliceDim] = dicomreadVolume(filename);
    V = squeeze(V);
    
    sliceLoc = spatialDetails.PatientPositions;
    allPixelSpacings = spatialDetails.PixelSpacings;
    
    xSpacing = allPixelSpacings(1,1);
    ySpacing = allPixelSpacings(1,2);
    zSpacing = mean(diff(sliceLoc(:,sliceDim)));
    spacings = [xSpacing,ySpacing,zSpacing];
    spacings = spacings ./ min(spacings);
    tform = makehgtform('scale',spacings);
    return;
end

try
    if isempty(V)
        V = squeeze(dicomread(filename));
    end
    info = dicominfo(filename);
catch
    throwInvalidFileException('DICOM');
end

tform = [];
if isfield(info,'PixelSpacing') && isfield(info,'SliceThickness')
   spacings = [info.PixelSpacing;info.SliceThickness];
   scale = spacings ./ min(spacings);
   tform = makehgtform('scale',scale);   
end

end

function [V,tform] = readAnalyze(filename)

try
    metadata = analyze75info(filename);
    V = analyze75read(metadata);
catch
    throwInvalidFileException('Analyze 7.5');
end

if isfield(metadata,'PixelDimensions')
    pixelDims = metadata.PixelDimensions;
    scaleFactors = pixelDims ./ min(pixelDims);
    tform = makehgtform('scale',scaleFactors);
end

end

function throwInvalidFileException(fileTypeStr)

if isempty(fileTypeStr)
    ME = MException('images:invalidFile',getString(message('images:segmenter:invalidFileFormat')));
else
    ME = MException('images:invalidFile',getString(message('images:volumeViewer:invalidFileWithFormat',fileTypeStr)));
end

throw(ME);

end

