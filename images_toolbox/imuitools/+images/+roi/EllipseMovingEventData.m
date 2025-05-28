classdef (ConstructOnLoad) EllipseMovingEventData < event.EventData
% images.roi.EllipseMovingEventData Event data passed when the ellipse ROI is moving
% data = images.roi.EllipseMovingEventData(oldPos,newPos,oldSemi,newSemi,oldTheta,newTheta)
% packages the event data associated with the MovingROI and ROIMoved events
% for the images.roi.Ellipse object. oldPos, oldSemi, and oldTheta are the
% Ellipse's Center, SemiAxes, and RotationAngle before the movement,
% whereas newPos, newSemi, and newTheta are the Ellipse's current Center,
% SemiAxes, and RotationAngle.
%
% This object is created by the ROI and broadcast with events MovingROI and
% ROIMoved in response to interactive movement. These events will not be
% fired in response to any programmatic positioning of the Ellipse. If
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
% h = images.roi.Ellipse(ax,'Center',[0.5 0.5],'SemiAxes',[0.3 0.4],'RotationAngle',45);
%
% % Add a listener to display ROI data when the ROI is being moved
% addlistener(h,'MovingROI',@(src,evt) disp(evt.CurrentSemiAxes));
%
%
% Example 2: Package event data and manually broadcast event
% -------------------------------------------------------------------------
%
% ax = axes;
% h = images.roi.Ellipse(ax,'Center',[0.5 0.5],'SemiAxes',[0.3 0.4],'RotationAngle',45);
% addlistener(h,'ROIMoved',@(src,evt) disp('ROIMoved event has been broadcast'));
% 
% oldPos = h.Center;
% oldSemi = h.SemiAxes;
% oldTheta = h.RotationAngle;
% newPos = [0.2 0.2];
% newSemi = [0.3 0.6];
% newTheta = 60;
% 
% set(h,'Center',newPos,'SemiAxes',newSemi,'RotationAngle',newTheta);
% 
% evt = images.roi.EllipseMovingEventData(oldPos,newPos,oldSemi,newSemi,oldTheta,newTheta);
% notify(h,'ROIMoved',evt);
%
%
%   EllipseMovingEventData properties:
%       Source                - Event source
%       EventName             - Name of event
%       PreviousCenter        - Center before ROI moved
%       CurrentCenter         - Center after ROI moved
%       PreviousSemiAxes      - Lengths of semiaxes before ROI was reshaped
%       CurrentSemiAxes       - Lengths of semiaxes after ROI was reshaped
%       PreviousRotationAngle - Orientation before ROI rotated
%       CurrentRotationAngle  - Orientation after ROI rotated
    
% Copyright 2018-2019, The Mathworks Inc.

    properties
        
        % PreviousCenter - Position before ROI moved
        % Position before ROI moved, specified as a two-element numeric 
        % vector of the form [x y].
        PreviousCenter
        
        % CurrentCenter - Position after ROI moved
        % Position after ROI moved, specified as a two-element numeric
        % vector of the form [x y]. If the ellipse is interactively
        % reshaped but not repositioned, this property will have the same
        % value as PreviousCenter.
        CurrentCenter
        
        % PreviousSemiAxes - Lengths of semiaxes before ROI was reshaped
        % Lengths of semiaxes before ROI was reshaped, specified as a 
        % two-element numeric vector.
        PreviousSemiAxes
        
        % CurrentSemiAxes - Lengths of semiaxes after ROI was reshaped
        % Lengths of semiaxes after ROI was reshaped, specified as a 
        % two-element numeric vector. If the ellipse is interactively
        % rotated or translated, this property will have the same value as
        % PreviousSemiAxes.
        CurrentSemiAxes
        
        % PreviousRotationAngle - Orientation before ROI rotated
        % Orientation before ROI rotated, specified as a numeric scalar,
        % measured in degrees.
        PreviousRotationAngle
        
        % - CurrentRotationAngle - Orientation after ROI rotated
        % Orientation after ROI rotated, specified as a numeric scalar,
        % measured in degrees. If the ellipse is interactively repositioned
        % but not rotated, this property will have the same value as
        % PreviousRotationAngle.
        CurrentRotationAngle
        
    end
    
    methods
        
        function data = EllipseMovingEventData(oldPos,newPos,oldSemi,newSemi,oldTheta,newTheta)
            
            data.PreviousCenter = oldPos;
            data.CurrentCenter = newPos;
            
            data.PreviousSemiAxes = oldSemi;
            data.CurrentSemiAxes = newSemi;
            
            data.PreviousRotationAngle = oldTheta;
            data.CurrentRotationAngle = newTheta;
            
        end
        
    end
end