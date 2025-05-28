function hImage = imageshow(varargin)
%

% Copyright 2024 The MathWorks, Inc.

[parent, remainingInputs, imageSize, isIndexed, validOverlap] = processInputs(varargin{:});

if isempty(parent)
    % No parent provided
    fig = images.ui.graphics.internal.utilities.getPrewarmedFigure(imageSize);
    viewer = createViewer(fig,isIndexed);
    newViewer = true;
elseif isa(parent,'images.ui.graphics.Viewer')
    % Parent is an existing Viewer object
    viewer = parent;
    newViewer = false;
    % If other images are present in the viewer and no transformation is
    % applied, throw a warning. We want to encourage users to set the
    % object Data for playback and scrubbing workflows and OverlayData for
    % image overlay workflows.
    otherImages = findall(viewer,'type','image');
    if isscalar(otherImages)
        if ~validOverlap
            warning(message('images:volume:repeatedImageDisplay'));
        end
    end
else
    error(message('images:volume:invalidViewer'));
end

viewer.Busy = true;

try
    hImage = images.ui.graphics.Image(viewer, remainingInputs{:});
    if ~feature('LiveEditorRunning')
        waitfor(viewer,'Busy',false);
    end
catch ME
    if newViewer
        close(ancestor(viewer,'figure'));
    else
        viewer.Busy = false;
    end
    rethrow(ME);
end

end

function viewer = createViewer(parent,isIndexed)

viewer = viewer2d('Parent',parent);
viewer.Mode.WindowLevel.Enabled = ~isIndexed;

end

function [parent, remainingInputs, imageSize, isIndexed, validOverlap] = processInputs(varargin)
parent = gobjects(0);
remainingInputs = {};
im = []; %#ok<NASGU>
imageSize = [];
isIndexed = false;
validOverlap = false;

if ~isempty(varargin)

    if isnumeric(varargin{1}) || islogical(varargin{1}) || isa(varargin{1},'blockedImage')
        im = varargin{1};
        varargin(1) = [];
    elseif ischar(varargin{1}) || isstring(varargin{1})
        [im,cmap] = images.internal.app.utilities.readAllIPTFormats(varargin{1});
        varargin(1) = [];
        if ~isempty(cmap)
            if size(cmap,1) > 256
                error(message('images:volume:invalidIndexedImage'));
            end
            varargin = [{'Interpolation'},{'nearest'},{'Colormap'},{cmap},{'DisplayRange'},{[0,size(cmap,1)-1]},varargin];
            isIndexed = true;
        end
    elseif isa(varargin{1},"categorical")
        error(message('images:volume:categoricalData'));
    else
        error(message('images:volume:requireImageData'));
    end

    % Specify the image position when possible for local desktop to display
    % an appropriate sized figure
    if matlab.internal.capability.Capability.isSupported(matlab.internal.capability.Capability.LocalClient)
        if isnumeric(im) || islogical(im)
            imageSize = size(im,1,2);
        end
    end

    if isempty(varargin)
        remainingInputs = {'Data',im};
        return;
    end

    [parent,remainingInputs] = images.ui.graphics.internal.utilities.processParent(varargin{:});

    % Add Data to inputs
    remainingInputs = [remainingInputs, {'Data',im}];

    % Find AlphaData and set it last
    alphaDataIndices = find(cellfun(@(x) startsWith(x, "AlphaData", 'IgnoreCase', true), remainingInputs(1:2:end)));
    if ~isempty(alphaDataIndices)
        alphaData = remainingInputs{alphaDataIndices(end) * 2};
        remainingInputs([alphaDataIndices * 2, alphaDataIndices * 2 - 1]) = [];
        remainingInputs = [remainingInputs, {'AlphaData',alphaData}];
    end

    % Find transformation
    tformIndices = find(cellfun(@(x) startsWith(x, "Transformation", 'IgnoreCase', true), remainingInputs(1:2:end)), 1);

    % Identify cases where users might be accidentally specifying
    % overlapping opaque images in the same scene (for example to display  
    % video frames)
    validOverlap = ~isempty(alphaDataIndices) || ~isempty(tformIndices);

    % If a user specifies a transformation, we should not try to set the
    % figure to match the image size
    if ~isempty(tformIndices)
        imageSize = [];
    end

end

end
