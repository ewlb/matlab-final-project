classdef CanUseGPUDialog < images.internal.app.utilities.OkCancelDialog
% Dialog that allows users to select if SAM needs to be performed on a GPU
%
% The dialog layout is below:
% <UILABEL: Message about GPU being available>
% <UIBUTTON:YES>    <UIBUTTON:NO>
% <UICHECKBOX: Prompt user to remember the choice made>

%   Copyright 2023-2024, The MathWorks, Inc.

    properties(GetAccess=public, SetAccess=private)
        IsPrompt (1, 1) logical = false;
        IsUseGPU (1, 1) logical = false;
    end

    properties(Access=private)
        YesBtn
        NoBtn
        DoNotShowChkBox
    end

    properties(Access=private, Constant)
        DialogSize = [350 200];
        
        HorizMargin = 5;
        VertMargin = 5;

        InterElemSpacing = 20;

        ChkBoxHeight = 20;
    end

    methods(Access=public)
        function obj = CanUseGPUDialog(loc)
            import images.internal.app.segmenter.image.web.getMessageString;
            obj@images.internal.app.utilities.OkCancelDialog( ...
                loc, ...
                getMessageString("appName") );

            obj.Size = obj.DialogSize;

            create(obj);
            createDialog(obj);
        end
    end

    methods(Access=private)
        function createDialog(obj)
            % Create the UI elements for the Dialog
            import images.internal.app.segmenter.image.web.getMessageString;

            % Create the Checkbox
            chkBoxPos = [ obj.HorizMargin obj.VertMargin ...
                          obj.Size(1)-2*obj.HorizMargin ...
                          obj.ChkBoxHeight ];
            obj.DoNotShowChkBox = uicheckbox( obj.FigureHandle, ...
                                    Tag="RemindChkBox", ...
                                    Text=getString(message("images:commonUIString:rememberChoiceDontShowAgain")), ...
                                    WordWrap=true, ...
                                    Value=true, ...
                                    Position=chkBoxPos, ...
                                    ValueChangedFcn=@(~, evt) reactToChkBoxChecked(obj, evt) );

            % Reposition the buttons
            obj.Ok.Text = getString(message("images:commonUIString:yes"));
            obj.Ok.Position(2) = chkBoxPos(2)+chkBoxPos(4)+obj.InterElemSpacing;

            obj.Cancel.Text = getString(message("images:commonUIString:no"));
            obj.Cancel.Position(2) = chkBoxPos(2)+chkBoxPos(4)+obj.InterElemSpacing;

            % Message Label
            labelPos = [ obj.HorizMargin ...
                         obj.Ok.Position(2)+obj.Ok.Position(4)+obj.InterElemSpacing ...
                         obj.Size(1) - 2*obj.HorizMargin ...
                         obj.Size(2) - 2*obj.VertMargin - obj.ChkBoxHeight - ...
                         2*obj.InterElemSpacing - obj.ButtonSize(2) ];
            uilabel( obj.FigureHandle, ...
                     Text=getMessageString("samUseGPU"), ...
                     WordWrap=true, ...
                     Position=labelPos, ...
                     VerticalAlignment="top", ...
                     FontSize=14, ...
                     Tag="MessageLabel" );

        end
    end

    methods(Access=protected)
        function okClicked(obj)
            obj.IsUseGPU = true;

            okClicked@images.internal.app.utilities.OkCancelDialog(obj);
        end

        function cancelClicked(obj)
            obj.IsUseGPU = false;

            cancelClicked@images.internal.app.utilities.OkCancelDialog(obj);
        end
    end

    methods(Access=private)
        function reactToChkBoxChecked(obj, evt)
            % Checkbox CHECKED means do not prompt
            obj.IsPrompt = ~evt.Value;  
        end
    end

end