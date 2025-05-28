function imageBrowser(imagedata)

switch nargin
    case 0
        images.internal.app.imageBrowser.web.ImageBrowserCore;
    case 1
        if isa(imagedata, 'matlab.io.datastore.ImageDatastore')
            h = images.internal.app.imageBrowser.web.ImageBrowserCore;
            h.createThumbFigure(inputname(1), imagedata);
        elseif (isstring(imagedata) || ischar(imagedata)) && isfolder(imagedata)
            h = images.internal.app.imageBrowser.web.ImageBrowserCore;
            recursiveTF = false;
            h.loadFolder(imagedata,recursiveTF);
        else
            error(message('images:imageBrowser:unrecognizedInput'))
        end
    otherwise
        assert(false,'Unexpected syntax');
end


end

%   Copyright 2016-2023 The MathWorks, Inc.
