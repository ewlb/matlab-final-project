classdef (ConstructOnLoad) SliderMovingEventData < event.EventData   
% images.stack.browser.SliderMovingEventData Event data passed when the
% slider is moving
% data = images.stack.browser.SliderMovingEventData(newPos) packages the
% event data associated with the MovingSlider and SliderMoved events for
% the sliceViewer objects. newPos is the slider's position after movement.
%
% This object is created by the sliceViewer and broadcast with events
% MovingSlider and SliderMoved in response to interactive movement. These
% events will not be fired in response to any programmatic positioning of
% the SliceNumber. If you wish to broadcast this event at a time that does
% not coincide with interactive movement, you can manually package this
% event data and broadcast the event.
%
%   % Example: Listen to 'MovingSlider' event
%   % Load data and sliceViewer
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','images','vol_001.mat'));
%   s = sliceViewer(vol);
%
%   % Listen to MovingSlider event
%   addlistener(s,'MovingSlider',@(src,evt) disp('MovingSlider event is being broadcast'));
%
% SliderMovingEventData properties:
%       Source           - Event source
%       EventName        - Name of event
%       CurrentValue     - Current slider value

% Copyright 2019, The Mathworks Inc.
    
    properties
        CurrentValue
    end
    
    methods
        
        function data = SliderMovingEventData(new)
            data.CurrentValue = new;
        end
        
    end
end