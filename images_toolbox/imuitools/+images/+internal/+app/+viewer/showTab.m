function showTab(tabGroup, tab, idx)
% Helper function that displays a tab in the specific location in the tab
% group

%   Copyright 2023 The Mathworks, Inc.
    if isempty(tabGroup.contains(tab.Tag))
        % If there are N tabs in the tab group, the next idx to add must
        % be between [1, N+1]. If idx is > N+1, the tab is not added to the
        % group even though it is displayed. This code below is to guard
        % against this behaviour.
        while idx >= 1
            tabGroup.add(tab, idx);
            if ~isempty(contains(tabGroup, tab.Tag))
                break;
            end
            idx = idx - 1;
        end
    end
end
