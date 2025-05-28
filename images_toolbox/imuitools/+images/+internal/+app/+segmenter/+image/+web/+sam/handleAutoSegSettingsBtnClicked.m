function handleAutoSegSettingsBtnClicked(ui)
% Helper function that handles the Automatic Segmentation Configuration UI

    if ui.FigureHandle.Visible == "off"
        % Settings dialog has been "closed". "Re-open" it.
        ui.FigureHandle.Visible = "on";
        focus(ui.FigureHandle);
    else
        % Settings Dialog is open but not visible. Bring it into
        % focus
        focus(ui.FigureHandle);
    end

end

% Copyright 2024 The MathWorks, Inc.