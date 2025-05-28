function formats = supportedWriteFormats()
% Returns list of image formats supported for writing

% Copyright 2022 The MathWorks, Inc.

    % Identify only the writeable formats supported by IMWRITE
    imf = imformats;
    imf = imf( arrayfun(@(x) ~isempty(x.write), imf) );

    % Get the extensions supported
    formats = {imf.ext};

    % Some formats support multiple extensions. Flatten it out
    formats = string(horzcat(formats{:})');

    % Remove extensions that dont need maps
    formats( ismember(formats, ["xwd", "pcx"]) ) = [];

    % Add DICOM and EXR
    formats(end+1:end+2) = ["dcm"; "exr"];
    formats = sort(formats);

end