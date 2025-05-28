function imageBatchProcessor(source)

narginchk(0, 1);

% Flag to handle whether closing the open app instances is requested
isClose = false;

try
    ibp = [];

    % Syntax: imageBatchProcessor()
    if nargin == 0
        % Run AppContainer version
        images.internal.app.batchProcessor.BatchProcessorGUI();
    else
        % Syntax: 
        % (a) imageBatchProcessor(location)
        % (b) imageBatchProcessor(imds)
        % (c) imageBatchProcessor("close")
        
        imageSrc = convertCharsToStrings(source);

        % Syntax (a)
        if isa(imageSrc, "matlab.io.datastore.ImageDatastore")
            % Run AppContainer version
            ibp = images.internal.app.batchProcessor.BatchProcessorGUI();
            ibp.importImages(imageSrc);
        else
            if ~isstring(imageSrc)
                error(message("images:imageBatchProcessor:loadOnlyFromFolderOrIMDS"));
            end

            % A little quirk with the app in order to preserve backward
            % compatibility is that users cannot specify a folder
            % called "close" directly.

            % Syntax (c)
            if contains("close", imageSrc)
                isClose = true;
            else
                % Syntax (b)
                ibp = images.internal.app.batchProcessor.BatchProcessorGUI();
                ibp.importImages(imageSrc, false);
            end
        end
    end
catch ME
    if ~isempty(ibp)
        delete(ibp);
    end
    throwAsCaller(ME);
end

if isClose    
    imageslib.internal.apputil.manageToolInstances('deleteAll',...
        'imageBatchProcessor');
end

% Copyright 2014-2022 The MathWorks, Inc.
