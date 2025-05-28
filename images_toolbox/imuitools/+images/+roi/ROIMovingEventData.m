classdef (ConstructOnLoad) ROIMovingEventData < event.EventData
% images.roi.ROIMovingEventData Event data passed when the ROI is moving
% data = images.roi.ROIMovingEventData(oldPos,newPos) packages the event
% data associated with the MovingROI and ROIMoved events for the ROI
% object. oldPos and newPos are the ROI's Position before and after
% movement.
%
% This object is created by the ROI and broadcast with events MovingROI and
% ROIMoved in response to interactive movement. These events will not be
% fired in response to any programmatic positioning of the ROI. If
% you wish to broadcast this event at a time that does not coincide with
% interactive movement, you can manually package this event data and
% broadcast the event.
%
%
% Example 1: Listen to event and display event data during interaction
% -------------------------------------------------------------------------
%
% % Create ROI
% ax = axes;
% h = images.roi.Polyline(ax,'Position',[0.5 0.5; 0.3 0.4]);
%
% % Add a listener to display ROI data when the ROI is being moved
% addlistener(h,'MovingROI',@(src,evt) disp(evt.CurrentPosition));
%
%
% Example 2: Package event data and manually broadcast event
% -------------------------------------------------------------------------
%
% ax = axes;
% h = images.roi.Line(ax,'Position',[0.5 0.5; 0.3 0.4]);
% addlistener(h,'ROIMoved',@(src,evt) disp('ROIMoved event has been broadcast'));
% 
% oldPos = h.Position;
% newPos = [0.2 0.2; 0.3 0.4];
% 
% set(h,'Position',newPos);
% 
% evt = images.roi.ROIMovingEventData(oldPos,newPos);
% notify(h,'ROIMoved',evt);
%
%
%   ROIMovingEventData properties:
%       Source                - Event source
%       EventName             - Name of event
%       PreviousPosition      - Position before ROI moved
%       CurrentPosition       - Position after ROI moved
    
% Copyright 2018-2019, The Mathworks Inc.
    
    properties
        
        % PreviousPosition - Position before ROI moved
        % Position before the ROI moved, specified as the comma-separated 
        % pair consisting of an n-by-2 array of the form 
        % [x1 y1; ...; xn yn].
        PreviousPosition
        
        % CurrentPosition - Position after ROI moved
        % Position after the ROI moved, specified as the comma-separated 
        % pair consisting of an n-by-2 array of the form 
        % [x1 y1; ...; xn yn].
        CurrentPosition
        
    end
    
    methods
        
        function data = ROIMovingEventData(old,new)
            
            data.PreviousPosition = old;
            data.CurrentPosition = new;
            
        end
        
    end
end