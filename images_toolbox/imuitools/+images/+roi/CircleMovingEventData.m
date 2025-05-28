classdef (ConstructOnLoad) CircleMovingEventData < event.EventData
% images.roi.CircleMovingEventData Event data passed when the circle ROI is moving
% data = images.roi.CircleMovingEventData(oldPos,newPos,oldR,newR) packages
% the event data associated with the MovingROI and ROIMoved events for the
% images.roi.Circle object. oldPos and oldR are the Circle's Center and
% Radius before the movement, whereas newPos and newR are the Circle's
% current Center and Radius.
%
% This object is created by the ROI and broadcast with events MovingROI and
% ROIMoved in response to interactive movement. These events will not be
% fired in response to any programmatic positioning of the Circle. If you
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
% h = images.roi.Circle(ax,'Center',[0.5 0.5],'Radius',0.2);
%
% % Add a listener to display ROI data when the ROI is being moved
% addlistener(h,'MovingROI',@(src,evt) disp(evt.CurrentRadius));
%
%
% Example 2: Package event data and manually broadcast event
% -------------------------------------------------------------------------
%
% ax = axes;
% h = images.roi.Circle(ax,'Center',[0.5 0.5],'Radius',0.2);
% addlistener(h,'ROIMoved',@(src,evt) disp('ROIMoved event has been broadcast'));
% 
% oldPos = h.Center;
% oldR = h.Radius;
% newPos = [0.6 0.7];
% newR = 0.1;
% 
% set(h,'Center',newPos,'Radius',newR);
% 
% evt = images.roi.CircleMovingEventData(oldPos,newPos,oldR,newR);
% notify(h,'ROIMoved',evt);
%
%
%   CircleMovingEventData properties:
%       Source              - Event source
%       EventName           - Name of event
%       PreviousCenter      - Position before ROI moved
%       CurrentCenter       - Position after ROI moved
%       PreviousRadius      - Radius before change in size
%       CurrentRadius       - Radius after change in size
    
% Copyright 2018-2019, The Mathworks Inc.
    
    properties
        
        % PreviousCenter - Position before ROI moved
        % Position before ROI moved, specified as a two-element numeric 
        % vector of the form [x y].
        PreviousCenter
        
        % CurrentCenter - Position after ROI moved
        % Position after ROI moved, specified as a two-element numeric 
        % vector of the form [x y]. If the circle is interactively resized
        % but not repositioned, this property will have the same value as
        % PreviousCenter.
        CurrentCenter
        
        % PreviousRadius - Radius before change in size
        % Radius before change in size, specified as a numeric scalar.
        PreviousRadius
        
        % CurrentRadius - Radius after change in size
        % Radius after change in size, specified as a numeric scalar. If
        % the circle is interactively translated but not resized, this
        % property will have the same value as PreviousRadius.
        CurrentRadius
        
    end
    
    methods
        
        function data = CircleMovingEventData(oldPos,newPos,oldR,newR)
            
            data.PreviousCenter = oldPos;
            data.CurrentCenter = newPos;
            
            data.PreviousRadius = oldR;
            data.CurrentRadius = newR;
            
        end
        
    end
end