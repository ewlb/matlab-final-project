function keyPressCallback(hBrowser,hKeyPressEvt,deleteTF)
% Implements a default set of handlers for key board events

% Copyright 2020-2021 The MathWorks, Inc.

if nargin < 3
    deleteTF = false;
else
    assert(islogical(deleteTF) && isscalar(deleteTF),'Argument to control delete key press must be a scalar logical');
end

if ~isempty(hKeyPressEvt.Modifier)...
        && (any(strcmp(hKeyPressEvt.Modifier,'control'))...
        ||any(strcmp(hKeyPressEvt.Modifier,'command')))
    if strcmpi(hKeyPressEvt.Key,'a')
        % Only ctrl+a is supported with CTRL modifier
        selectAll = 1:hBrowser.NumImages;
        hBrowser.select(selectAll);
    end
    return;
end


curAnchor = hBrowser.LastSelected;
newAnchor = [];

switch(hKeyPressEvt.Key)
    
    case 'pageup'
        if isempty(curAnchor)
            hBrowser.pageUp();
        else
            newAnchor = max(1, curAnchor-hBrowser.NumVisibleColumns*hBrowser.NumVisibleRows);
        end
    case 'pagedown'
        if isempty(curAnchor)
            hBrowser.pageDown();
        else
            newAnchor = min(curAnchor+hBrowser.NumVisibleColumns*hBrowser.NumVisibleRows, hBrowser.NumImages);
        end
    case 'home'
        if isempty(curAnchor)
            hBrowser.top();
        else
            newAnchor = 1;
        end
    case 'end'
        if isempty(curAnchor)
            hBrowser.bottom();
        else
            newAnchor = hBrowser.NumImages;
        end
    case 'downarrow'
        if isempty(curAnchor)
            hBrowser.down();
        else
            if hBrowser.Layout == "row"
                newAnchor = min(curAnchor+1, hBrowser.NumImages);
            else
                newAnchor = min(curAnchor+hBrowser.NumVisibleColumns, hBrowser.NumImages);
            end
        end
    case 'uparrow'
        if isempty(curAnchor)
            hBrowser.up();
        else
            if hBrowser.Layout == "row"
                newAnchor = max(1, curAnchor-1);
            else
                newAnchor = max(1, curAnchor-hBrowser.NumVisibleColumns);
            end
        end
    case 'rightarrow'
        if ~isempty(curAnchor)
            newAnchor = min(curAnchor+1, hBrowser.NumImages);
        end
    case 'leftarrow'
        if ~isempty(curAnchor)
            newAnchor = max(1, curAnchor-1);
        end
        
    case {'delete', 'backspace'}
        if deleteTF
            if ~isempty(curAnchor)
                newAnchor = max(hBrowser.Selected);
                newAnchor = max(1, newAnchor-numel(hBrowser.Selected)+1);
            end
            hBrowser.removeSelected();
            if ~isempty(curAnchor) && isvalid(hBrowser)
                newAnchor = min(newAnchor, hBrowser.NumImages);
            else
                newAnchor = 0;
            end
        end
        
    case 'return'
        notify(hBrowser,...
            'OpenSelection',...
            images.internal.app.browser.events.OpenSelectionEventData(hBrowser.Selected));
        
end

if ~isempty(newAnchor) && newAnchor~=0
    % Update selection
    if strcmp(hKeyPressEvt.Modifier, 'shift')
        if newAnchor<curAnchor
            newSelection = curAnchor:-1:newAnchor;
        else
            newSelection = curAnchor:newAnchor;
        end
        % Add to existing selection
        newSelection = unique([hBrowser.Selected(:); newSelection(:)], 'stable');
        % Ensure newAnchor is always the last element in the selection
        % list.
        hBrowser.select(newSelection);
    else
        hBrowser.select(newAnchor);
    end
end

end

