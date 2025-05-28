function displayErrorDialog(app, msg)
% Helper function to display error messages when using SAM errors out

    import images.internal.app.segmenter.image.web.getMessageString;

    if app.Visible
        origBusyState = app.Busy;
        app.Busy = false;
        okStr = getString(message("images:commonUIString:ok"));
        

        errorMsg = string(getMessageString("samErrorDlgPrefixText")) + msg;
        
        % The output argument is need to ensure the dialog blocks execution
        outStr = uiconfirm( app, errorMsg, ...
                            getMessageString("appName"), ...
                            Options={okStr}, ...
                            DefaultOption=okStr, ...
                            CancelOption=okStr, ...
                            Interpreter="html", ...
                            Icon="error" );
        app.Busy = origBusyState;
    end
end

% Copyright 2024 The MathWorks, Inc.