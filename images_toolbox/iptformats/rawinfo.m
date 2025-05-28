function info = rawinfo(fileName)

    arguments
        fileName (1, 1) string
    end

    fullFileName = images.internal.io.absolutePathForReading(fileName);
    
    info = images.internal.builtins.rawinfo(char(fullFileName));
    
    % Populate the information about the file
    info.Filename = string(fullFileName);
    
    % Get Information about the Tags in the file
    imageTagInfo = getImageTagInfo(fullFileName);
    
    % Populate EXIF Tags
    info.ExifTags = getExifTags(imageTagInfo);
    
    % Populate DNG Tags if the file is a DNG file
    info = populateDNGTags(info, imageTagInfo);
    
    % Perform some post-processing of the INFO struct
    info = postProcessInfo(info);
end

function exifTags = getExifTags(imageTagInfo)
    % Get information about any EXIF Tags present in the file
    
    exifTags = struct.empty();
    
    if isempty(imageTagInfo)
        return;
    end
    
    if ~isfield(imageTagInfo, 'DigitalCamera')
        return;
    end
    
    exifTags = imageTagInfo.DigitalCamera;
end

function info = populateDNGTags(info, imageTagInfo)
    % Populate the FormatSpecificInfo with DNG Tag values that are
    % available.
    
    if isempty(imageTagInfo)
        return;
    end
    
    % For DNG files, the builtin code returns a struct with the expected
    % field names pre-populated. This is done as it is easier to detect
    % whether a file is a DNG using libraw than otherwise.
    % We want to check whether one of the fields is a DNG specific tag.
    if ~isfield(info.FormatSpecificInfo, 'DNGTags')
        return;
    end
    
    dngTagNames = fieldnames(info.FormatSpecificInfo.DNGTags);
    
    % Scan the TIFF tags for the DNG specific ones we are interested in and
    % populate them if present.
    % DNG 1.5 spec states the primary camera profile is stored in IFD0 for
    % backwards compatibility. Hence, it is sufficient to inspect the
    % top-level info struct returned by IMFINFO.
    imageTagNames = fieldnames(imageTagInfo);
    for cnt = 1:numel(dngTagNames)
        tagName = dngTagNames{cnt};
        if ismember(tagName, imageTagNames)
            info.FormatSpecificInfo.DNGTags.(tagName) = imageTagInfo.(tagName);
        else
            % If the tag was not parsed by IMFINFO, indicates the tag is
            % not present in the file. Hence, remove the tag name from the
            % DNGTags field.
            % Tag with an empty value is confusing as we cannot distinguish
            % between
            % (a) Tag is present in the file but has no value OR
            % (b) Tag not present in the file
            info.FormatSpecificInfo.DNGTags = rmfield(info.FormatSpecificInfo.DNGTags, tagName);
        end
    end
end

function imageInfo = getImageTagInfo(fileName)
    % Use IMFINFO to get information about the image. This will be used to
    % populate EXIF Tags and DNG specific tags if any.
    
    % The IMFINFO call can fail if:
    % 1. RAW File is not TIFF-based
    % 2. Possibly unsupported by IMFINFO
    % In such cases, we return an empty struct.
    try
        warnState = warning('off', 'all');
        warnCleanup = onCleanup( @() warning(warnState) );
        imageInfo = imfinfo(fileName);
    catch ME
        imageInfo = struct.empty();
    end
end

function info = postProcessInfo(info)
% This function is for post-processing the INFO struct read from libraw
% to workaround some of the quirks of the library.

    % Convert the timestamp property into a datetime type
    info.MiscInfo.ImageTimeStamp = convertTimeStamp(info.MiscInfo.ImageTimeStamp);
    
    % Parse the raw bytes of the ICC Profile into a 1x1 struct that is
    % returned by ICCREAD. 
    % If the parsing fails, then the raw bytes are preserved as read.
    info.ColorInfo.ICCProfile = parseICCProfile(info.ColorInfo.ICCProfile);
        
    % Convert Camera Presets WhiteBalance information (if any) into a table
    info = convertCameraWBInfoToTable(info);
    
    % For many files, the CameraToXYZ matrix is not always available and is
    % a matrix of all zeros. In such cases, this has to be derived using
    % CameraTosRGB by converting it back to XYZ space
    if isempty(find(info.ColorInfo.CameraToXYZ, 1))
        % Transformation matrix for sRGB from sRGB -> XYZ
        M = images.color.internal.linearRGBToXYZTransform(true);
        
        % The CameraTosRGB matrix is scaled such that transformation from
        % sRGB space to Camera Space transforms white to white i.e.
        % sRGBToCamera*[1 1 1]' = [1 1 1]';
        % The scale factors correspond to the D65 White Balance
        % multipliers. We need to undo this scaling before computing the
        % CameraToXYZ matrix
        unscaledCameraTosRGB = unscaleCameraTosRGB(info);
        
        % Below is equivalent to sRGBToXYZ(CameraTosRGB(PIX)) =>
        % sRGBToXYZ * CameraTosRGB
        info.ColorInfo.CameraToXYZ = M * unscaledCameraTosRGB;
    else
        % Underlying code actually returns the matrix to convert from XYZ
        % to Camera Space.
        % Perform inverse or pseudoinverse as necessary to obtain the
        % transformation from Camera Space to XYZ
        info.ColorInfo.CameraToXYZ = invertMatrix(info.ColorInfo.CameraToXYZ);
    end
end

function out = convertTimeStamp(ts)
    % Convert the timestamp returned as POSIX Time into a datetime type
    
    % In POSIX time terms, 0 means Jan 1, 1970. Treating this as an
    % indication that the timestamp was not present.
    if ts == 0
        out = datetime.empty();
    else
        % Specify the time in terms of Eastern Time-Zone
        out = datetime(ts, 'ConvertFrom', 'posixtime', 'TimeZone', 'America/New_York');
        % Changing the Display Format to ensure the time-zone is shown in
        % the default display.
        out.Format = 'MMMM d, yyyy HH:mm:ss z';
    end
end

function icc = parseICCProfile(iccProfileRawBytes)
    icc = iccProfileRawBytes;    
    
    if isempty(iccProfileRawBytes)
        return;
    end
    
    try
        % As the iccread function does not support reading from a
        % byte-stream, writing the profile to a temporary file to parse it.
        
        % Write the bytes to a temporary file
        iccProfFileName = [tempname '.icc'];
        fp = fopen(iccProfFileName, 'wb');
        if fp == -1
            return;
        end
        
        fwrite(fp, iccProfileRawBytes);
        fclose(fp);
        
        try
            icc = iccread(iccProfFileName);
        catch iccME
        end
        delete(iccProfFileName);
        
    catch ME
        return;
    end
end

function info = convertCameraWBInfoToTable(info)
    % If the file contains information about white-balance multipliers for
    % the camera presets, they are returned as a cell array. This function
    % converts them into a table type
    
    if ~isfield(info.FormatSpecificInfo, 'CameraWhiteBalancePresets')
        return;
    end
    
    % If the camera provides white balance information about its presets,
    % then both camera mode and color temp white balance fields are
    % present. It is possible that one of the fields can be empty.
    wb = info.FormatSpecificInfo.CameraWhiteBalancePresets.CameraModesMultipliers;
    if isempty(wb)
        t = table.empty;
    else
        t = cell2table(wb, "VariableNames", ["CameraPresetModes", "WhiteBalance"] );
    end
    info.FormatSpecificInfo.CameraWhiteBalancePresets.CameraModesMultipliers = t;
    
    wb = info.FormatSpecificInfo.CameraWhiteBalancePresets.ColorTemperatureMultipliers;
    if isempty(wb)
        t1 = table.empty;
    else
        t1 = cell2table(wb, "VariableNames", ["ColorTemperature", "WhiteBalance"]);
    end
    info.FormatSpecificInfo.CameraWhiteBalancePresets.ColorTemperatureMultipliers = t1;
end


function unscaledCameraTosRGB = unscaleCameraTosRGB(info)
    if info.CFALayout == ""
        % Multiplication factors are in the R, G1, B, G2 order. G1 and G2
        % represent possibly different G sensors. 
        mulFactor = info.ColorInfo.D65WhiteBalance';
    else
        % For Bayer pattern, the coefficients are in the CFALayout order.
        % Hence, we need to reorder them in the R, G1, B, G2 order because
        % the conversion matrices always operate on the image data in the
        % [R, G1, B, G2] order. G1 and G2 represent possibly different G
        % sensors.
        numSensorElems = size(info.ColorInfo.CameraTosRGB, 2);
        mulFactor = zeros(numSensorElems, 1);
        idxFound = logical(mulFactor);
        
        rLoc = strfind(info.CFALayout, "R");
        mulFactor(1) = info.ColorInfo.D65WhiteBalance(rLoc);
        idxFound(rLoc) = true;

        gLoc = strfind(info.CFALayout, "G");
        mulFactor(2) = info.ColorInfo.D65WhiteBalance(gLoc(1));
        idxFound(gLoc(1)) = true;
        
        bLoc = strfind(info.CFALayout, "B");
        mulFactor(3) = info.ColorInfo.D65WhiteBalance(bLoc);
        idxFound(bLoc) = true;
        
        if numSensorElems == 4
            mulFactor(4) = info.ColorInfo.D65WhiteBalance( find(~idxFound) );
        end
    end
    
    % This matrix contains the transformation from sRGB space to the camera
    % space. This is 3xNUMSENSORELEMS matrix, where NUMSENSORELEMS can be 3
    % or 4.
    sRGBToCamera = invertMatrix(info.ColorInfo.CameraTosRGB);
    
    % Undo the scaling of this matrix using the daylight White Balance
    % coefficients
    unscaledsRGBToCamera = sRGBToCamera ./ mulFactor;
    
    unscaledCameraTosRGB = invertMatrix(unscaledsRGBToCamera);
end

function out = invertMatrix(in)
    s = size(in);
        
    % Perform Moore-Penrose pseudo-inverse if non-square matrix
    if all(s == s(1))
        out = inv(in);
    else
        out = pinv(in);
    end
end

%   Copyright 2020-2022 The MathWorks, Inc.
