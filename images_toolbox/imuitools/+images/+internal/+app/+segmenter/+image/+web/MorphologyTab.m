classdef MorphologyTab < handle
    %

    % Copyright 2015-2024 The MathWorks, Inc.
    
    %%Public
    properties (GetAccess = public, SetAccess = private)
        Visible = false;
    end
    
    %%Tab Management
    properties (Access = private)
        hTab
        hApp
        hAppContainer
        hTabGroup
        hToolstrip
    end
    
    %%UI Controls
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        OperationSection
        OperationButton
        
        StrelSection
        ShapeButton
        RadiusLabel
        RadiusSpinner
        LengthLabel
        LengthSpinner
        DegreesLabel
        DegreesSpinner
        NLabel
        NComboBox
        WidthLabel
        WidthSpinner
        
        ViewSection
        ViewMgr
        
        ApplyCloseSection
        ApplyCloseMgr
        
        OpacitySliderListener
        ShowBinaryButtonListener
    end
    
    %%Algorithm
    properties
        NoOperationSelected
        OperationList = {'dilate','erode','open','close'};
        ShapeList = {'disk','diamond','line','octagon','square','rectangle'};
        ShapeIconList = {'structuringElementDisk','structuringElementDiamond','structuringElementLine','structuringElementOctagon','structuringElementSquare','structuringElementRectangle'};
        StrelCreationCommand
    end
    
    %%Public API
    methods
        function self = MorphologyTab(toolGroup, tabGroup, theToolstrip, theApp, varargin)

            if (nargin == 1)
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup,'morphologyTab');
            else
                self.hTab = images.internal.app.segmenter.image.web.createTab(tabGroup,'morphologyTab', varargin{:});
            end

            self.hAppContainer = toolGroup;
            self.hTabGroup = tabGroup;
            self.hToolstrip = theToolstrip;
            self.hApp = theApp;
            
            self.layoutTab();
        end
        
        function show(self)
            if (~self.isVisible())
                self.hTabGroup.add(self.hTab)
            end
            
            self.hApp.showLegend()
            self.makeActive()
            self.Visible = true;
        end
        
        function hide(self)
            self.hApp.hideLegend()
            self.hTabGroup.remove(self.hTab)
            self.Visible = false;
        end
        
        function makeActive(self)
            self.hTabGroup.SelectedTab = self.hTab;
        end
        
        function setMode(self, mode)
            import images.internal.app.segmenter.image.web.AppMode;
            
            switch (mode)
                
            case {AppMode.NoMasks, ...
                  AppMode.NoImageLoaded, ...
                  AppMode.ActiveContoursNoMask}
                %If the app enters a state with no mask, make sure we set
                %the state back to unshow binary.
                if self.ViewMgr.ShowBinaryButton.Enabled
                    self.reactToUnshowBinary();
                    % This is needed to ensure that state is settled after
                    % unshow binary.
                    drawnow;
                end
                self.ViewMgr.Enabled = false;
                self.OperationButton.Enabled = false;
                self.disableStrelSection()
                
            case AppMode.MasksExist
                self.OperationButton.Enabled = true;
                self.enableStrelSection()
                self.ViewMgr.Enabled = true;
                
            case AppMode.MorphTabOpened
                self.restoreDefaults()
                self.ApplyCloseMgr.ApplyButton.Enabled = false;
                
            case AppMode.OpacityChanged
                self.reactToOpacityChange()
                
            case AppMode.ShowBinary
                self.reactToShowBinary()
                
            case AppMode.UnshowBinary
                self.reactToUnshowBinary()
                
            case AppMode.MorphImage
                self.applyMorphologicalOperation()

            otherwise
                % Many App Modes do not require any action from this tab.
            end
        end
        
        function onApply(self)
            self.hApp.commitTemporaryHistory()
            
            self.ApplyCloseMgr.ApplyButton.Enabled = false;
            
            if (maskHasRegions(self.hApp.getCurrentMask() ))
                self.hToolstrip.setMode(images.internal.app.segmenter.image.web.AppMode.MasksExist)
            else
                self.hToolstrip.setMode(images.internal.app.segmenter.image.web.AppMode.NoMasks)
            end
        end
        
        function onClose(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.hApp.clearTemporaryHistory()
            
            self.hToolstrip.showSegmentTab()
            self.hToolstrip.hideMorphologyTab()
            self.hToolstrip.setMode(AppMode.MorphologyDone);
        end
    end
    
    %%Layout
    methods (Access = private)
        function layoutTab(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            self.OperationSection   = self.hTab.addSection(getMessageString('operation'));
            self.OperationSection.Tag = 'Operation';
            self.StrelSection       = self.hTab.addSection(getMessageString('strel'));
            self.StrelSection.Tag   = 'StructuringElement';
            self.ViewSection        = self.addViewSection();
            self.ApplyCloseSection  = self.addApplyCloseSection();
            
            self.layoutOperationSection();
            self.layoutStrelSection();
        end
        
        function layoutOperationSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            %Operation Label
            OperationLabel = matlab.ui.internal.toolstrip.Label(getMessageString('operation'));
            OperationLabel.Description = getMessageString('operationTooltip');
            OperationLabel.Tag = 'OperationLabel';
            
            %Operation Button
            self.OperationButton = matlab.ui.internal.toolstrip.DropDownButton(getMessageString('selectOp'));
            self.OperationButton.Tag = 'btnOp';
            self.OperationButton.Description = getMessageString('operationTooltip');
            
            %Operation Dropdown
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            sub_item1 = matlab.ui.internal.toolstrip.ListItem(getMessageString(sprintf('%sOp',self.OperationList{1})));
            sub_item1.Description = getMessageString(sprintf('%sDescription',self.OperationList{1}));
            sub_item1.Tag = self.OperationList{1};
            addlistener(sub_item1, 'ItemPushed', @self.updateOperationSelection);
            
            sub_item2 = matlab.ui.internal.toolstrip.ListItem(getMessageString(sprintf('%sOp',self.OperationList{2})));
            sub_item2.Description = getMessageString(sprintf('%sDescription',self.OperationList{2}));
            sub_item2.Tag = self.OperationList{2};
            addlistener(sub_item2, 'ItemPushed', @self.updateOperationSelection);
            
            sub_item3 = matlab.ui.internal.toolstrip.ListItem(getMessageString(sprintf('%sOp',self.OperationList{3})));
            sub_item3.Description = getMessageString(sprintf('%sDescription',self.OperationList{3}));
            sub_item3.Tag = self.OperationList{3};
            addlistener(sub_item3, 'ItemPushed', @self.updateOperationSelection);
            
            sub_item4 = matlab.ui.internal.toolstrip.ListItem(getMessageString(sprintf('%sOp',self.OperationList{4})));
            sub_item4.Description = getMessageString(sprintf('%sDescription',self.OperationList{4}));
            sub_item4.Tag = self.OperationList{4};
            addlistener(sub_item4, 'ItemPushed', @self.updateOperationSelection);
            
            sub_popup.add(sub_item1);
            sub_popup.add(sub_item2);
            sub_popup.add(sub_item3);
            sub_popup.add(sub_item4);
            
            self.OperationButton.Popup = sub_popup;
            self.OperationButton.Popup.Tag = 'popupOperationList';
            
            %Layout
            c = self.OperationSection.addColumn('HorizontalAlignment','center');
            c.add(OperationLabel);
            c.add(self.OperationButton);
        end
        
        function layoutStrelSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.Icon;
            
            %Shape Button
            shapeMessageList = cellfun(@getMessageString,self.ShapeList,'UniformOutput',false);
            shapeDescList = cellfun(@(s)getMessageString(sprintf('%sDescription',s)),self.ShapeList,'UniformOutput',false);

            self.ShapeButton = matlab.ui.internal.toolstrip.DropDownButton(sprintf('%s -\n%s', getMessageString('shape'), getMessageString('disk')));
            self.ShapeButton.Icon = 'structuringElementDisk';
            self.ShapeButton.Tag = 'default';
            self.ShapeButton.Description = getMessageString('shapeTooltip');
            
            %Operation Dropdown
            sub_popup = matlab.ui.internal.toolstrip.PopupList();
            
            for idx = 1:length(self.ShapeList)
                sub_item = matlab.ui.internal.toolstrip.ListItem(shapeMessageList{idx});
                sub_item.Tag = self.ShapeList{idx};
                iconfunc = self.ShapeIconList{idx};
                sub_item.Icon = iconfunc();
                sub_item.Description = shapeDescList{idx};
                addlistener(sub_item, 'ItemPushed', @self.updateShapeSelection);
                sub_popup.add(sub_item);
            end
            
            self.ShapeButton.Popup = sub_popup;
            self.ShapeButton.Popup.Tag = 'popupShapeList';
            
            %Radius Label
            self.RadiusLabel    = matlab.ui.internal.toolstrip.Label(getMessageString('radius'));
            self.RadiusLabel.Description = getMessageString('radTooltip');
            self.RadiusLabel.Tag = "RadiusLabel";

            %Length Label
            self.LengthLabel    = matlab.ui.internal.toolstrip.Label(getMessageString('length'));
            self.LengthLabel.Description = getMessageString('lengthTooltip');
            self.LengthLabel.Tag = "LengthLabel";

            %Degrees Label
            self.DegreesLabel   = matlab.ui.internal.toolstrip.Label(getMessageString('degrees'));
            self.DegreesLabel.Description = getMessageString('degreesTooltip');
            self.DegreesLabel.Tag = "DegreesLabel";

            %N Label
            self.NLabel         = matlab.ui.internal.toolstrip.Label(getMessageString('N'));
            self.NLabel.Description = getMessageString('nTooltip');
            self.NLabel.Tag = "NLabel";

            %Width Label
            self.WidthLabel     = matlab.ui.internal.toolstrip.Label(getMessageString('width'));
            self.WidthLabel.Description = getMessageString('widthTooltip');
            self.WidthLabel.Tag = "WidthLabel";

            %Radius Spinner
            self.RadiusSpinner = matlab.ui.internal.toolstrip.Spinner([0,65535],3);
            self.RadiusSpinner.Tag = 'radius';
            self.RadiusSpinner.Description = getMessageString('radTooltip');
            addlistener(self.RadiusSpinner,'ValueChanged',@(~,~)self.radiusChanged);
            
            %Length Spinner
            self.LengthSpinner = matlab.ui.internal.toolstrip.Spinner([0,65535],3);
            self.LengthSpinner.Tag = 'length';
            self.LengthSpinner.Description = getMessageString('lengthTooltip');
            addlistener(self.LengthSpinner,'ValueChanged',@(~,~)self.lengthChanged);
            
            %Degrees Spinner
            self.DegreesSpinner = matlab.ui.internal.toolstrip.Spinner([0,180],0);
            self.DegreesSpinner.Tag = 'degrees';
            self.DegreesSpinner.Description = getMessageString('degreesTooltip');
            addlistener(self.DegreesSpinner,'ValueChanged',@(~,~)self.degreesChanged);
            
            %N Combo Box
            self.NComboBox = matlab.ui.internal.toolstrip.DropDown({'0';'4';'6';'8'});
            self.NComboBox.SelectedIndex = 1;
            self.NComboBox.Tag = 'N';
            self.NComboBox.Description = getMessageString('nTooltip');
            addlistener(self.NComboBox,'ValueChanged',@(~,~)self.nChanged);
            
            %Width Spinner
            self.WidthSpinner = matlab.ui.internal.toolstrip.Spinner([0,65535],3);
            self.WidthSpinner.Tag = 'width';
            self.WidthSpinner.Description = getMessageString('widthTooltip');
            addlistener(self.WidthSpinner,'ValueChanged',@(~,~)self.widthChanged);

            %Layout
            c = self.StrelSection.addColumn('width',60);
            c.add(self.ShapeButton);
            c2 = self.StrelSection.addColumn(...
                'HorizontalAlignment','right');
            c2.add(self.RadiusLabel);
            c2.add(self.LengthLabel);
            c2.add(self.DegreesLabel);
            c3 = self.StrelSection.addColumn('width',40);
            c3.add(self.RadiusSpinner);
            c3.add(self.LengthSpinner);
            c3.add(self.DegreesSpinner);
            c4 = self.StrelSection.addColumn(...
                'HorizontalAlignment','right');
            c4.add(self.NLabel);
            c4.add(self.WidthLabel);
            c5 = self.StrelSection.addColumn('width',40);
            c5.add(self.NComboBox);
            c5.add(self.WidthSpinner);
            
        end
        
        function section = addViewSection(self)
            
            self.ViewMgr = images.internal.app.segmenter.image.web.ViewControlsManager(self.hTab);
            section = self.ViewMgr.Section;
            
            self.OpacitySliderListener = addlistener(self.ViewMgr.OpacitySlider, 'ValueChanged', @(~,~)self.opacitySliderMoved());
            self.ShowBinaryButtonListener = addlistener(self.ViewMgr.ShowBinaryButton, 'ValueChanged', @(hobj,~)self.showBinaryPress(hobj));
        end
        
        function section = addApplyCloseSection(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            tabName = getMessageString('morphologyTab');
            
            self.ApplyCloseMgr = iptui.internal.ApplyCloseManager(self.hTab, tabName);
            section = self.ApplyCloseMgr.Section;
            
            addlistener(self.ApplyCloseMgr.ApplyButton,'ButtonPushed',@(~,~)self.onApply());
            addlistener(self.ApplyCloseMgr.CloseButton,'ButtonPushed',@(~,~)self.onClose());
        end
    end
    
    %%Callbacks
    methods (Access = private)
        function opacitySliderMoved(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            newOpacity = self.ViewMgr.Opacity;
            self.hApp.updateScrollPanelOpacity(newOpacity)
            
            self.hToolstrip.setMode(AppMode.OpacityChanged)
        end
        
        function showBinaryPress(self,hobj)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            if hobj.Value
                self.hApp.showBinary()
                self.ViewMgr.OpacitySlider.Enabled = false;
                self.ViewMgr.OpacityLabel.Enabled  = false;
                self.hToolstrip.setMode(AppMode.ShowBinary)
            else
                self.hApp.unshowBinary()
                self.ViewMgr.OpacitySlider.Enabled = true;
                self.ViewMgr.OpacityLabel.Enabled  = true;
                self.hToolstrip.setMode(AppMode.UnshowBinary)
            end
        end
        
        function updateOperationSelection(self,src,~)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.AppMode;
            
            self.OperationButton.Text = src.Tag;
            self.OperationButton.Tag = src.Tag;
            
            self.NoOperationSelected = false;
            
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
        
        function updateShapeSelection(self,src,~)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            import images.internal.app.segmenter.image.web.AppMode;
            
            shape = src.Tag;
            self.ShapeButton.Tag = shape;
            self.ShapeButton.Text = getMessageString(shape);
            self.ShapeButton.Icon = self.ShapeIconList{find(cellfun(@(x) isequal(x,shape), self.ShapeList),1)};
            self.updateStrelPropertyPanel()
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
        
        function radiusChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            % Update radius to integer-valued number if needed.
            val = self.RadiusSpinner.Value;
            if val ~= round(val)
                self.RadiusSpinner.Value = round(val);
                val = round(val);
            end
            
            % Update radius to a multiple of 3 if needed. (Octagon)
            if self.RadiusSpinner.StepSize == 3
                if mod(val,3) ~= 0
                    self.RadiusSpinner.Value = val + (3 - mod(val,3));
                end
            end
            
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
        
        function lengthChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            val = self.LengthSpinner.Value;
            if val~=round(val)
                self.LengthSpinner.Value = round(val);
            end
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
        
        function degreesChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            val = self.DegreesSpinner.Value;
            if val~=round(val)
                self.DegreesSpinner.Value = round(val);
            end
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
        
        function nChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
        
        function widthChanged(self)
            
            import images.internal.app.segmenter.image.web.AppMode;
            
            val = self.WidthSpinner.Value;
            if val~=round(val)
                self.WidthSpinner.Value = round(val);
            end
            self.hToolstrip.setMode(AppMode.MorphImage);
        end
    end
    
    %%Helpers
    methods (Access = private)
        function restoreDefaults(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            % Reset operation selection
            self.OperationButton.Text = getMessageString('selectOp');
            self.NoOperationSelected = true;
        end
        
        function reactToOpacityChange(self)
            % We move the opacity slider to reflect a change in opacity
            % level coming from a different tab.
            
            newOpacity = self.hApp.getScrollPanelOpacity();
            self.ViewMgr.Opacity = 100*newOpacity;
        end
        
        function reactToShowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled     = false;
            self.ViewMgr.ShowBinaryButton.Value = true;
        end
        
        function reactToUnshowBinary(self)
            self.ViewMgr.OpacitySlider.Enabled     = true;
            self.ViewMgr.ShowBinaryButton.Value = false;
        end
        
        function applyMorphologicalOperation(self)
            
            import images.internal.app.segmenter.image.web.getMessageString;
            
            if self.NoOperationSelected
                return;
            end
            
            self.showAsBusy();
            
            self.hApp.clearTemporaryHistory()
            
            % Find the morphological operation to apply
            operation = self.OperationButton.Tag;
            morphOp = str2func(sprintf('im%s',operation));
            
            % Get the structuring element to use
            [se,shape] = self.getStructuringElement();
            
            % Get the mask.
            mask = self.hApp.getCurrentMask();
            
            % Apply the morphological operation
            mask = morphOp(mask,se);
            
            cmdStrel = self.StrelCreationCommand;
            cmdMorph = sprintf('BW = im%s(BW, se);', operation);
            cmd = [cmdStrel, {cmdMorph}];
            
            % Enable Apply button
            self.ApplyCloseMgr.ApplyButton.Enabled = true;
            
            resourceKey = sprintf('%sComment', operation);
            self.hApp.setTemporaryHistory(mask, getMessageString(resourceKey, shape), cmd)
            self.hApp.updateScrollPanelPreview(mask)
            
            self.unshowAsBusy();
        end
        
        function updateStrelPropertyPanel(self)

            strelShape = self.ShapeButton.Tag;
            
            self.disableAllStrelProperties();
            switch strelShape
                case {'disk','default'}
                self.RadiusLabel.Enabled = true;
                self.RadiusSpinner.Enabled = true;
                self.RadiusSpinner.StepSize = 1;
                self.NLabel.Enabled = true;
                self.NComboBox.Enabled = true;
            case 'diamond'
                self.RadiusLabel.Enabled = true;
                self.RadiusSpinner.Enabled = true;
                self.RadiusSpinner.StepSize = 1;
            case 'line'
                self.LengthLabel.Enabled = true;
                self.LengthSpinner.Enabled = true;
                self.DegreesLabel.Enabled = true;
                self.DegreesSpinner.Enabled = true;
            case 'octagon'
                self.RadiusLabel.Enabled = true;
                self.RadiusSpinner.Enabled = true;
                self.RadiusSpinner.StepSize = 3;
                
                % Update spinner value to be a multiple of 3
                val = self.RadiusSpinner.Value;
                if mod(val,3) ~= 0
                    self.RadiusSpinner.Value = val + (3 - mod(val,3));
                end
            case 'square'
                self.LengthLabel.Enabled = true;
                self.LengthSpinner.Enabled = true;
            case 'rectangle'
                self.LengthLabel.Enabled = true;
                self.LengthSpinner.Enabled = true;
                self.WidthLabel.Enabled = true;
                self.WidthSpinner.Enabled = true;
            otherwise
                assert(false,'Incorrect structuring element shape')
            end
        end

        function disableAllStrelProperties(self)

            self.RadiusLabel.Enabled = false;
            self.RadiusSpinner.Enabled = false;
            self.LengthLabel.Enabled = false;
            self.LengthSpinner.Enabled = false;
            self.DegreesLabel.Enabled = false;
            self.DegreesSpinner.Enabled = false;
            self.NLabel.Enabled = false;
            self.NComboBox.Enabled = false;
            self.WidthLabel.Enabled = false;
            self.WidthSpinner.Enabled = false;
        end

        function [se,strelShape] = getStructuringElement(self)
            strelShape = self.ShapeButton.Tag;
            
            R       = self.RadiusSpinner.Value;
            len     = self.LengthSpinner.Value;
            deg     = self.DegreesSpinner.Value;
            N       = str2double(self.NComboBox.Value);
            W       = self.WidthSpinner.Value;
            
            switch strelShape
                case {'disk','default'}
                se = strel('disk',R,N);
                self.StrelCreationCommand = {...
                    sprintf('radius = %d;', R), ...
                    sprintf('decomposition = %d;', N), ...
                    'se = strel(''disk'', radius, decomposition);'};
            case 'diamond'
                se = strel('diamond',R);
                self.StrelCreationCommand = {...
                    sprintf('radius = %d;', R), ...
                    'se = strel(''diamond'', radius);'};
            case 'line'
                se = strel('line',len,deg);
                self.StrelCreationCommand = {...
                    sprintf('length = %f;', len), ...
                    sprintf('angle = %f;', deg), ...
                    'se = strel(''line'', length, angle);'};
            case 'octagon'
                se = strel('octagon',R);
                self.StrelCreationCommand = {...
                    sprintf('radius = %d;', R), ...
                    'se = strel(''octagon'', radius);'};
            case 'square'
                se = strel('square',len);
                self.StrelCreationCommand = {...
                    sprintf('width = %d;', len), ...
                    'se = strel(''square'', width);'};
            case 'rectangle'
                se = strel('rectangle',[len W]);
                self.StrelCreationCommand = {...
                    sprintf('dimensions = [%d %d];', len, W), ...
                    'se = strel(''rectangle'', dimensions);'};
            otherwise
                assert(false,'Incorrect structuring element shape')
            end
                   
        end
        
        function TF = isVisible(self)
            TF = ~isempty(self.hAppContainer.SelectedToolstripTab) && strcmp(self.hAppContainer.SelectedToolstripTab.title, self.hTab.Title);
        end
        
        function disableStrelSection(self)
            
            self.ShapeButton.Enabled = false;
            self.disableAllStrelProperties()
        end
        
        function enableStrelSection(self)
            
            self.ShapeButton.Enabled = true;
			self.updateStrelPropertyPanel()
        end
        
        function showAsBusy(self)
            self.hAppContainer.Busy = true;
        end
        
        function unshowAsBusy(self)
            self.hAppContainer.Busy = false;
        end
    end
    
    %%Set/Get Methods
    methods
        function set.NoOperationSelected(self,TF)
            % Update view of strel section every time this flag is updated.
            
            if TF
               self.disableStrelSection()
            else
                self.enableStrelSection()
            end
            self.NoOperationSelected = TF;
        end
    end
    
end

function TF = maskHasRegions(mask)

TF = any(mask(:));

end
