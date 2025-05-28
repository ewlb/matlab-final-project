classdef ImageProcessingToolboxPreferences < handle
% Class that handles the IPT Preferences for Javascript Desktop

% Copyright 2022-2023 The MathWorks, Inc.

    properties (Access = public)
        UIFigure
    end

    properties (Access = private)
        % UI Controls

        % IMTOOL Section
        ChkBoxOpenOverview

        % Initial IMTOOL Magnification
        RadioAdaptive = [];
        RadioFitWindow = [];
        RadioPrefPct = [];
        EditPrefPct = [];

        % Processor Optimization Section
        ChkBoxHWOptim = [];
    end

    properties(Access=private, Constant)
        Width = 500;
        Margin = 10;
        TextElemsHeight = 20;
        TextElemsWidth = 150;
        VertRadioButtonSpacing = 5;
        PrefPctEditWidth = 50;

        ImtoolOverviewHeight = 40;
        ImtoolInitMagHeight = 120;

        ProcOptimPanelHeight = 60;
    end

    methods (Access = public)
        function obj = ImageProcessingToolboxPreferences
            % Construct the uifigure and populate it using iptgetpref.
            createPanel(obj);
        end
        
        function delete(obj)
            delete(obj.UIFigure);
        end
        
        function result = commit(obj)
            % Interact with the Model.
            
            % Set all values whether changed or not.
            try
                iptsetpref('ImtoolStartWithOverview', obj.ChkBoxOpenOverview.Value)
                
                if obj.RadioAdaptive.Value
                    iptsetpref('ImtoolInitialMagnification', 'adaptive')
                elseif obj.RadioFitWindow.Value
                    iptsetpref('ImtoolInitialMagnification', 'fit')
                else
                    iptsetpref('ImtoolInitialMagnification', ...
                        obj.EditPrefPct.Value)
                end
                
                iptsetpref('UseIPPL', obj.ChkBoxHWOptim.Value)
                
                result = true;
            catch ME %#ok<NASGU>
                result = false;
            end
        end
    end
    
    methods (Access = private)
        function createPanel(obj)
            obj.UIFigure = uifigure;
            obj.UIFigure.AutoResizeChildren = "off";
                        
            % High-level layout: Create a grid layout for the two sections
            mainUG = uigridlayout(obj.UIFigure, [2 1]);
            mainUG.Scrollable = "on";
            imtoolPanelHeight = obj.ImtoolOverviewHeight + obj.ImtoolInitMagHeight + 50;
            mainUG.RowHeight = {imtoolPanelHeight, obj.ProcOptimPanelHeight}; 
            mainUG.ColumnWidth = {obj.Width};

            % "Image Tool (IMTOOL) Display" section
            imtoolPanel = uipanel( mainUG, ...
                            Title=string(message('images:preferencesIPT:imtoolDisplay')), ...
                            FontWeight="bold", ...
                            Tag = "ImtoolPanel" ); 
            imtoolPanel.AutoResizeChildren = "off";
            imtoolPanel.Layout.Row = 1;
            imtoolPanel.Layout.Column = 1;

            % Add a grid layout to manage the IMTOOL Section
            imtoolPanelUG = uigridlayout(imtoolPanel, [2 1]);
            imtoolPanelUG.RowHeight = {obj.ImtoolOverviewHeight obj.ImtoolInitMagHeight};
            imtoolPanelUG.ColumnWidth = {'1x'};

            % Add the Open Overview checkbox
            obj.ChkBoxOpenOverview = uicheckbox( imtoolPanelUG, ...
                                        Text=string(message('images:preferencesIPT:overview')), ...
                                        Tag="ChkBoxOpenOverview" );
            obj.ChkBoxOpenOverview.Layout.Row = 1;
            obj.ChkBoxOpenOverview.Layout.Column = 1;

            % Add the Initial Magnification button group
            initMagBtnGroup = uibuttongroup( imtoolPanelUG, ...
                                Title=string(message('images:preferencesIPT:initMag')), ...
                                Tag="InitMagBtnGroup" );
            initMagBtnGroup.AutoResizeChildren="off";
            initMagBtnGroup.Layout.Row = 2;
            initMagBtnGroup.Layout.Column = 1;
            initMagBtnGroup.SizeChangedFcn = @obj.initMagBtnGrpSizeChgFcn;
            initMagBtnGroup.SelectionChangedFcn = @(src,evt) obj.initMagGroupChanged(src, evt);

            % Add the buttons bottom up
            pctPos = [ obj.Margin obj.Margin obj.TextElemsWidth-50 obj.TextElemsHeight ];

            editPos = [ pctPos(1)+pctPos(3)+obj.Margin ...
                        obj.Margin ...
                        obj.PrefPctEditWidth obj.TextElemsHeight ];

            fitPos = [ pctPos(1) ...
                       pctPos(2)+pctPos(4)+obj.VertRadioButtonSpacing ...
                       pctPos(3) obj.TextElemsHeight ];

            bgpos = initMagBtnGroup.Position;
            adaptPos = [ fitPos(1) ...
                         fitPos(2)+fitPos(4)+obj.VertRadioButtonSpacing ...
                         bgpos(3)-2*obj.Margin obj.TextElemsHeight ];

            obj.RadioAdaptive = uiradiobutton( initMagBtnGroup, ...
                                    Text=string(message('images:preferencesIPT:adaptive')), ...
                                    Position=adaptPos, ...
                                    Tag="RadioAdaptive" );

            obj.RadioFitWindow = uiradiobutton( initMagBtnGroup, ...
                                    Text=string(message('images:preferencesIPT:fit')), ...
                                    Position=fitPos, ...
                                    Tag="RadioFitWindow" );

            obj.RadioPrefPct = uiradiobutton( initMagBtnGroup, ...
                                    Text=string(message('images:preferencesIPT:percentage')), ...
                                    Position=pctPos, ...
                                    Tag="RadioPrefPct" );
            
            % Add the Edit field
            obj.EditPrefPct = uieditfield( initMagBtnGroup, "numeric", ...
                                           Position=editPos, ...
                                           Tag="EditPrefPct" );
            obj.EditPrefPct.ValueDisplayFormat = '%3.0f%%';
            obj.EditPrefPct.Value = 100;
            obj.EditPrefPct.Limits = [0 inf];

            % "Processor Optimizations" section (not available on maca64)
            if computer("arch")~="maca64"
                procOptimPanel = uipanel( mainUG, ...
                    Title=string(message('images:preferencesIPT:hwOptimizations')), ...
                    FontWeight="bold", ...
                    Tag="ProcOptimPanel" );
                procOptimPanel.AutoResizeChildren = "off";
                procOptimPanel.Layout.Row = 2;
                procOptimPanel.Layout.Column = 1;

                procOptimPanelUG = uigridlayout(procOptimPanel, [1 1]);
                procOptimPanelUG.RowHeight = {obj.TextElemsHeight};
                procOptimPanelUG.ColumnWidth = {'1x'};
                obj.ChkBoxHWOptim = uicheckbox( procOptimPanelUG, ...
                    Text=string(message('images:preferencesIPT:enableOptimizations')), ...
                    Tag="ChkBoxHWOptim" );
                obj.ChkBoxHWOptim.Layout.Row = 1;
                obj.ChkBoxHWOptim.Layout.Column = 1;
            end

            setViewValues(obj);
        end

        function setViewValues(obj)
            prefs = iptgetpref();  % Interact with Model.
            
            obj.ChkBoxOpenOverview.Value = prefs.ImtoolStartWithOverview;
            
            switch (prefs.ImtoolInitialMagnification)
                case 'adaptive'
                    obj.RadioAdaptive.Value = true;
                    obj.EditPrefPct.Enable = false;
                case 'fit'
                    obj.RadioFitWindow.Value = true;
                    obj.EditPrefPct.Enable = false;
                otherwise
                    obj.RadioPrefPct.Value = true;
                    obj.EditPrefPct.Value = prefs.ImtoolInitialMagnification;
                    obj.EditPrefPct.Enable = true;
            end
            
            obj.ChkBoxHWOptim.Value = prefs.UseIPPL;
        end
        
        function initMagGroupChanged(obj, ~, evt)
            obj.EditPrefPct.Enable = evt.NewValue.Tag == "RadioPrefPct";
        end

        function initMagBtnGrpSizeChgFcn(obj, src, ~)
            % Size changed function for the Initial Mag Button Group. This
            % is needed to accurately position the uilabel that follows the
            % edit field.
            bgpos = src.Position;
            fitPos = obj.RadioFitWindow.Position;

            adaptPos = [ fitPos(1) ...
                         fitPos(2)+fitPos(4)+obj.VertRadioButtonSpacing ...
                         bgpos(3)-2*obj.Margin obj.TextElemsHeight ];

            obj.RadioAdaptive.Position = adaptPos;
        end
    end
end