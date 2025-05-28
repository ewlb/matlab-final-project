classdef VariableDialog < images.internal.app.utilities.OkCancelDialog
    %
    
    % Copyright 2019-2024 The MathWorks, Inc.
    
    properties (GetAccess = public, SetAccess = protected)
        
        Label
        EditField
        Table
        
        Variables cell = {};
        VariableSizes cell = {};
        VariableClasses cell = {};
        
        Message char = '';
        
        SelectedVariable char = '';
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Ok Dialog
        %------------------------------------------------------------------
        function self = VariableDialog(loc, dlgTitle, dlgMsg, supportedStyle)
            
            self = self@images.internal.app.utilities.OkCancelDialog(loc, dlgTitle);
            
            self.Size = [380, 320];
            
            self.Message = dlgMsg;
            
            filterVariables(self,supportedStyle);
            
            create(self);
            
            set(self.Table,'Visible','on');
            self.Ok.Enable = 'off';
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
            
            create@images.internal.app.utilities.OkCancelDialog(self);
            
            addLabel(self);
            addTable(self);
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Ok Clicked------------------------------------------------------
        function okClicked(self)
            
            if ~isempty(self.SelectedVariable)
                self.Canceled = false;
                close(self);
            end
            
        end
        
        %--Add Label-------------------------------------------------------
        function addLabel(self)
            
            self.Label = uilabel(...
                'Parent', self.FigureHandle,...
                'Position', [self.ButtonSpace,13*self.ButtonSize(2) + 3*self.ButtonSpace,self.Size(1) - (2*self.ButtonSpace),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','left',...
                'Text',self.Message);
            
        end
        
        %--Add List Box----------------------------------------------------
        function addTable(self)
            
            self.Table = uitable(...
                'Parent', self.FigureHandle,...
                'Position', [self.ButtonSpace,self.ButtonSize(2) + 2*self.ButtonSpace,self.Size(1) - (2*self.ButtonSpace),12*self.ButtonSize(2)],...
                'FontSize', 12,...
                'Enable','on',...
                'ColumnName',{getString(message('images:segmenter:variableTable')),getString(message('images:segmenter:sizeTable')),getString(message('images:segmenter:classTable'))},...
                'ColumnFormat',{'char','char','char'},...
                'RowName',{},...
                'Visible','off',...
                'SelectionType','row',...
                'RowStriping','off',...
                'CellSelectionCallback',@(src,evt) selectRow(self,evt),...
                'Data',[self.Variables',self.VariableSizes',self.VariableClasses']);
     
        end
        
        %--Select Row------------------------------------------------------
        function selectRow(self,evt)
            if ~isempty(evt.Source.Selection)
                if ~isscalar(evt.Source.Selection)
                    evt.Source.Selection = evt.Source.Selection(1);
                end
                self.SelectedVariable = self.Variables(evt.Source.Selection(1));
                self.Ok.Enable = 'on';
            else
                self.Ok.Enable = 'off';
            end
        end
        
        %--Filter Variables------------------------------------------------
        function filterVariables(self,supportedStyle)
            
            vars = evalin('base','whos');
            self.Variables = {};
            
            for i = 1:numel(vars)
                if filterByStyle(self,vars(i),supportedStyle)
                    self.Variables{end+1} = vars(i).name;
                    
                    str = num2str(vars(i).size(1));
                    for idx = 2:numel(vars(i).size)
                        str = [str 'x' num2str(vars(i).size(idx))]; %#ok<AGROW>
                    end
                    
                    self.VariableSizes{end+1} = str;
                    self.VariableClasses{end+1} = vars(i).class;
                end
            end
            
        end
        
        %--Filter By Style-------------------------------------------------
        function TF = filterByStyle(~,var,supportedStyles)
            
            % In case the input is a cellstr
            supportedStyles = string(supportedStyles);

            for style = supportedStyles(:)'
                switch style
                    
                    case 'text'
                        supportedClasses = {'categorical','char','string','cell'};
                        TF = any(strcmp(var.class,supportedClasses));
                        
                    case 'grayOrLogicalVolume3D'
                        supportedClasses = {'logical','int8','uint8','int16','uint16','int32','uint32','single','double'};
                        % Support 3D inputs. We do not allow singleton dimensions
                        TF = any(strcmp(var.class,supportedClasses)) && (length(var.size) == 3 && all(var.size > 1));
                        
                    case 'grayOrRGBVolume'
                        supportedClasses = {'int8','uint8','int16','uint16','int32','uint32','single','double'};
                        % Support 2D, 3D, or 4D (1 or 3 channel) inputs. We can
                        % allow singleton dimensions
                        TF = (any(strcmp(var.class,supportedClasses)) && ((length(var.size) == 3 && all(var.size > 1)) || (length(var.size) == 4 && all(var.size > 1) && var.size(4) == 3)));
                        
                    case 'labelVolume'
                        supportedClasses = {'categorical','logical','int8','uint8','int16','uint16','int32','uint32','single','double'};
                        % Support 2D or 3D inputs. We can allow singleton
                        % dimensions
                        TF = any(strcmp(var.class,supportedClasses)) && (length(var.size) == 3 || length(var.size) == 2);
                        
                    case 'labelVolume3D'
                        supportedClasses = {'categorical','logical','int8','uint8','int16','uint16','int32','uint32','single','double'};
                        % Support only 3D inputs. We do not allow singleton
                        % dimensions
                        TF = any(strcmp(var.class,supportedClasses)) && (length(var.size) == 3 && all(var.size > 1));
                        
                    case 'duration'
                        
                        supportedClasses = {'duration'};
                        TF = any(strcmp(var.class,supportedClasses));
                    case 'blockedImage'
                        TF = strcmp(var.class,'blockedImage');
                        
                    case 'all'
                        TF = true;

                    case 'colormap'
                        supportedClasses = {'int8','uint8','int16','uint16','int32','uint32','single','double'};
                        TF = ismember(var.class, supportedClasses) && (length(var.size) == 2) && var.size(2) == 3;
                        
                    case 'grayOrRGBImage'
                        supportedClasses = {'int8','uint8','int16','uint16','int32','uint32','single','double'};
                        TF = (any(strcmp(var.class,supportedClasses)) && ((length(var.size) == 2) || (length(var.size) == 3 && var.size(3) == 3)));
    
                    case 'trueColorImage'
                        supportedClasses = {'int8','uint8','int16','uint16','int32','uint32','single','double'};
                        TF = (any(strcmp(var.class,supportedClasses)) && (length(var.size) == 3 && var.size(3) == 3));
                        
                    case 'logicalImage'
                        TF = length(var.size) == 2 && strcmpi(var.class,'logical');
                        
                    case 'groundTruth'
                        % Support groundTruth input for ImageLabeler, VideoLabeler and GroundTruthLabeler
                        TF = strcmp(var.class,'groundTruth');
                    
                    case 'groundTruthMultisignal'
                        TF = strcmp(var.class,'groundTruthMultisignal') || strcmp(var.class,'groundTruth');                    
    
                    case 'groundTruthLidar'
                        % Support grroundTruthLidar input for Lidar Labeler
                        TF = strcmp(var.class, 'groundTruthLidar');
    
                    case 'medicalVolume'
                        TF = strcmp(var.class,'medicalVolume');

                    case 'medicalImage'
                        TF = strcmp(var.class,'medicalImage');

                    case 'groundTruthMedical'
                        TF = strcmp(var.class,'groundTruthMedical');   
                 
                    case 'imageDatastore'
                        TF = strcmp(var.class, 'matlab.io.datastore.ImageDatastore');
                        
                    case 'dicomCollection'
                        TF  = strcmp(var.class, 'table') && evalin('base', sprintf('images.internal.app.dicom.isDicomCollection(%s);', var.name));    
                        
                    case 'hypercube'
                        TF = any(strcmp(var.class,'hypercube'));
                        if TF
                            hcube = evalin('base',var.name);
                            if isscalar(hcube)
                                TF = TF & hyper.internal.app.viewer.hyperspectral.isValidHyperspectralImage(hcube.DataCube);
                            else
                                TF = false;
                            end
    
                        end
    
                    case 'hyperImage'
                        supportedClasses = {'int8','uint8','int16','uint16','int32','uint32','single','double'};
                        % Support 3D. We can allow singleton dimensions
                        TF = any(strcmp(var.class,supportedClasses)) && length(var.size) == 3 && var.size(3) >= 3 && all(var.size > 1);

                    case 'monoCamera'
                        % Support Monocamera variable object.
                        TF = strcmp(var.class,'monoCamera');

                    otherwise
                        TF = false;
                        
                end
                
                % Don't support complex or sparse or empty variables anywhere
                if TF
                    TF = TF && ~var.complex && ~var.sparse && all(var.size ~= 0);
                end

                % If variable has any of the required styles, then no
                % further checks are required.
                if TF
                    break;
                end
            end
        end
    end
end
