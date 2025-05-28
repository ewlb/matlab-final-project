classdef LowContrastImageUI < images.internal.app.utilities.OkCancelDialog
% Dialog that allows user to determine the correct action to be taken if
% the image being loaded has low-contrast
%
% The dialog layout is below:
% <UILABEL: Message about image being low contrast>
% <UIBUTTON:YES>    <UIBUTTON:NO>
% <UICHECKBOX: Prompt user to remember the choice made>

%   Copyright 2023, The MathWorks, Inc.

    properties(GetAccess=public, SetAccess=private)
        IsPrompt (1, 1) logical = false;
        IsScaleToSource (1, 1) logical = false;
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
        function obj = LowContrastImageUI(loc)
            obj@images.internal.app.utilities.OkCancelDialog( ...
                loc, ...
                getString(message("images:imageViewer:appTitle")) );

            obj.Size = obj.DialogSize;

            create(obj);
            createDialog(obj);
        end
    end

    methods(Access=private)
        function createDialog(obj)
            % Create the UI elements for the Dialog

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
                     Text=getString(message("images:imageViewer:adjustContrastDlgMessage")), ...
                     WordWrap=true, ...
                     Position=labelPos, ...
                     VerticalAlignment="top", ...
                     FontSize=14, ...
                     Tag="MessageLabel" );

        end
    end

    methods(Access=protected)
        function okClicked(obj)
            obj.IsScaleToSource = true;

            okClicked@images.internal.app.utilities.OkCancelDialog(obj);
        end

        function cancelClicked(obj)
            obj.IsScaleToSource = false;

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