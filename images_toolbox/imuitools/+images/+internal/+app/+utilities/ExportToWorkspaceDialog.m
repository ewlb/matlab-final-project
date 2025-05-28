classdef ExportToWorkspaceDialog < images.internal.app.utilities.OkCancelDialog
    % For internal use only
    
    % Use this dialog to replace the export2wsdlg. The app code for using
    % this dialog should look like this:
    %
    % loc = imageslib.internal.app.utilities.ScreenUtilities.getToolCenter(myApp);
    %
    % dlg = images.internal.app.utilities.ExportToWorkspaceDialog(loc,...
    %       'Export To Workspace', ["var1","var2"], ["label1","label2"]);
    %
    % wait(dlg);
    %
    % if ~dlg.Canceled
    %     if dlg.VariableSelected(1)
    %         assignin('base',dlg.VariableName(1),myData1);
    %     end
    %     if dlg.VariableSelected(2)
    %         assignin('base',dlg.VariableName(2),myData2);
    %     end
    % end
    %
    % where myApp is a handle to the AppContainer object, myData1 and
    % myData2 are two variables you wish to export.
    
    % Copyright 2020-2024 The MathWorks, Inc.
    
    properties (GetAccess = public, SetAccess = protected)
        
        % Variable Name - Cell array of variable names. The number of names
        % is determined by the number of names/variables passed in when
        % constructing the dialog.
        VariableName string
        
        % Variable Selected - Logical flag for each variable to signal
        % whether or not the user wishes to export the corresponding
        % variable in VariableName.
        VariableSelected logical
        
    end
    
    properties (Access = protected)
        
        % Flag to determine if each variable has a valid name
        ValidName logical
        
    end

    properties(Access=private, Constant)
        MaxHeight = 600;
    end
    
    methods
        
        %------------------------------------------------------------------
        % Export To Workspace Dialog
        %------------------------------------------------------------------
        function self = ExportToWorkspaceDialog(loc, dlgTitle, varName, labelMsg)
            
            validateattributes(varName,{'string'},{'vector'});
            validateattributes(labelMsg,{'string'},{'size',size(varName),'vector'});
            
            self = self@images.internal.app.utilities.OkCancelDialog(loc, dlgTitle);
            
            % Restrict the maximum height in the event there are too many
            % variables being exported. See g3059157
            self.Size = [480, min(self.MaxHeight, 60+(30*numel(varName)))];
            
            self.VariableName = varName;
            self.VariableSelected = true(size(varName));
            self.ValidName = true(size(varName));
            
            create(self,varName,labelMsg);
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self,varName,labelMsg)
            
            create@images.internal.app.utilities.OkCancelDialog(self);
            
            % If there are too many entries, ensure the dialog is
            % scrollable.
            self.FigureHandle.Scrollable = self.MaxHeight < 60+(30*numel(varName));

            % Reposition the OK and Cancel buttons to ensure "Cancel" is
            % not covered by the slider
            if self.FigureHandle.Scrollable
                self.Ok.Position(1) = self.Ok.Position(1) - 2*self.ButtonSpace;
                self.Cancel.Position(1) = self.Cancel.Position(1) - 2*self.ButtonSpace;
            end

            for idx = 1:numel(varName)
                add(self,varName(idx),labelMsg(idx),idx, numel(varName));
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Add-------------------------------------------------------------
        function add(self,var,msg,idx, totalNumEntries)
            
            originalVar = var;
            varidx = 1;
            
            while evalin('base',sprintf('exist(''%s'',''var'') ~= 0',var))
                var = strcat(originalVar,string(varidx));
                varidx = varidx + 1;
            end
            
            self.VariableName(idx) = var;
            
            if self.FigureHandle.Scrollable
                hEFWidth = self.Size(1)/2 - round(3*self.ButtonSpace);
            else
                hEFWidth = (self.Size(1)/2) - round(1.5*self.ButtonSpace);
            end

            hEditField = uieditfield('text',...
                'Tag', var,...
                'Parent', self.FigureHandle,...
                'Position',[ (self.Size(1)/2) + (0.5*self.ButtonSpace), ...
                             (idx*self.ButtonSize(2)) + (idx+2)*self.ButtonSpace, ...
                             hEFWidth, ...
                             self.ButtonSize(2) ],...
                'FontSize', 12,...
                'Value',var,...
                'ValueChangingFcn',@(src,evt) validateVariableName(self,src,evt.Value,idx));
            
            if totalNumEntries>1
                uicheckbox('Parent', self.FigureHandle,...
                    'Tag', msg,...
                    'Tooltip',msg,...
                    'Position', [ self.ButtonSpace, ...
                                  (idx*self.ButtonSize(2)) + (idx+2)*self.ButtonSpace, ...
                                  (self.Size(1)/2) - round(1.5*self.ButtonSpace), ...
                                  self.ButtonSize(2) ],...
                    'FontSize', 12,...
                    'FontName','Helvetica',...
                    'Value',1,...
                    'ValueChangedFcn',@(src,evt) checkBoxChanged(self,evt.Value,idx,hEditField),...
                    'Text',msg);
            else
                uilabel('Parent', self.FigureHandle,...
                    'Tag', msg,...
                    'Tooltip',msg,...
                    'Position', [ self.ButtonSpace, ...
                                  (idx*self.ButtonSize(2)) + (idx+2)*self.ButtonSpace, ...
                                  (self.Size(1)/2) - round(1.5*self.ButtonSpace), ...
                                  self.ButtonSize(2) ],...
                    'FontSize', 12,...
                    'FontName','Helvetica',...
                    'Text',msg);               
            end
            
        end
        
        %--Validate Variable Name------------------------------------------
        function validateVariableName(self,src,val,idx)
            
            if isempty(val)
                self.VariableName(idx) = "";
                self.ValidName(idx) = false;
                src.FontColor = [0 0 0];
            elseif isvarname(val)
                self.VariableName(idx) = string(val);
                self.ValidName(idx) = true;
                src.FontColor = [0 0 0];
            else
                self.VariableName(idx) = "";
                self.ValidName(idx) = false;
                src.FontColor = [1 0 0];
            end
            
            updateOkState(self);
            
        end
        
        %--Update Ok State-------------------------------------------------
        function updateOkState(self)
            
            if any(self.VariableSelected) && all(self.ValidName(self.VariableSelected))
                self.Ok.Enable = 'on';
            else
                self.Ok.Enable = 'off';
            end
            
        end
        
        %--Check Box Changed-----------------------------------------------
        function checkBoxChanged(self,val,idx,hEditField)
            
            self.VariableSelected(idx) = logical(val);
            
            if val
                set(hEditField,'Editable','on','Enable','on');
            else
                set(hEditField,'Editable','off','Enable','off');
            end
            
            updateOkState(self);
            
        end
        
    end
    
end
