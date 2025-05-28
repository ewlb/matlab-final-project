classdef (ConstructOnLoad) CuboidMovingEventData < event.EventData
% images.roi.CuboidMovingEventData Event data passed when the cuboid ROI is moving
% data = images.roi.CuboidMovingEventData(oldPos,newPos,oldTheta,newTheta)
% packages the event data associated with the MovingROI and ROIMoved events
% for the images.roi.Cuboid object. oldPos and oldTheta are the Cuboid's
% Position and RotationAngle before the movement, whereas newPos and
% newTheta are the Cuboid's current Position and RotationAngle.
%
% This object is created by the ROI and broadcast with events MovingROI and
% ROIMoved in response to interactive movement. These events will not be
% fired in response to any programmatic positioning of the Cuboid. If you
% wish to broadcast this event at a time that does not coincide with
% interactive movement, you can manually package this event data and
% broadcast the event.
%
%
% Example 1: Listen to event and display event data during interaction
% -------------------------------------------------------------------------
%
% % Create ROI
% ax = axes;
% view(3);
% h = images.roi.Cuboid(ax,'Position',[0.5 0.5 0.5 0.3 0.4 0.2],'RotationAngle',[0 0 45],'Rotatable','all');
%
% % Add a listener to display ROI data when the ROI is being moved
% addlistener(h,'MovingROI',@(src,evt) disp(evt.CurrentRotationAngle));
%
%
% Example 2: Package event data and manually broadcast event
% -------------------------------------------------------------------------
%
% ax = axes;
% view(3);
% h = images.roi.Cuboid(ax,'Position',[0.5 0.5 0.5 0.3 0.4 0.2],'RotationAngle',[0 0 45]);
% addlistener(h,'ROIMoved',@(src,evt) disp('ROIMoved event has been broadcast'));
% 
% oldPos = h.Position;
% oldTheta = h.RotationAngle;
% newPos = [0.2 0.2 0.2 0.3 0.4 0.2];
% newTheta = [0 0 60];
% 
% set(h,'Position',newPos,'RotationAngle',newTheta);
% 
% evt = images.roi.CuboidMovingEventData(oldPos,newPos,oldTheta,newTheta);
% notify(h,'ROIMoved',evt);
%
%
%   CuboidMovingEventData properties:
%       Source                - Event source
%       EventName             - Name of event
%       PreviousPosition      - Position before ROI moved
%       CurrentPosition       - Position after ROI moved
%       PreviousRotationAngle - Orientation before ROI rotated
%       CurrentRotationAngle  - Orientation after ROI rotated
    
% Copyright 2018-2019, The Mathworks Inc.
    
    properties
        
        % PreviousPosition - Position before ROI moved
        % Position before ROI moved, specified as a 1-by-6 numeric array of 
        % the form [x y z w h d].
        PreviousPosition
        
        % CurrentPosition - Position after ROI moved
        % Position after ROI moved, specified as a 1-by-6 numeric array of 
        % the form [x y z w h d]. If the cuboid is interactively rotated
        % but not repositioned, this property will have the same value as
        % PreviousPosition.
        CurrentPosition
        
        % PreviousRotationAngle - Orientation before ROI rotated
        % Orientation before ROI rotated, specified as a 1-by-3 numeric 
        % array, measured in degrees.
        PreviousRotationAngle
        
        % CurrentRotationAngle - Orientation after ROI rotated
        % Orientation after ROI rotated, specified as a 1-by-3 numeric
        % array, measured in degrees. If the cuboid is interactively
        % repositioned but not rotated, this property will have the
        % same value as PreviousRotationAngle.
        CurrentRotationAngle
        
    end
    
    methods
        
        function data = CuboidMovingEventData(oldPos,newPos,oldTheta,newTheta)
            
            data.PreviousPosition = oldPos;
            data.CurrentPosition = newPos;
            
            data.PreviousRotationAngle = oldTheta;
            data.CurrentRotationAngle = newTheta;
            
        end
        
    end
end