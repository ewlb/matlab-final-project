classdef FilterDialog < images.internal.app.utilities.OkCancelDialog
    %
    
    % Copyright 2019 The MathWorks, Inc.
    
    properties (GetAccess = public, SetAccess = protected)
        
        Label
        EditField
        ListBox
        
        Categories cell = {};
        
        Message char = '';
        
        SelectedLabel char = '';
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Ok Dialog
        %------------------------------------------------------------------
        function self = FilterDialog(loc, dlgTitle, dlgMsg, dlgCats)
            
            self = self@images.internal.app.utilities.OkCancelDialog(loc, dlgTitle);
            
            self.Size = [360, 160];
            
            self.Message = dlgMsg;
            self.Categories = dlgCats;
            
            create(self);
            
            self.SelectedLabel = self.ListBox.Value;
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
            
            create@images.internal.app.utilities.OkCancelDialog(self);
            
            addLabel(self);
            addEditField(self);
            addListBox(self);
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Ok Clicked------------------------------------------------------
        function okClicked(self)
            
            if ~isempty(self.SelectedLabel)
                self.Canceled = false;
                close(self);
            end
            
        end
        
        %--Add Ok----------------------------------------------------------
        function addLabel(self)
            
            self.Label = uilabel(...
                'Parent', self.FigureHandle,...
                'Position', [self.ButtonSpace,4*self.ButtonSize(2) + 3*self.ButtonSpace,(self.Size(1)/2) - (3*self.ButtonSpace),self.ButtonSize(2)],...
                'FontSize', 12,...
                'HorizontalAlignment','right',...
                'Text',self.Message);
            
        end
        
        %--Add Cancel------------------------------------------------------
        function addEditField(self)
            
            self.EditField = uieditfield('text',...
                'Parent', self.FigureHandle,...
                'Position',[(self.Size(1)/2) + (0.5*self.ButtonSpace),4*self.ButtonSize(2) + 3*self.ButtonSpace,(self.Size(1)/2) - (3*self.ButtonSpace),self.ButtonSize(2)],...
                'FontSize', 12,...
                'Value','',...
                'ValueChangingFcn',@(src,evt) filterList(self,evt.Value));
                 
        end
        
        %--Add Cancel------------------------------------------------------
        function addListBox(self)
            
            self.ListBox = uilistbox('Parent', self.FigureHandle,...
                'Position',[(self.Size(1)/2) + (0.5*self.ButtonSpace),self.ButtonSize(2) + 3*self.ButtonSpace,(self.Size(1)/2) - (3*self.ButtonSpace),3*self.ButtonSize(2)],...
                'Items',self.Categories,...
                'FontSize', 12,...
                'Value',self.Categories(1),...
                'ValueChangedFcn',@(src,evt) selectFromList(self,evt));
     
        end
        
        %--Select From List------------------------------------------------
        function selectFromList(self,evt)
            
            self.SelectedLabel = evt.Value;
            self.Ok.Enable = 'on';
            
        end
        
        %--Filter List-----------------------------------------------------
        function filterList(self,keys)
                        
            TF = cellfun(@(x) strncmpi(keys,x,numel(keys)),self.Categories);
            
            idx = find(TF, 1);
            
            if ~isempty(idx)
                
                newcats = self.Categories(TF);
                
                set(self.ListBox,'Items',newcats,'Value',newcats(1));
                
                self.Ok.Enable = 'on';
                self.SelectedLabel = self.ListBox.Value;
                
            else
                
                self.Ok.Enable = 'off';
                self.SelectedLabel = '';
                self.ListBox.Items = {};
                
            end
            
        end
        
    end
    
end
