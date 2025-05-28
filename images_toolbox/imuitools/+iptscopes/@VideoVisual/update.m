function update(this)
%UPDATE   Update the video display.

%   Copyright 2007-2018 The MathWorks, Inc.

% Cache the new frame data
source = this.Application.DataSource;

% We only show the last frame and the time is irrelevant.
values = getRawData(source);

if isempty(values)
    return;
end

% Perform the conversion on the raw data.
conversionFcn = this.ColorMap.ConversionFcn;
if ~isempty(conversionFcn)
    [str, id] = lastwarn;
    for indx = 1:numel(values)
        values{indx} = conversionFcn(values{indx});
    end
    lastwarn(str, id);
end

values = cat(3, values{:});

sizeNewFrame = size(values);

% Update the image object's CData and make sure its visible.
hImage = this.Image;



% Check if the dimensions of the signal has changed
if isempty(this.OldDimensions) || isequal(sizeNewFrame,this.OldDimensions)
    set(hImage, 'CData', values);
else
    %*** g513285: Add support for variable-sized signals for Video Viewers ******
    sizePrevFrame = this.OldDimensions;
    
    % R4:  images cannot change in their third dimension.
    % We need to add this constraint only for video viewer blocks
    % We should move this check somewhere else (g582040)
    if strcmp(this.Application.getAppName,'Video Viewer')
        checkDimConsistency(this, sizeNewFrame, sizePrevFrame, source);
    end
    
    % Get the extension information. To be used later to determine if in
    % FitToView mode. It's possible that the extension be added or removed
    % after the Video Visual was initialized in which case the visual's
    % 'Extension' property needs to be reset.
    if ~isa(this.Extension,'iptscopes.ImageNavigationTool')
        ext = this.Application.getExtInst('Tools:Image Navigation Tools');
        this.Extension = ext;
    else
        ext = this.Extension;
    end
        
    % If the image size has changed, use replaceImage API function to
    % update the scrollpanel.
    sp_api = iptgetapi(this.ScrollPanel);
    sp_api.replaceImage(values, ...
        'ColorMap',     this.ColorMap.Map, ...
        'PreserveView', true);
    if  isa(ext,'iptscopes.ImageNavigationTool') && strcmp(ext.Mode,'FitToView')
        % Reset the magnification if in FitToView mode
        sp_api.setMagnification(sp_api.findFitMag());
    end

end

% Cache the current dimensions
this.OldDimensions= sizeNewFrame;

end

% -------------------------------------------------------------------------
function checkDimConsistency(this, sizeNewFrame, sizePrevFrame, source)
% Do not throw an exception if the incoming or previous image happens to be
% an empty image

    % Need to change OldDimensions that are initially set to 1x1 to the
    % new appropraite value
    % Note ImageType does not support varying Dimensions
	dataType = getDataTypes(source, 1);
    dims =[sizeNewFrame(1),sizeNewFrame(2),3];
    if numel(sizeNewFrame) < 3
		if startsWith(getDataTypes(source, 1), 'Image_')
			isGrayscale = contains(dataType,'Grayscale');
			if isGrayscale
				dims = [ sizePrevFrame(1), sizePrevFrame(2) ];
                sizePrevFrame = [sizePrevFrame(1) , sizePrevFrame(2)];
			end
		else
			dims(3) = 1;
		end
    end
    this.OldDimensions = dims;

if sizePrevFrame(1) ~=0 && sizeNewFrame(1) ~=0
    if  ~(length(sizeNewFrame) == length(sizePrevFrame)) ...
            || (length(sizePrevFrame) == 3 && ~(sizePrevFrame(3)==sizeNewFrame(3)))
        % Cache the current image size before throwing an error
        this.OldDimensions= sizeNewFrame;
        msgObj = message('vision:block:videoBandsSzChanged',this.Application.getAppName);
        msg = msgObj.getString;
        id = msgObj.Identifier;
        exception = MException(id, msg);
        throw(exception);
    end
end

end
% [EOF]
