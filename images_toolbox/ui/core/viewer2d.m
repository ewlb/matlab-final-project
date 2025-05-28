function hViewer = viewer2d(varargin)
%

% Copyright 2023-2024 The MathWorks, Inc.

[parent,remainingInputs] = images.ui.graphics.internal.utilities.processParent(varargin{:});

if isempty(parent)
    parent = images.ui.graphics.internal.utilities.getPrewarmedFigure([]);
end

hViewer = images.ui.graphics.Viewer("Parent",parent,"View","2d",...
    "Interactions",["annotate","zoom","pan"],...
    "RenderingQuality",'medium',remainingInputs{:});

end