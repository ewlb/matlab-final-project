classdef AutoSegConfigUI < images.internal.app.utilities.CloseDialog
% Class creates the Parent UI Container into which controls needed to
% configure Automatic Segmentation using SAM are populated.

    properties(Access=public, Dependent)
        ImageSize
    end

    properties(GetAccess=public, SetAccess=private, Dependent)
        AutoSegParams
    end

    properties(GetAccess=public, SetAccess=private)
        ParamControls images.internal.app.utilities.semiautoseg.SAMAutoSegParamsUIControls = ...
                            images.internal.app.utilities.semiautoseg.SAMAutoSegParamsUIControls.empty()
    end

    events
        ParamsDialogClosing
        UpdateSegmentation
    end

    properties(Access=private)
        ParamPanel matlab.ui.container.Panel = ...
                                matlab.ui.container.Panel.empty()

        HelpButton matlab.ui.control.Button = ...
                                matlab.ui.control.Button.empty()
    end

    properties(Access=private, Constant)
        DialogSize = [450 475];
    end

    methods(Access=public)
        function obj = AutoSegConfigUI(dialogStartLoc)
            import images.internal.app.segmenter.image.web.getMessageString;

            obj@images.internal.app.utilities.CloseDialog( dialogStartLoc, ...
                                    getMessageString("samConfigParamsDialogTitle") );
            obj.Size = obj.DialogSize;
            
            create(obj);

            % Add a Help Button
            helpBtnPos = [ obj.FigureHandle.Position(3) - ...
                                (obj.Close.Position(1) + obj.Close.Position(3)) ...
                           obj.Close.Position(2) obj.Close.Position(3:4)];
            obj.HelpButton = uibutton( obj.FigureHandle, "push", ...
                                Tag="HelpButton", ...
                                Text=string(message("images:commonUIString:help")), ...
                                Icon="question", ...
                                Position=helpBtnPos, ...
                                ButtonPushedFcn=@(~, ~) reactToHelpButton(obj) );

            obj.FigureHandle.Tag = "SAMAutoSegConfigFig";
            obj.FigureHandle.WindowStyle = "normal";
            obj.FigureHandle.CloseRequestFcn = @(~, ~) reactToFigCloseReq(obj);

            panelYPos = obj.Close.Position(2) + obj.ButtonSize(2) + ...
                                                        obj.ButtonSpace;
            panelWidth = obj.FigureHandle.Position(3);
            panelHeight = obj.FigureHandle.Position(4) - panelYPos;
            obj.ParamPanel = uipanel( obj.FigureHandle, ...
                                Position=[1 panelYPos panelWidth panelHeight], ...
                                BorderType="none", ...
                                Scrollable="on", ...
                                Tag="ParamsPanel" );

            obj.ParamControls = images.internal.app.utilities.semiautoseg.SAMAutoSegParamsUIControls(obj.ParamPanel);
            addlistener( obj.ParamControls, "UpdateSegmentationReq", ...
                            @(~, evt) reactToUpdateSegReq(obj, evt) );
            resetUI(obj);

            obj.FigureHandle.Visible = "on";
        end

        function enableControls(obj)
            obj.Close.Enable = "on";
            enableControls(obj.ParamControls);
        end

        function disableControls(obj)
            obj.Close.Enable = "off";
            disableControls(obj.ParamControls);
        end

        function resetUI(obj)
            resetControls(obj.ParamControls);
        end

        function delete(obj)
            delete(obj.FigureHandle);
        end
    end

    methods(Access=public, Static)
        function hui = createUI(app, imageSize)
            import images.internal.app.segmenter.image.web.sam.AutoSegConfigUI;

            dlgLoc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(app);
            hui = AutoSegConfigUI(dlgLoc(1:2));
            hui.ImageSize = imageSize;
        end
    end

    % Setters/Getters
    methods
        function sz = get.ImageSize(obj)
            sz = obj.ParamControls.ImageSize;
        end

        function set.ImageSize(obj, sz)
            obj.ParamControls.ImageSize = sz;
        end

        function params = get.AutoSegParams(obj)
            params = obj.ParamControls.AutoSegParams;
        end
    end

    methods(Access=protected)
        function keyPress(~, ~)
            % Do nothing for now
        end
    end

    methods(Access=private)
        function reactToFigCloseReq(obj)
            obj.FigureHandle.Visible = "off";

            notify(obj, "ParamsDialogClosing");
        end

        function reactToUpdateSegReq(obj, evt)
            evtData = images.internal.app.utilities.semiautoseg.events.ToolstripEventData(evt.Data);
            notify(obj, "UpdateSegmentation", evtData);
        end

        function reactToHelpButton(~)
            doc("imsegsam");
        end
    end
end

% Copyright 2024 The MathWorks, Inc.