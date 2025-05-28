function imageViewer(varargin)
    nargoutchk(0, 0);

    [varargin{:}] = convertStringsToChars(varargin{:});

    try
        checkIfImtoolStyleInputs(varargin{:});
    catch ME
        throwAsCaller(ME)
    end

    [imageSource, options] = parseInputs(varargin{:});

    if isempty(imageSource) && ~isempty(fieldnames(options))
        error(message("images:imageViewer:noNVPairsForEmptyApp"));
    end

    if ~isempty(imageSource)
        if ischar(imageSource) || isstring(imageSource)
            if imageSource == "close" && ~isempty(fieldnames(options))
                error(message("images:imageViewer:noNVPairsForClose"));
            end
    
            if imageSource == "close"
                imageslib.internal.apputil.manageToolInstances( 'deleteAll',...
                                            'imageViewer' );
                return;
            end
        end
    end

    mustBeValidOptionsForImageType(options, imageSource);

    if ~isfield(options, "Interpolation")
        options.Interpolation = "nearest";
    end

    if ~isfield(options, "Colormap")
        options.Colormap = zeros(0, 3);
    end

    if ~isfield(options, "InitialMagnification")
        options.InitialMagnification = "fit";
    else
        initMag = options.InitialMagnification;
        if ischar(initMag) || isstring(initMag)
            options.InitialMagnification = string( ...
                    validatestring(initMag, "fit") );
        else
            options.InitialMagnification = initMag;
        end
    end

    if ~isempty(imageSource) && ...
            (isnumeric(imageSource) || islogical(imageSource))
        options.WkspaceSrcVarName = string(inputname(1));
    else
        % The source is a file. Hence, this name-value pair is not used
        options.WkspaceSrcVarName = "";
    end

    try
        createImageViewer(imageSource, options);
    catch ME
        error(message("images:imageViewer:imageViewerFailed", ME.message));
    end
end

function [imageSource, options] = parseInputs(imageSource, options)
    arguments
        imageSource {mustBeSource} = []

        options.DisplayRange ...
                    {mustBeDisplayRange(options.DisplayRange)}

        options.InitialMagnification ...
                {mustBeInitMag(options.InitialMagnification)}

        options.Interpolation (1, 1) string { mustBeMember( ...
            options.Interpolation, ["nearest", "bilinear"] ) }

        options.Colormap (:, 3) {mustBeNumeric(options.Colormap)}
    end
end

function checkIfImtoolStyleInputs(varargin)
    % Check if the function has been called with imtool style inputs i.e.:
    % imageViewer(I, cmap)
    % Generate an informative error if this is the case.

    if (numel(varargin) < 2) || ~isnumeric(varargin{2})
        return;
    end

    secondArg = varargin{2};

    if ismatrix(secondArg) && size(secondArg, 2) == 3
        error(message("images:imageViewer:cmapNotPositional"));
    end

    if isempty(secondArg) || (numel(secondArg) == 2)
        error(message("images:imageViewer:dispRangeNotPositional"));
    end
end

function createImageViewer(imageSource, options)

    if isfield(options, "DisplayRange")
        images.internal.app.viewer.ImageViewer( imageSource, ...
                    UserColormap=options.Colormap, ...
                    DisplayRange=options.DisplayRange, ...
                    InitialMagnification=options.InitialMagnification, ...
                    Interpolation=options.Interpolation, ...
                    IsReadOnlyFirstFrame=true, ...
                    WkspaceSrcVarName=options.WkspaceSrcVarName );
    else
        images.internal.app.viewer.ImageViewer( imageSource, ...
                    UserColormap=options.Colormap, ...
                    InitialMagnification=options.InitialMagnification, ...
                    Interpolation=options.Interpolation, ...
                    IsReadOnlyFirstFrame=true, ...
                    WkspaceSrcVarName=options.WkspaceSrcVarName );
    end
end

function mustBeSource(src)
    % Validate the source

    if ischar(src) || isstring(src)
        validateattributes( src, ["char", "string"], "scalartext", ...
                            "imageViewer", "source" );
        if src == ""
            error(getString(message("images:imageViewer:nonEmptyFileName")));
        end
    else
        validateattributes( src, ["numeric", "logical"], "3d", ...
                            "imageViewer", "source" );

        if ~ismember(size(src, 3), [1 3])
            error(getString(message("images:imageViewer:input1or3Channels")));
        end

        if islogical(src) && (size(src, 3) ~= 1)
            error(getString(message("images:imageViewer:logicalOneChannel")));
        end
    end
end


function mustBeDisplayRange(range)
    validateattributes(range, "numeric", {});

    if ~isempty(range)
        validateattributes( range, "numeric", ...
                {"row", "numel", 2, "nondecreasing", "real", "finite"}, ...
                "imageViewer", "DisplayRange" );
    end
end

function mustBeInitMag(initMag)
    if ischar(initMag) || isstring(initMag)
        validatestring(initMag, "fit");
    else
        validateattributes( initMag, "numeric", ...
                ["scalar", "positive", "real", "finite"], ...
                "imageViewer", "InitialMagnification" );
    end
end

function mustBeValidOptionsForImageType(options, imageSource)
    % Ensure that name-value pairs specified are applicable for the image
    % type

    if isempty(imageSource)
        return;
    end

    isCmap = isfield(options, "Colormap");
    isRange = isfield(options, "DisplayRange");
    if isCmap || isRange
        % These name-value pairs are only applicable for single channel
        % images
        loader = images.internal.app.viewer.ImageLoader.create(imageSource);
        img = readImage(loader);
        
        if size(img, 3) ~= 1
            % Throw an error
            optionName = string.empty();
            if isCmap
                optionName = "Colormap";
            end
            if isRange
                optionName = [optionName; "DisplayRange"];
            end
            optionNameStr = strjoin(optionName, ",");

            error( message( "images:imageViewer:optionOnlyFor1channel", ...
                                optionNameStr ) );
        end

    end
end
%   Copyright 2023 The MathWorks, Inc.
