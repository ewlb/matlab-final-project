classdef ImageCaptureDialog < images.internal.app.utilities.OkCancelDialog
% ImageCaptureDialog creates a image capure dialog with a preview panel
% and a camera properties panel.
    
% Copyright 2021-2024 The MathWorks, Inc.

    % UI components
    properties (GetAccess=?uitest.factory.Tester, SetAccess=private)
       deviceDropDown 
       captureButton
       retakeButton
       hCaptureButtonPanel
       hPropertiesPanel
       camPropertiesPanel
       hPreviewAxes
       hImage
       hGrid
       image
    end
    
    properties (Access=private)
        margin = 10;
        buttonHeight = 20;
        currentDevice
        deviceList
    end
    
    
    
    methods
        function self = ImageCaptureDialog(size, location)
            
            self = self@images.internal.app.utilities.OkCancelDialog( location, getString(message('images:colorSegmentor:ImageCaptureDialogTitle')));
            self.Size = size;
            
            % Before begining the dialog construction, check for presence
            % of webcam/support package.
            isOK = initializeDevices(self);
            
            if isOK
                create(self);
            end
        end
        
        function create(self)
            create@images.internal.app.utilities.OkCancelDialog(self);
            
            self.customizeOKCancelButton();
            
            self.createGridLayout();
            
            self.createDeviceDropDown();
            
            self.createPropertiesPanel();
            
            self.createPreviewPanel();
            
            self.createCaptureButton();
            
            self.createRetakeButton();
            
            self.startPreview();
            
        end
        
        
        function im = getCapturedImage(self)
           im = self.image; 
        end
        
    end
    
    methods (Access=private)
                
        function customizeOKCancelButton(self)
            self.Ok.Text = 'Accept';
            
            self.Ok.Icon = fullfile(matlabroot, 'toolbox', 'images', 'icons', 'CreateMask_24px.png');
            self.Cancel.Icon = fullfile(matlabroot, 'toolbox', 'images', 'icons', 'failed_24.png');
            
            dialogWidth = self.Size(1);
            okCancelWidth = self.Ok.Position(3) + 25;
            okCancelHeight = self.Ok.Position(4) + 10;
            
            okPosition = [(dialogWidth-self.margin-okCancelWidth) ...
                          self.margin ...
                          okCancelWidth ...
                          okCancelHeight];
                      
            cancelPosition = [(dialogWidth-2*self.margin-2*okCancelWidth) ...
                          self.margin ...
                          okCancelWidth ...
                          okCancelHeight];
            self.Ok.Position = okPosition;
            self.Cancel.Position = cancelPosition;
            self.Ok.Enable = 'off';
        end
        
        function createGridLayout(self)
            
            % Calculate panel position (excluding the ok/cancel buttons)
            panelXStart = self.margin;
            panelYStart = self.margin+self.Ok.Position(2)+self.Ok.Position(4);
            panelWidth = self.FigureHandle.Position(3) - 2*self.margin;
            panelHeight = self.FigureHandle.Position(4) - panelYStart - self.margin;
            panelPosition = [panelXStart panelYStart panelWidth panelHeight];
            
            hPanel = uipanel('Parent',self.FigureHandle,'Position',panelPosition,'BorderType','none');
            
            % Create grid 2x2 grid layout in the panel
            %|----------------------------------------------------------------|
            %|loc(1,1) = Device selectionList |                               |
            %|--------------------------------|-------------------------------|
            %|loc(2,1) = Properties List      | loc(2,2) = Camera preview     |
            %|--------------------------------|-------------------------------|                               
            
            % At the bottom of the figure window
            %|           Capture/Retake Button | Cancel Button | Accept Button|
            %|--------------------------------|-------------------------------|
            self.hGrid = uigridlayout(hPanel, [2 2]);
            
            buttonCellHeight = 2*self.margin + self.buttonHeight;
            
            self.hGrid.RowHeight = {buttonCellHeight-5, '1x'};
            self.hGrid.ColumnWidth = {'2.15x', '2.85x'};
            
        end
        
        function createDeviceDropDown(self)
            
           hDevicePanel = uipanel(self.hGrid, 'BorderType', 'none');
           hDevicePanel.Layout.Row = 1;
           hDevicePanel.Layout.Column = 1;
           
           labelWidth = 60;
           dropDownWidth = 200;
           
           uilabel(hDevicePanel, 'Text', 'Camera',...
                                 'HorizontalAlignment', 'left',...
                                 'Position',[self.margin, self.margin, labelWidth,  self.buttonHeight]);
             
           camList = self.deviceList;
           
           self.deviceDropDown = uidropdown(hDevicePanel,...
                                            'Items', camList,...
                                            'Position', [2*self.margin+labelWidth, self.margin, dropDownWidth, self.buttonHeight],...
                                            'ValueChangedFcn', @(src,evt)self.onDeviceChanged(src, evt));                  
        end
        
        function createPropertiesPanel(self)
           
            % Properties list panel
            self.hPropertiesPanel = uipanel( self.hGrid, Visible="off", ...
                                             Scrollable="on", ...
                                             Tag="CameraPropsMainPanel" );

            self.hPropertiesPanel.Layout.Row = 2;
            self.hPropertiesPanel.Layout.Column = 1;
            
            drawnow;
            
            self.camPropertiesPanel = ...
                images.internal.app.colorThresholderWeb.CameraPropertiesPanel(...
                self.hPropertiesPanel, self.currentDevice);
            
            self.hPropertiesPanel.Visible = 'on';
            
            drawnow;
            
            l = addlistener(self.camPropertiesPanel,...
                            'ResolutionChanged',...
                            @(src, evt)self.onResolutionChanged(src, evt));
            
        end
        
        function createPreviewPanel(self)
           
            hImagePanel = uipanel(self.hGrid, 'BorderType', 'none',...
                                              'Units', 'pixels');
            hImagePanel.Layout.Row = 2;
            hImagePanel.Layout.Column = 2;
            
            self.hPreviewAxes   = axes('Parent', hImagePanel,...
                                       'Units','normalized',...
                                       'Position', [0 0 1 1],...
                                       'Interactions',[],...
                                       'PickableParts', 'none');
            
            set(self.hPreviewAxes,'Visible','on');
            set(self.hPreviewAxes,'XTick',[],'YTick',[]);
            set(self.hPreviewAxes,'XColor','none','YColor','none');
            
            im = snapshot(self.currentDevice);
            
            self.hImage = imshow(im, 'Parent', self.hPreviewAxes, 'Border', 'tight');
            
            self.hPreviewAxes.Toolbar.Visible = 'off';
        end
        
        function createCaptureButton(self)
            
            
            icon = fullfile(matlabroot, 'toolbox', 'images', 'icons', 'color_thresholder_load_camera_24.png');

            cancelPos = self.Cancel.Position;
            
            captureButtonPos = [cancelPos(1)-self.margin-cancelPos(3)...
                                cancelPos(2) ...
                                cancelPos(3) ...
                                cancelPos(4)];
                            
            self.captureButton = uibutton(self.FigureHandle,...
                                          'Text', 'Capture',...
                                          'Icon', icon,...
                                          'Tooltip', 'Capture Image',...
                                          'Position',captureButtonPos,...
                                          'ButtonPushedFcn', @(src, evt) self.onCapture(src, evt));
                                      
            
            
        end
        
        function createRetakeButton(self)
            
            icon = fullfile(matlabroot, 'toolbox', 'images', 'icons', 'restore_24.png');
                            
            self.retakeButton = uibutton(self.FigureHandle,...
                                          'Text', 'Retake',...
                                          'Icon', icon,...
                                          'Tooltip', 'Retake Image',...
                                          'Position',self.captureButton.Position,...
                                          'Visible', 'off',...
                                          'ButtonPushedFcn', @(src, evt) self.onRetake(src, evt));
        end
        
        function onDeviceChanged(self, src, ~)

            newDevice = src.Value;
            
            stopPreview(self);
            
            delete(self.camPropertiesPanel);
            delete(self.hPropertiesPanel);
            
            self.currentDevice = webcam(newDevice);
            
            self.createPropertiesPanel();
            
            im = snapshot(self.currentDevice);
            self.hImage = imshow(im, 'Parent', self.hPreviewAxes, 'Border', 'tight');
            startPreview(self);
            
        end
        
        function onCapture(self, ~, ~)
            
            im = snapshot(self.currentDevice);
            stopPreview(self);
            self.hImage = imshow(im, 'Parent', self.hPreviewAxes, 'Border', 'tight' );
            self.image = im;
            
            self.captureButton.Visible = 'off';
            self.retakeButton.Visible = 'on';
            self.Ok.Enable = 'on';
            
        end
        
        function onRetake(self, ~, ~)
            
            self.restartPreview();
            self.captureButton.Visible = 'on';
            self.retakeButton.Visible = 'off';
            self.Ok.Enable = 'off';
            self.image = [];

        end
        
        function onResolutionChanged(self, ~, ~)
           self.restartPreview(); 
        end
    end
    
    %---- Device interaction methods ------
    methods (Access=private)
        
       function isOK = initializeDevices(self)

           isOK = true;

           % Find the location of webcam.m for checking spkg installation
           fullpathToUtility = which('matlab.webcam.internal.Utility');
            
            if isempty(fullpathToUtility)
                uiwait(errordlg(getString(message('images:colorSegmentor:SupportPkgNotInstalledMsg')), ...
                    getString(message('images:colorSegmentor:GenericErrorTitle')), ...
                    'modal'));
                isOK = false;
                return;
            end 
                       
            % Get available webcams
            try
                cams = webcamlist;
                if isempty(cams)
                    uiwait(errordlg(getString(message('images:colorSegmentor:NoWebcamsDetectedMsg')), ...
                        getString(message('images:colorSegmentor:NoWebcamsDetected')), ...
                        'modal'));       
                    isOK = false;
                    return;
                end
            catch excep
                uiwait(errordlg(excep.message, ...
                    getString(message('images:colorSegmentor:GenericErrorTitle')), ...
                    'modal'));
                isOK = false;
                return;
            end

            %Initialize Webcam
            try
                self.deviceList = cams;
                self.currentDevice = webcam(1);
                % Test if the webcam is accessible
                snapshot(self.currentDevice);
                
            catch
                uiwait(errordlg(getString(message('images:colorSegmentor:CameraInUseMsg', cams{1})), ...
                    getString(message('images:colorSegmentor:GenericErrorTitle')), ...
                    'modal'));
                isOK = false;
                return;
            end
       end
        
        function startPreview(self)
            preview(self.currentDevice, self.hImage);
        end
        
        function stopPreview(self)
            closePreview(self.currentDevice);
        end 
        
        function restartPreview(self)
            
            self.stopPreview();
            % Two snapshots to clear the image queue and get the updated
            % image.
            im = snapshot(self.currentDevice);
            im = snapshot(self.currentDevice);
            self.hImage = imshow(im, 'Parent', self.hPreviewAxes, 'Border', 'tight');
            self.startPreview();
            
        end
    end
    
    
end 