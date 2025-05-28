function [useGPU, isBtnEnabled] = canUseGPU(app)
% Helper function that checks if SAM can use the GPU for its operations

    import images.internal.app.segmenter.image.web.sam.CanUseGPUDialog;
    import imageslib.internal.app.utilities.ScreenUtilities.getToolCenter;
    import images.internal.app.segmenter.image.web.getMessageString;

    s = settings;
    sGpuAction = s.images.imagesegmentertool.SAMUseGPU.ActiveValue;

    isGpuAvail = canUseGPU();

    % The Use GPU button will be enabled depending on whether a usable GPU
    % is available for the user
    isBtnEnabled = isGpuAvail;

    switch(sGpuAction)
        case "no"
            % User does not want to use GPU
            % User has masked Dialog as "Do not show"
            % Hence, app will not use GPU.
            useGPU = false;

        case "yes"
            % User wants to use GPU
            % User has masked Dialog as "Do not show"
            useGPU = isGpuAvail;
            if ~isGpuAvail
                % GPU is in a bad state. Let user know about this and
                % continue using the CPU
                origBusyState = app.Busy;
                app.Busy = false;
                okStr = getString(message("images:commonUIString:ok"));
                msg = getMessageString("samGPUNotAvailable");
                if app.Visible
                    outStr = uiconfirm( app, msg, ...
                                    getMessageString("appName"), ...
                                    Options={okStr}, ...
                                    DefaultOption=okStr, ...
                                    CancelOption=okStr, ...
                                    Interpreter="html", ...
                                    Icon="warning" );
                end
                s.images.imagesegmentertool.SAMUseGPU.PersonalValue = "prompt";
                app.Busy = origBusyState;
            end

        case "prompt"
            % User wants to be prompted for GPU use
            if isGpuAvail
                % Prompt user for choice only if the GPU is available
                dialogLoc = getToolCenter(app);

                dlg = CanUseGPUDialog(dialogLoc(1:2));
        
                uiwait(dlg.FigureHandle);
                
                useGPU = dlg.IsUseGPU;

                if ~dlg.IsPrompt
                    if useGPU
                        val = "yes";
                    else
                        val = "no";
                    end
                else
                    val = "prompt";
                end
                s.images.imagesegmentertool.SAMUseGPU.PersonalValue = val;
            else
                useGPU = false;
            end

        otherwise
            assert(false, "Invalid GPU Action Setting");
    end

end

%   Copyright 2023-2024, The MathWorks Inc.