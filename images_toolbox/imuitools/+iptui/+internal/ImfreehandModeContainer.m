classdef ImfreehandModeContainer < handle    
    % This undocumented class may change or be removed in a future release.
    
    % ImfreehandModeContainer is a container of Freehand objects. Each time
    % an interactive placement gesture of Freehand is completed, an
    % additional instance of Freehand is added to the property hROI. The
    % client enables the ability to add to the container by calling
    % enableInteractivePlacement.
    
    % Copyright 2014-2020 The MathWorks, Inc.
    
    events
        DrawingAborted
        DrawingStarted
    end
    
    properties (Access = private)
        hFig
        hParent
        
        MouseClickListener
        MouseMotionListener
        
        drawingAborted = false;
    end
    
    properties (GetAccess = public, Constant = true)
        Kind = 'Freehand';
    end
    
    properties (SetAccess = private, SetObservable = true)
        hROI  % Handles to imfreehand ROIs
    end

    properties(GetAccess = ?uitest.factory.Tester)
        Tag = "FreehandManager"
    end
    
    methods
        function obj = ImfreehandModeContainer(hParent)
                    
            obj.hFig = ancestor(hParent,'figure');
            obj.hParent = hParent;
            obj.hROI = images.roi.Freehand.empty();
            
            obj.MouseClickListener = addlistener(obj.hFig, 'WindowMousePress', @(~,evt) obj.mouseClickCallback(evt));
            obj.MouseClickListener.Enabled = false;
            
            obj.MouseMotionListener = addlistener(obj.hFig, 'WindowMouseMotion', @(src,evt) obj.managePointer(src,evt));
            obj.MouseMotionListener.Enabled = false;

        end
        
        function enableInteractivePlacement(obj)
            obj.MouseClickListener.Enabled = true;
            obj.MouseMotionListener.Enabled = true;
        end
        
    end
    
    methods(Access = protected)
        function mouseClickCallback(self, evt)
            hAx = ancestor(evt.HitObject, 'axes');
            if ~isempty(hAx) && (hAx == self.hParent)
                self.drawFreehand(evt);
            end
        end
        
        function managePointer(self, src, evt)
            
            hitAxes = ancestor(evt.HitObject, 'axes');
            if ~isempty(hitAxes) && (hitAxes == self.hParent) && ~isModeManagerActive(self)
                images.roi.setBackgroundPointer(src,'crosshair');
            else
                images.roi.setBackgroundPointer(src,'arrow');
            end
            
        end
        
        function drawFreehand(self, evt)
            
            notify(self, 'DrawingStarted');
            newFreehand  = images.roi.Freehand('Parent',self.hParent);
            newFreehand.beginDrawingFromPoint(evt.Source.CurrentAxes.CurrentPoint([1,3]))
            
            images.roi.setBackgroundPointer(self.hFig, 'arrow');
            
            self.MouseClickListener.Enabled = false;
            self.MouseMotionListener.Enabled = false;
            
            if ~self.drawingAborted && isvalidFreehand(self,newFreehand)
                self.hROI(end+1) = newFreehand;
            else
                self.notify('DrawingAborted');
                self.drawingAborted = false;
                newFreehand.delete();
            end
        end
        
        function flag = isvalidFreehand(~,newFreehand)
            if ~isvalid(newFreehand) || isempty(newFreehand.Position)
                flag = false;
                return
            end
            flag = numel(newFreehand.Position(:,1)) >= 3;
        end
        
        function TF = isModeManagerActive(self)
            hManager = uigetmodemanager(self.hFig);
            hMode = hManager.CurrentMode;
            TF = isobject(hMode) && isvalid(hMode) && ~isempty(hMode);
        end
    end

    methods(Access = ?uitest.factory.Tester)
        function setROI(self, value)
            self.hROI = value;
        end
    end
end
