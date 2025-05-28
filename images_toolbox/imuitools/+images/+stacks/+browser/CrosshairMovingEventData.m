classdef (ConstructOnLoad) CrosshairMovingEventData < event.EventData
% images.stack.browser.CrosshairMovingEventData Event data passed when the
% Crosshair is moving
% data = images.stack.browser.CrosshairMovingEventData(oldPos,newPos)
% packages the event data associated with the MovingCrosshair and
% CrosshairMoved events for the orthosliceViewer objects. oldPos and newPos
% are the Crosshair's Position before and after movement.
%
% This object is created by the orthosliceViewer and broadcast with events
% MovingCrosshair and CrosshairMoved in response to interactive movement.
% These events will not be fired in response to any programmatic
% positioning of the SliceNumbers. If you wish to broadcast this event at a
% time that does not coincide with interactive movement, you can manually
% package this event data and broadcast the event.
%
%   % Example: Listen to 'CrosshairMoved' event
%   % Load data and orthosliceViewer
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','images','vol_001.mat'));
%   s = orthosliceViewer(vol);
%
%   % Listen to CrosshairMoved event
%   addlistener(s,'CrosshairMoved',@(src,evt) disp('CrosshairMoved event has been broadcast'));
%
% CrosshairMovingEventData properties:
%       Source                - Event source
%       EventName             - Name of event
%       PreviousPosition      - Position before Crosshair moved
%       CurrentPosition       - Position after Crosshair moved

% Copyright 2019, The Mathworks Inc.
    
    properties
        PreviousPosition
        CurrentPosition
    end
    
    methods
        
        function data = CrosshairMovingEventData(old,new)
            data.PreviousPosition = old;
            data.CurrentPosition = new;
        end
        
    end
end