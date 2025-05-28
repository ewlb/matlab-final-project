function tf = ishdr(fileName)

    arguments
        fileName (1, 1) string
    end

    [fp, msg] = fopen(fileName, "r");
    if fp == -1
        msg = message('images:hdrread:fileOpen', filename, msg);
        errorID = replace(msg.Identifier, "hdrread", "ishdr");
        throw(MException(errorID, getString(msg)));
    end
    
    fpOc = onCleanup( @() fclose(fp) );

    % Ensure that we're reading an HDR file.
    header = '';
    while ~contains(header, "#?") && ~feof(fp)
        header = fgetl(fp);
        continue;
    end

    tf = contains(header, "#?");

    radianceMarker = strfind(header, '#?');
    fileID  =header((radianceMarker+1):end);

    tf = tf && contains(fileID, ["RADIANCE"; "RGBE"]);
end

% Copyright 2022 The MathWorks, Inc.