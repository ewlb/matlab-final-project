classdef ImpolyModeContainer < handle    
    % This undocumented class may change or be removed in a future release.
    
    % ImpolyModeContainer is a container of Polygon objects. Each time an
    % interactive placement gesture of Polygon is completed, an additional
    % instance of Polygon is added to the property hROI. The client enables
    % the ability to add to the container by calling
    % enableInteractivePlacement.
    
    % Copyright 2014-2020 The MathWorks, Inc.
    
    events
        DrawingAborted
        DrawingStarted
        ROIMoving
    end
    
    properties (Access = private)
        hFig
        hParent
        
        MouseClickListener
        MouseMotionListener
        
        drawingAborted = false;
    end
    
    properties (GetAccess = public, Constant = true)
        Kind = 'Polygon';
    end
    
    properties (SetAccess = private, SetObservable = true)
        hROI  % Handles to imfreehand ROIs
    end

    properties(GetAccess = ?uitest.factory.Tester)
        Tag = "PolygonManager"
    end
    
    methods
        function obj = ImpolyModeContainer(hParent)
                    
            obj.hFig = ancestor(hParent,'figure');
            obj.hParent = hParent;
            obj.hROI = images.roi.Polygon.empty();
            
            obj.MouseClickListener = addlistener(obj.hFig, 'WindowMousePress', @(~,evt) obj.mouseClickCallback(evt));
            obj.MouseClickListener.Enabled = false;
            
            obj.MouseMotionListener = addlistener(obj.hFig, 'WindowMouseMotion', @(src,evt) obj.managePointer(src,evt));
            obj.MouseMotionListener.Enabled = false;
                                 
        end
        
%         function enableInteractivePlacement(obj)
%             obj.MouseClickListener.Enabled = true;
%             newPolygon = drawpolygon('Parent',obj.hParent);
%             obj.MouseClickListener.Enabled = false;
%             
%             if ~obj.drawingAborted && isvalidPolygon(obj,newPolygon)
%                 obj.hROI(end+1) = newPolygon;
%             else
%                 obj.drawingAborted = false;
%                 newPolygon.delete();
%             end
%         end
        
        function enableInteractivePlacement(obj)
            obj.MouseClickListener.Enabled = true;
            obj.MouseMotionListener.Enabled = true;
        end
        
    end
    
    methods(Access = protected)
        function mouseClickCallback(self, evt)
            hAx = ancestor(evt.HitObject, 'axes');
            if ~isempty(hAx) && (hAx == self.hParent)
                self.drawPolygon(evt);
            end
        end
        
        function managePointer(self, src, evt)
            
            hitAxes = ancestor(evt.HitObject, 'axes');
            if isequal(hitAxes, self.hParent) 
                images.roi.setBackgroundPointer(src,'crosshair');
            else
                images.roi.setBackgroundPointer(src,'arrow');
            end
            
        end
        
        function drawPolygon(self, evt)
            
            notify(self, 'DrawingStarted');
            newPolygon  = images.roi.Polygon('Parent',self.hParent);
            newPolygon.beginDrawingFromPoint(evt.Source.CurrentAxes.CurrentPoint([1,3]))

            % Exit drawPolygon if user closes the colorspace tab or App 
            if ~(isvalid(self))
                return;
            else
                if(~isvalid(self.hFig))
                return;
                end
            end
            
            addlistener(newPolygon, 'MovingROI', @(~,~)onROIMove(self));
            
            images.roi.setBackgroundPointer(self.hFig, 'arrow');
            
            self.MouseClickListener.Enabled = false;
            self.MouseMotionListener.Enabled = false;
            
            if ~self.drawingAborted && isvalidPolygon(self,newPolygon)
                self.hROI(end+1) = newPolygon;
            else
                self.notify('DrawingAborted');
                self.drawingAborted = false;
                newPolygon.delete();
            end
        end
        
        function onROIMove(self)
            notify(self, 'ROIMoving');            
        end
        
        function flag = isvalidPolygon(~,newPolygon)
            if ~isvalid(newPolygon) || isempty(newPolygon.Position)
                flag = false;
                return
            end
            flag = numel(newPolygon.Position(:,1)) >= 3;
        end
    end

    methods(Access = ?uitest.factory.Tester)
        function setROI(self, value)
            self.hROI = value;
        end
    end
end
