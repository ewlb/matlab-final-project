function hViewer = viewer3d(varargin)
%

% Copyright 2022-2024 The MathWorks, Inc.

[parent,remainingInputs] = images.ui.graphics.internal.utilities.processParent(varargin{:});

if isempty(parent)
    parent = images.ui.graphics.internal.utilities.getPrewarmedFigure([]);
end

hViewer = images.ui.graphics.Viewer("Parent",parent,remainingInputs{:});

end