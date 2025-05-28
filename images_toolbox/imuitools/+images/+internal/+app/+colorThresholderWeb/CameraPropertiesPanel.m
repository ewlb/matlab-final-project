classdef CameraPropertiesPanel< handle
% CameraPropertiesPanel - Creates camera specific properties and associated
% tearaway.
 
% Copyright 2020-2024 The MathWorks, Inc.
    
    properties(Access=private)
        CamObj
        
        DevicePropGrid
        DevicePropObjects
        
        CurrentSliderValue
    end
    
    events
        ResolutionChanged
    end
 
    methods
        function this = CameraPropertiesPanel(hPropertiesPanel, camObj)
            % Initialization
            this.CamObj = camObj;
            this.addButtons(hPropertiesPanel);
        end
        
    end
    
    
    
    methods
            
         function addButtons(this, hPropertiesPanel)
 
             camController = this.CamObj.getCameraController;
             
             % Get all settable properties.
             props = set(this.CamObj);
             propNames = fieldnames(props);
             sortedProps = sort(propNames(2:end));
             propNames(2:end) = sortedProps;
             
             % Have Mode properties listed before the actual value
             % properties.
             indices = find(contains(propNames, "Mode"));
             if ~isempty(indices)
                 for idx = 1:length(indices)
                     modePropName = propNames{indices(idx)};
                     tempID = strfind(modePropName, 'Mode');
                     expectedPropName = modePropName(1:tempID-1);
                     if strcmpi(expectedPropName, propNames{indices(idx)-1})
                         propNames{indices(idx)-1} = modePropName;
                         propNames{indices(idx)} = expectedPropName;
                     end
                 end
             end
           
             numProperties = length(propNames);

             % Hardcoding panelPos because of bug related to panel Position
             % returning an incorrect size. This panel needs to be replaced
             % with uigridlayout structure for properties.
             this.DevicePropGrid = uigridlayout( hPropertiesPanel, ...
                                        [numProperties, 2], ...
                                        ColumnWidth=["fit", "1x"], ...
                                        RowHeight=repmat("fit", [numProperties 1]), ...
                                        Padding=[5 5 5 5], ...
                                        RowSpacing=0, ...
                                        Scrollable="on", ...
                                        Tag="CameraPropMainGrid" );
             
             for idx =  1:numProperties
                 lblCtrl = uilabel( this.DevicePropGrid, Text=propNames{idx} );
                 lblCtrl.Layout.Row = idx;
                 lblCtrl.Layout.Column = 1;

                 if ~isempty(props.(propNames{idx}))
                     comboCtrl = uidropdown( this.DevicePropGrid,...
                                            'Items', props.(propNames{idx}){1},...
                                            'Value', this.CamObj.(propNames{idx}),...
                                            'Tag', strcat(propNames{idx}, 'Combo') );
                     comboCtrl.Layout.Row = idx;
                     comboCtrl.Layout.Column = 2;                                                    
                     addlistener( comboCtrl, 'ValueChanged', ...
                            @(~,~)updateCameraObjectProps(this, propNames{idx}) );
                     this.DevicePropObjects.(propNames{idx}).ComboControl = comboCtrl;
                 else
                     entryGrid = uigridlayout( this.DevicePropGrid, [1 2], ...
                                                ColumnWidth=["1x", "2x"], ...
                                                Tag="CameraPropSubGrid" );

                     % Create text field to enter slider.
                     this.CurrentSliderValue = this.CamObj.(propNames{idx});

                     editCtrl = uieditfield( entryGrid,...
                                             'numeric', 'Value',...
                                             this.CurrentSliderValue, ...
                                             'Tag', strcat( propNames{idx}, 'Edit'),...
                                             'RoundFractionalValues', ...
                                                matlab.lang.OnOffSwitchState.on );
                     addlistener( editCtrl, 'ValueChanged', ...
                            @(hobj,~)this.sliderEditControlCallback(hobj , propNames{idx}));
                     this.DevicePropObjects.(propNames{idx}).EditControl = editCtrl;

                     % Create the Slider
                     range = camController.getPropertyRange(propNames{idx});
                     entryGrid.Layout.Row = idx;
                     entryGrid.Layout.Column = 2;

                     sliderCtrl = uislider( entryGrid,...
                                            'Value', this.CamObj.(propNames{idx}),...
                                            'Limits',[double(range(1)), double(range(2))],...
                                            'Tag', strcat(propNames{idx}, 'Slider'),...
                                            'MajorTickLabelsMode', 'auto',...
                                            'MajorTicks',[],'MinorTicks', [],...
                                            'MajorTickLabels',{});
                     sliderCtrl.Layout.Row = 1;
                     sliderCtrl.Layout.Column = 2;
                     addlistener( sliderCtrl, 'ValueChanged', ...
                            @(hobj,~)this.sliderEditControlCallback(hobj, propNames{idx}));
                     this.DevicePropObjects.(propNames{idx}).SliderControl = sliderCtrl;
                     
                     updateSliderAvailability(this, strcat(propNames{idx}, 'Mode'));
                 end
             end
         end
    end
    
    methods(Access=private)
        function updateSliderAvailability(this, propName)
            % Update a slider/edit field based on combo box value.
            
            if strfind(propName, 'Resolution') %#ok<STRIFCND> % Resolution is special. 
                notify(this, 'ResolutionChanged');
                return;
            end
            
            idx = strfind(propName, 'Mode');
            if isempty(idx)
                return;
            end
            editPropName = propName(1:idx-1);
            try
                if isfield(this.DevicePropObjects, propName)
                    if strcmpi(this.DevicePropObjects.(propName).ComboControl.Value, 'auto')
                        this.DevicePropObjects.(editPropName).SliderControl.Enable = false;
                        this.DevicePropObjects.(editPropName).EditControl.Enable = false;
                    elseif strcmpi(this.DevicePropObjects.(propName).ComboControl.Value, 'manual')
                        this.DevicePropObjects.(editPropName).SliderControl.Enable = true;
                        this.DevicePropObjects.(editPropName).EditControl.Enable = true;                    
                    end
                end
            catch
                % Do nothing and continue.
            end
        end
        
        function updateCameraObjectProps(this, propName)
            propObject = this.DevicePropObjects.(propName);
            if any(ismember(fieldnames(propObject), 'EditControl'))
                this.CamObj.(propName) = this.DevicePropObjects.(propName).EditControl.Value;
            else
                this.CamObj.(propName) = this.DevicePropObjects.(propName).ComboControl.Value;
                updateSliderAvailability(this, propName);
            end
        end
        
        function sliderEditControlCallback(this, obj, propNames)
            if isa(obj,'matlab.ui.control.Slider')
                this.CurrentSliderValue = obj.Value;
                this.DevicePropObjects.(propNames).EditControl.Value = this.CurrentSliderValue ;
            elseif isa(obj, 'matlab.ui.control.NumericEditField')
                camController = this.CamObj.getCameraController;
                range = camController.getPropertyRange(propNames);
                minValue = range(1);
                maxValue = range(2);
                value = obj.Value;
                if isnan(value)
                    % TODO: Do we need an unnecessary error message?
                    this.DevicePropObjects.(propNames).EditControl.Value = this.CurrentSliderValue;
                    return;
                end
                % Valid value - continue.
                if value < minValue
                    value = minValue;
                elseif value > maxValue
                    value = maxValue;
                end
                
                this.CurrentSliderValue = double(value);
                this.DevicePropObjects.(propNames).EditControl.Value = this.CurrentSliderValue;
                this.DevicePropObjects.(propNames).SliderControl.Value = this.CurrentSliderValue;
            end
            updateCameraObjectProps(this, propNames)
        end
        
        function [width, height] = getResolution(this)
            res = this.CamObj.Resolution;
            idx = strfind(res, 'x');
            width = str2double(res(1:idx-1));
            height = str2double(res(idx+1:end));
        end 
            
    end
end
