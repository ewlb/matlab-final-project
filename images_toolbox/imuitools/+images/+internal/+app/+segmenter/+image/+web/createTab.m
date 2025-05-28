function hTab = createTab(tabGroup, resourceKeyword, varargin)
    %

    % Copyright 2015-2019 The MathWorks, Inc.

if (nargin == 2)
    hTab = tabGroup.addTab(...
        images.internal.app.segmenter.image.web.getMessageString(resourceKeyword));
else
    hTab = matlab.ui.internal.toolstrip.Tab(...
        images.internal.app.segmenter.image.web.getMessageString(resourceKeyword));
    tabGroup.add(hTab, varargin{:});
end

end