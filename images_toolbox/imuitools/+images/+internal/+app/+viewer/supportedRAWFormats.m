function extn = supportedRAWFormats()
% Helper function that returns a list of supported RAW file format
% extensions. This is needed as there is no way to query whether an image
% file is RAW or not.

    % Copyright 2023 The MathWorks, Inc.
    
    extn = [ ".dng",".nef",".cr2",".crw",".arw",".raf",".kdc", ...
             ".mrw",".orf",".raw",".rw2",".srw",".pef",".x3f" ];

    extn = [extn upper(extn)];
end