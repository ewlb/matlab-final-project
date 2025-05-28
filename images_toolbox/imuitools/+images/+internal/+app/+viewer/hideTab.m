function hideTab(tabGroup, tab)
% Helper function that hides the specific tab from the tab group

%   Copyright 2023 The Mathworks, Inc.

    if ~isempty(tabGroup.contains(tab.Tag))
        tabGroup.remove(tab);
    end
end