classdef (ConstructOnLoad) RectangleMovingEventData < event.EventData
% images.roi.RectangleMovingEventData Event data passed when the rectangle ROI is moving
% data = images.roi.RectangleMovingEventData(oldPos,newPos,oldTheta,newTheta)
% packages the event data associated with the MovingROI and ROIMoved events
% for the images.roi.Rectangle object. oldPos and oldTheta are the
% Rectangle's Position and RotationAngle before the movement, whereas
% newPos and newTheta are the Rectangle's current Position and
% RotationAngle.
%
% This object is created by the ROI and broadcast with events MovingROI and
% ROIMoved in response to interactive movement. These events will not be
% fired in response to any programmatic positioning of the Rectangle. If
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
% h = images.roi.Rectangle(ax,'Position',[0.5 0.5 0.3 0.4],'RotationAngle',45);
%
% % Add a listener to display ROI data when the ROI is being moved
% addlistener(h,'MovingROI',@(src,evt) disp(evt.CurrentRotationAngle));
%
%
% Example 2: Package event data and manually broadcast event
% -------------------------------------------------------------------------
%
% ax = axes;
% h = images.roi.Rectangle(ax,'Position',[0.5 0.5 0.3 0.4],'RotationAngle',45);
% addlistener(h,'ROIMoved',@(src,evt) disp('ROIMoved event has been broadcast'));
% 
% oldPos = h.Position;
% oldTheta = h.RotationAngle;
% newPos = [0.2 0.2 0.3 0.4];
% newTheta = 60;
% 
% set(h,'Position',newPos,'RotationAngle',newTheta);
% 
% evt = images.roi.RectangleMovingEventData(oldPos,newPos,oldTheta,newTheta);
% notify(h,'ROIMoved',evt);
%
%
%   RectangleMovingEventData properties:
%       Source                - Event source
%       EventName             - Name of event
%       PreviousPosition      - Position before ROI moved
%       CurrentPosition       - Position after ROI moved
%       PreviousRotationAngle - Orientation before ROI rotated
%       CurrentRotationAngle  - Orientation after ROI rotated
    
% Copyright 2018-2019, The Mathworks Inc.
    
    properties

        % PreviousPosition - Position before ROI moved
        % Position before ROI moved, specified as a 1-by-4 numeric array of 
        % the form [x y w h].
        PreviousPosition
        
        % CurrentPosition - Position after ROI moved
        % Position after ROI moved, specified as a 1-by-4 numeric array of 
        % the form [x y w h]. If the rectangle is interactively rotated
        % but not repositioned, this property will have the same value as
        % PreviousPosition.
        CurrentPosition
        
        % PreviousRotationAngle - Orientation before ROI rotated
        % Orientation before ROI rotated, specified as a numeric scalar,
        % measured in degrees.
        PreviousRotationAngle
        
        % CurrentRotationAngle - Orientation after ROI rotated
        % Orientation after ROI rotated, specified as a numeric scalar,
        % measured in degrees. If the rectangle is interactively
        % repositioned but not rotated, this property will have the
        % same value as PreviousRotationAngle.
        CurrentRotationAngle
        
    end
    
    methods
        
        function data = RectangleMovingEventData(oldPos,newPos,oldTheta,newTheta)
            
            data.PreviousPosition = oldPos;
            data.CurrentPosition = newPos;
            
            data.PreviousRotationAngle = oldTheta;
            data.CurrentRotationAngle = newTheta;
            
        end
        
    end
end