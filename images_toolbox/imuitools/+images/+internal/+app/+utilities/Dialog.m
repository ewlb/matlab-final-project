classdef (Abstract) Dialog < handle
    %
    
    % Copyright 2019-2021 The MathWorks, Inc.
    
    properties (GetAccess = public, SetAccess = protected)
        
        FigureHandle matlab.ui.Figure
        
        % Size of the dialog [width, height]
        Size (1,2) double = [360, 120];
        
        % Title of the dialog as a string
        Title char = '';
        
    end
    
    properties (Hidden)
             
        Location (1,2) double = [100 100];
        
    end
    
    properties (Access = protected)
        
        ButtonSize (1,2) double = [80 20];
        ButtonSpace (1,1) double = 10;
        
    end
    
    methods (Abstract, Access = protected)
        
        keyPress(self,evt);
        
    end
    
    methods
        
        %------------------------------------------------------------------
        % Dialog
        %------------------------------------------------------------------
        function self = Dialog(loc, dlgTitle)
            
            self.Location = loc;
            self.Title = dlgTitle;
            
        end
        
        %------------------------------------------------------------------
        % Create
        %------------------------------------------------------------------
        function create(self)
            
            loc = imageslib.internal.app.utilities.ScreenUtilities.getModalDialogLocation(...
                self.Location, self.Size);
            
            self.FigureHandle = uifigure(...
                'Name', self.Title,...
                'Position', [loc self.Size],...
                'Resize','off',...
                'Visible','off');

            matlab.graphics.internal.themes.figureUseDesktopTheme(self.FigureHandle);
            
            addlistener(self.FigureHandle,'WindowKeyPress',@(src,evt) keyPress(self,evt));
            
            try %#ok<TRYNC>
                set(self.FigureHandle,'WindowStyle','modal');
            end
            
            movegui(self.FigureHandle, 'onscreen');
            
        end
        
        %------------------------------------------------------------------
        % Close
        %------------------------------------------------------------------
        function close(self)
            
            if ishandle(self.FigureHandle)
                close(self.FigureHandle);
            end
            
        end
        
        %------------------------------------------------------------------
        % Wait
        %------------------------------------------------------------------
        function wait(self)
            
            set(self.FigureHandle,'Visible','on');
            
            uiwait(self.FigureHandle);
            
            
        end
        
    end
    
    methods (Access = protected)
        
        %--Validate Key Press Support--------------------------------------
        function TF = validateKeyPressSupport(~,evt)
            % Return true if the keyboard press should be honored. This is
            % used to block keyboard shortcuts from happening when users
            % are interacting with objects that receive keyboard input. For
            % example, the enter key press should not close the dialog when
            % the user is currently typing in an editfield.
            TF = ~any(strcmp(class(evt.Source.CurrentObject),{...
                'matlab.ui.control.EditField',...
                'matlab.ui.control.DropDown',...
                'matlab.ui.control.DatePicker',...
                'matlab.ui.control.Spinner',...
                'matlab.ui.control.TextArea'}));
        end
        
    end
    
end
