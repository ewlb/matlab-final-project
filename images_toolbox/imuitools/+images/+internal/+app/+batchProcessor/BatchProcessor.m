classdef BatchProcessor < handle
    %

    %   Copyright 2014-2022 The MathWorks, Inc.
    
    % API
    properties
        UseParallel = false;

        BeginFcn = @(ind)[];
        DoneFcn = @(ind)[];

        CleanupFcn = @(inds)[];
        
        IsStopReqFcn = @()false;
    end

    % Needed only for testing
    properties(Access=public, Hidden)
        WriteLocation = ""
    end

    properties(Access=public, Constant = true)
        ThumbnailSize = 72; %px
    end

    properties(Access = private)
        Datastore;
        BatchFcn;
        IsInclInfo;

        % State of each image. Each element has these fields:
        %   visited       = true | false
        %      true -> ProcessFunction has been called on this file. (Could
        %      still have errored though)
        %
        %   The remaining flags have a valid state only if visited == true.
        %
        %   errored       = true | false
        %      true -> One of read/proc/write failed. exception field has
        %      the relevant exception.
        %   exception     = []   | MException
        %      non-empty-> hasErrored is true. Contains corresponding
        %      exception.
        %
        ImageStates;
    end

    properties(Access=private, Dependent)
        NumImages
    end
    
    % Constants
    properties(Access=private, Constant)
        InitNumImagesToQueue = 30;
        UIUpdateStepSize = 10;
        QueueUpdateStepSize = 10;
    end
    
    
    methods
        %
        function this = BatchProcessor(inDS, batchFcn, isInclInfo, writeLocation)
            arguments
                % Restricting the input to be IMDS for now.
                inDS (1, 1) matlab.io.datastore.ImageDatastore
                batchFcn (1, 1) function_handle
                isInclInfo (1, 1) logical
                writeLocation (1, 1) string
            end

            this.Datastore = copy(inDS);
            reset(this.Datastore);
            
            this.BatchFcn = batchFcn;

            this.IsInclInfo = isInclInfo;
            this.WriteLocation = writeLocation;
            
            this.resetState();
        end
        
        %
        function resetState(this)
            % (Re)Initialize image states
            this.ImageStates = struct( ...
                'visited', num2cell(false(1, this.NumImages)),...
                'errored', false,...
                'exception', [] );
        end

        %
        function processSelected(this, selectedInds)
            if this.UseParallel
                this.processSelectedInParallel(selectedInds);
            else
                this.processSelectedInSerial(selectedInds);
            end
        end
        
        %
        function wasVisited = visited(this, ind)
            wasVisited = this.ImageStates(ind).visited;
        end
                
        %
        function hasErrored   = errored(this, ind)
            hasErrored = this.ImageStates(ind).errored;
        end
        
        %
        function exception = getException(this, ind)
            exception = this.ImageStates(ind).exception;
        end
    end

    % Helpers to work with the outputs generated after executing the batch
    % function
    methods
        function summary = resultSummary(this, ind)
            outputfile = this.getResultSummaryFileName(ind);
            summary = load(outputfile);
        end

        function result = loadOneResultField(this, ind, varname)
            outputfile   = this.getResultFileName(ind);
            pState = warning('off','MATLAB:load:variableNotFound');
            resetWarningObj = onCleanup(@()warning(pState));
            resultStruct = load(outputfile,varname);
            result       = resultStruct.(varname);
        end

        function allResultStructArray = loadAllResults(this, varnames, isInclInputFileName)
            allResultFiles = dir(fullfile(this.WriteLocation,'*_result.mat'));
            
            % All fields need not be present in all output if function
            % changed between calls
            pState = warning('off','MATLAB:load:variableNotFound');
            resetWarningObj = onCleanup(@()warning(pState));
            
            % Initialize struct array
            allResultStructArray(numel(allResultFiles)) = struct();
            
            % Initialize fields
            for ind =1:numel(varnames)
                [allResultStructArray.(varnames{ind})] = deal([]);
            end
            
            for outInd = 1:numel(allResultFiles)
                outputfile = fullfile(this.WriteLocation,allResultFiles(outInd).name);
                resultStruct = struct();
                if(~isempty(varnames))
                    resultStruct = load(outputfile,varnames{:});
                end
                
                % Copy fields actually found in the output
                foundFields = fieldnames(resultStruct);
                for ind = 1:numel(foundFields)
                    fieldName = foundFields{ind};
                    allResultStructArray(outInd).(fieldName) = ...
                        resultStruct.(fieldName);
                end
                
                % Include fileName
                if isInclInputFileName
                    imageIndex = str2double(...
                        strrep(allResultFiles(outInd).name,'_result.mat',''));
                    allResultStructArray(outInd).fileName = ...
                        this.getInputImageName(imageIndex);
                end
            end
        end

        function failed = copyAllResultsToFiles(this, outputDir, fieldAndFormat, ~)
            % Disable displaying a detailed backtrace when a warning is
            % generated as it exposes internal implementation
            warnBackTraceState = warning('off', 'backtrace');
            wbtStateCleanup = onCleanup( @() warning(warnBackTraceState) );
            
            % Create output directory if required
            [sucess, failMessage] = mkdir(outputDir);
            if ~sucess
                warning(['mkdir(' outputDir,') : ' failMessage]);
                failed = true;
                return;
            end
            
            % If dir already existed, ensure we have write permissions
            [~, dirPerms] = fileattrib(outputDir);
            if ~dirPerms.UserWrite
                warning(getString(message('images:imageBatchProcessor:unableToWriteToOutput', outputDir)));
                failed = true;
                return;
            end            
            
            allResultFiles = dir(fullfile(this.WriteLocation,'*_result.mat'));
            
            % All fields need not be present in all output of function
            % changed between calls
            pState = warning('off','MATLAB:load:variableNotFound');
            resetWarningObj = onCleanup(@()warning(pState));
            
            failed = false;
            
            hwb = waitbar(0,...
                getString(message('images:imageBatchProcessor:exportingToFiles',...
                0, numel(allResultFiles))));
            cleanUpWaitBar = onCleanup(@()delete(hwb));
            
            for outInd = 1:numel(allResultFiles)
                waitbar(outInd/numel(allResultFiles),hwb,...
                    getString(message('images:imageBatchProcessor:exportingToFiles',...
                    outInd, numel(allResultFiles))));
                
                
                resultFileName = fullfile(this.WriteLocation,allResultFiles(outInd).name);
                for fieldInd = 1:numel(fieldAndFormat)
                    fieldName = fieldAndFormat.Row{fieldInd};
                    outputFormat = fieldAndFormat.OutputImageFileTypes{fieldInd};
                    
                    % Output file name = outputdir + relative input file
                    % name - old format + new format
                    imageIndex = str2double(...
                        strrep(allResultFiles(outInd).name,'_result.mat',''));
                    [~, relativePath] = this.getInputImageName(imageIndex);
                    outImageFileName = fullfile(outputDir,relativePath);
                    outImageFileName = regexprep(outImageFileName,...
                        '.[^.]*$',['_', fieldName, '.', outputFormat]);
                    
                    imout = load(resultFileName,fieldName);
                    imout = imout.(fieldName);
                    if ~isempty(imout)
                        try
                            dirName = fileparts(outImageFileName);
                            if ~isfolder(dirName)
                                mkdir(dirName);
                            end
                            switch(outputFormat)
                                case "dcm"
                                    dicomwrite(imout, outImageFileName);
                                case "exr"
                                    exrwrite(imout, outImageFileName);
                                otherwise
                                    imwrite(imout, outImageFileName);
                            end
                        catch ALL
                            % Issue to command window
                            headerString = getString(message('images:imageBatchProcessor:failedToExportThisFile',...
                                fieldName,outImageFileName));
                            warnMessage = [headerString, newline, ALL.message];
                            warning(warnMessage);
                            failed = true;
                        end
                    end
                end
            end
        end
    end

    % Getters
    methods
        function out = get.NumImages(obj)
            out = numel(obj.Datastore.Files);
        end
    end
    
    
    % Helpers
    methods (Access = private)
        function processSelectedInSerial(this, imgIndxToProcess)
            % Subset the datastore to contain only the selected images
            subds = subset(this.Datastore, imgIndxToProcess);
            
            cnt = 1;

            % Using count of images to be processed instead of hasdata() to
            % handle the case of errors when reading images.
            while cnt <= numel(imgIndxToProcess)
                imgInd = imgIndxToProcess(cnt);
                cnt = cnt + 1;
                
                if this.IsStopReqFcn()
                    break;
                end                
                
                try
                    cleanUpObj = onCleanup(@()this.DoneFcn(imgInd));
                    this.BeginFcn(imgInd);
                    
                    [   this.ImageStates(imgInd).errored,...
                        this.ImageStates(imgInd).exception] = ...
                            readProcessAndWrite( subds,...
                                    this.BatchFcn, ...
                                    this.IsInclInfo, ...
                                    this.getResultFileName(imgInd), ...
                                    this.getResultSummaryFileName(imgInd) );

                catch ALL %#ok<NASGU>
                    % Using TRY-CATCH only to ensure clean up. All
                    % exceptions will be caught internally by
                    % readProcessAndWrite above.
                end
                
                this.ImageStates(imgInd).visited = true;

                % If the current image index being processed resulted in an
                % error, then subset the datastore again. Otherwise, the
                % errored image will read repeatedly in every subsequent
                % read call.
                if this.ImageStates(imgInd).errored
                    subds = subset(this.Datastore, imgIndxToProcess(cnt:end));
                end
            end
            % For images, whose processing was cancelled, remove the
            % "waiting" badge 
            this.CleanupFcn(imgIndxToProcess(cnt:end));
        end
        
        function processSelectedInParallel(this, imgIndxToProcess)
            totalNumImagesToProcess = numel(imgIndxToProcess);
            
            % To ensure the UI is updated in a timely manner, we are going
            % to fetch results from completed images while scheduling more
            % images for processing. 
            
            % Schedule a certain number of images for processing at the
            % begining to ensure some results are available. This again
            % depends on how long the batch function runs for.
            initNumImagesToProcess = min( totalNumImagesToProcess, ....
                                          this.InitNumImagesToQueue );
            ffuture = repmat(parallel.FevalFuture(), [initNumImagesToProcess 1]);
            
            for cnt = 1:initNumImagesToProcess
                imgInd = imgIndxToProcess(cnt);

                % Subsetting the datastore to contain only 1 image. This is
                % the only way to generalize the app to support any
                % datastore. 
                subds = subset(this.Datastore, imgInd);

                % Even though this array is resized dynamically, the
                % performance is pretty good. Prototyped a few other
                % options and this was the best. We are choosing this
                % approach because calling fetchNext() on a futures arrray
                % that has any entries that are unavailable results in an
                % array. So this approach ensures the array only has
                % ffutures that have valid tasks assigned to them.
                ffuture(cnt) = parfeval( ...
                    @readProcessAndWrite,...
                    2,...
                    subds, ...
                    this.BatchFcn, ...
                    this.IsInclInfo, ...
                    this.getResultFileName(imgInd), ...
                    this.getResultSummaryFileName(imgInd) );

                % Update the UI only in batches and not for every image
                if mod(cnt, this.UIUpdateStepSize) == 0
                    this.BeginFcn(this.UIUpdateStepSize);
                end
            end
            
            % If step size is not an exact multiple of number of initial
            % images scheduled, update the UI again.
            numRemImages = rem(initNumImagesToProcess, this.UIUpdateStepSize);
            if numRemImages ~= 0
                this.BeginFcn(numRemImages);
            end
            
            numImagesSchedForProcess = initNumImagesToProcess;
            % This is used to cache the value that will be used to update
            % the UI.
            prevNumImagesSchedForProcess = numImagesSchedForProcess;
            numImagesProcessed = 0;
            
            % Updating badges one thumbnail at a time is expensive. So we
            % update thumbnails in batches. This is tracks the batch of
            % image indices that need to be updated.
            imgIndxBatch = zeros(this.UIUpdateStepSize, 1);
            imgIndxBatchCnt = 0;
            
            % Loop until results have been fetched from all images
            % scheduled for processing
            while numImagesProcessed ~= numImagesSchedForProcess
                isAllImagesSched = numImagesSchedForProcess == totalNumImagesToProcess; 
                % If a stop was requested, then do not schedule any
                % remaining images
                isStopReq = this.IsStopReqFcn();
                if ~isStopReq
                    % Schedule any remaining images one at a time until all
                    % images have been scheduled
                    if ~isAllImagesSched
                        numImagesSchedForProcess = numImagesSchedForProcess + 1;
                        imgInd = imgIndxToProcess(numImagesSchedForProcess);
                        % Subsetting the datastore to contain only 1 image.
                        % This is the only way to generalize the app to
                        % support any datastore. 
                        subds = subset(this.Datastore, imgInd);
                        ffuture(numImagesSchedForProcess) = parfeval( ...
                                @readProcessAndWrite, ...
                                2, ...
                                subds, ...
                                this.BatchFcn, ...
                                this.IsInclInfo, ...
                                this.getResultFileName(imgInd), ...
                                this.getResultSummaryFileName(imgInd) );
                        
                        % Update UI in batches
                        if rem(numImagesSchedForProcess, this.UIUpdateStepSize) == 0
                            this.BeginFcn(this.UIUpdateStepSize);
                        end
                    end
                else
                    % Stop was requested. Hence, cancel any scheduled
                    % future objects.
                    cancel(ffuture);
                end
                
                % If all images have been scheduled OR if a stop has been
                % requested, then check if there are any remaining images
                % for which the UI has not been updated.
                if (isAllImagesSched || isStopReq) && ...
                        prevNumImagesSchedForProcess ~= numImagesSchedForProcess
                    
                    prevNumImagesSchedForProcess = numImagesSchedForProcess;
                    numRemImages = rem(numImagesSchedForProcess, this.UIUpdateStepSize);
                    if numRemImages ~= 0
                        this.BeginFcn(numRemImages);
                    end
                end
                
                % Grab next available result if done
                try
                    % Using a timeout to ensure that we do not wait
                    % infinitely until results are available.
                    [completedInd, errored, exception] = fetchNext(ffuture, 0.1);
                    % Indicates no result is available
                    if isempty(completedInd)
                        continue;
                    end
                catch PEXP
                    % If results from all futures have been read, then we
                    % can exit this loop.
                    if PEXP.identifier == "MATLAB:parallel:future:NoUnreadFutures"
                        break;
                    end
                    
                    cause = PEXP.cause{1};
                    if cause.identifier == "parallel:fevalqueue:ExecutionCancelled"
                        continue;
                    end
                    
                    % Indicates the exception generated is due to an error
                    % during execution of the batch function
                    completedInd = cnt;
                    errored = true;
                    exception = PEXP.cause{1};
                end
                
                localImgInd = imgIndxToProcess(completedInd);
                this.ImageStates(localImgInd).visited       = true;
                this.ImageStates(localImgInd).errored       = errored;
                this.ImageStates(localImgInd).exception     = exception;
                numImagesProcessed = numImagesProcessed + 1;
                
                % Track the image indices that were processed and update
                % the badges when the required number have been batched
                % together
                imgIndxBatchCnt = imgIndxBatchCnt + 1;
                imgIndxBatch(imgIndxBatchCnt) = localImgInd;
                if imgIndxBatchCnt == this.UIUpdateStepSize
                    this.DoneFcn(imgIndxBatch);
                    imgIndxBatch = zeros(this.UIUpdateStepSize, 1);
                    imgIndxBatchCnt = 0;
                end
            end
            
            % Check if any processed images are present whose UI has not
            % been updated
            imgIndxBatch( imgIndxBatch == 0 ) = [];
            if ~isempty(imgIndxBatch)
                this.DoneFcn(imgIndxBatch);
            end
            
            % For images, whose processing was cancelled, remove the
            % "waiting" badge 
            imageIndxCancelled = imgIndxToProcess(numImagesSchedForProcess+1:end);
            this.CleanupFcn(imageIndxCancelled);
        end
    
        function [absolutePath, relativePath] = getInputImageName(this, ind)
            absolutePath = this.Datastore.Files{ind};

            if isscalar(this.Datastore.Folders)
                rootPath = this.Datastore.Folders{1};
            else
                % IMDS can be created from multiple locations. If a file
                % has multiple root folder locations that refer to it, then
                % relative path needs to be expressed from the highest
                % possible root.
                % For example, 
                % IMDS has Folder prop = {'mydir1', 'mydir1/mydir2'}
                % and there is a file myfile.png in each folder.
                % The relative path for the file mydir1/mydir2/myfile.png
                % will be returned as mydir2/myfile.png. 
                % This relative path is used to ensure the directory tree
                % is preserved when exporting output image files.
                rootFolders = this.Datastore.Folders;

                % There will be atleast one valid root folder.
                validRoots = cellfun(@(x) contains(absolutePath, x), rootFolders);

                % The valid root with the shortest length will be the
                % highest parent i.e mydir1 will be shorter than
                % mydir1/mydir2
                [~, highestParentIdx] = min(strlength(rootFolders(validRoots)));
                rootPath = rootFolders{highestParentIdx};
            end

            relativePath = erase(absolutePath, [rootPath filesep]);
        end
        
        function fullPath = getResultFileName(this, ind)
            fullPath = fullfile(this.WriteLocation, [num2str(ind) '_result.mat']);
        end
        
        function fullPath = getResultSummaryFileName(this, ind)
            fullPath = fullfile(this.WriteLocation, [num2str(ind) '_summary.mat']);
        end
    end
end

function [hasErrored, exception] = readProcessAndWrite( ds, batchFcn, ...
                                                        isInclInfo, ...
                                                        outputFileName, ...
                                                        summaryFileName )
% Function that executes the batch function and saves the results for later
% use

    hasErrored    = false;
    exception     = [];
    
    try % to process file

        [im, info] = read(ds);
        
        if isInclInfo
            results = batchFcn(im, info);
        else
            results = batchFcn(im);
        end
        if~( (isstruct(results)&&numel(results)==1)...
                || islogical(results) || isnumeric(results) )
            % Ensure scalar structure or numeric array
            error(getString(message('images:imageBatchProcessor:expectedScalarStruct')));
        end
        writeResults(results, outputFileName, summaryFileName);
    catch ALL
        hasErrored = true;
        exception  = ALL;
    end

    if hasErrored
        clearPreviousResults(outputFileName, summaryFileName);
    end
end

function writeResults(resToWrite, outputFile, summaryFile)
% Function to write the results of the batch function to the output
% location. 
    if ~isstruct(resToWrite)
        % Support for image in - image out workflow.
        results.output = resToWrite;
    else
        results = resToWrite;
    end
    save(outputFile, '-struct','results', '-v7.3');
    
    thumbnailSize = images.internal.app.batchProcessor.BatchProcessor.ThumbnailSize;
    % Compute and save thumbnails/truncated textual display
    summary = struct();
    for field = fieldnames(results)'
        im = results.(field{1});
        if images.internal.app.batchProcessor.isImage(im)
            % create thumbnail
            if(size(im,1)>size(im,2))
                thumb = imresize(im,[thumbnailSize, NaN],'nearest');
            else
                thumb = imresize(im,[NaN, thumbnailSize],'nearest');
            end
            if ~isa(thumb,'uint8')
                %  Scale down to uint8
                thumb = uint8(rescale(thumb, 0, 255));
            end
            summary.(field{1}) = thumb;
        else
            if (isnumeric(im)||islogical(im)) && numel(im)>20
                % Show size and data type
                imageInfo = whos('im');
                imageSize = sprintf('%dx',imageInfo.size);
                imageSize(end) = [];
                summary.(field{1}) = [imageSize, ' ', imageInfo.class];
            else
                % Use DISP. Links look bad on uicontrol, turn it
                % off.
                dispText = evalc('feature(''hotlinks'',''off''); disp(im); feature(''hotlinks'',''on'')');
                summary.(field{1}) = deblank(dispText);
            end
        end
    end
    save(summaryFile, '-struct','summary', '-v7.3');
end

function clearPreviousResults(outputFile, summaryFile)
    % If function invocation failed, ensure that previous results
    % are deleted
    
    if exist(outputFile, 'file')
        delete(outputFile);
    end
    
    if exist(summaryFile, 'file')
        delete(summaryFile);
    end            
end
