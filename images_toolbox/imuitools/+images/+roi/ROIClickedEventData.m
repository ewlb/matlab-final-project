classdef (ConstructOnLoad) ROIClickedEventData < event.EventData
% images.roi.ROIClickedEventData Event data passed when the ROI is clicked
% data = images.roi.ROIClickedEventData(type,hit,oldSelected,newSelected)
% packages the event data associated with the ROIClicked event for the ROI
% object. oldSelected and newSelected are the ROI's Selected state before
% and after the click, type is the click type, and hit is the part of the
% ROI that was clicked.
%
% This object is created by the ROI and broadcast with event ROIClicked in
% response to interaction. This event will not be fired in response to any
% programmatic setting of the ROI Selected state. If you wish to broadcast
% this event at a time that does not coincide with interaction, you can
% manually package this event data and broadcast the event.
%
%
% Example 1: Listen to event and display event data during interaction
% -------------------------------------------------------------------------
%
% % Create ROI
% ax = axes;
% h = images.roi.Rectangle(ax,'Position',[0.5 0.5 0.3 0.4]);
% 
% % Add a listener to display ROI data when the ROI is clicked
% addlistener(h,'ROIClicked',@(src,evt) disp(evt.SelectionType));
%
%
% Example 2: Package event data and manually broadcast event
% -------------------------------------------------------------------------
%
% ax = axes;
% h = images.roi.Rectangle(ax,'Position',[0.5 0.5 0.3 0.4]);
% addlistener(h,'ROIClicked',@(src,evt) disp('ROIClicked event has been broadcast'));
% 
% % Deselect ROI
% oldSelected = h.Selected;
% newSelected = false;
% 
% % Simulate double click on face
% type = 'double';
% hit = 'face';
% 
% set(h,'Selected',newSelected);
% 
% evt = images.roi.ROIClickedEventData(type,hit,oldSelected,newSelected);
% notify(h,'ROIClicked',evt);
%
%
%   ROIClickedEventData properties:
%       Source             - Event source
%       EventName          - Name of event
%       SelectionType      - Type of selection
%       SelectedPart       - Part of ROI that was clicked
%       PreviousSelected   - Selection state prior to mouse click
%       CurrentSelected    - Selection state after mouse click
    
% Copyright 2018-2019, The Mathworks Inc.
    
    properties
        
        % SelectionType - Type of selection
        % 'left' | 'right' | 'double' | 'shift' | 'ctrl' | 'alt' | 'middle'
        % 'left'   - Selection type when ROI is interactively clicked using
        %            left mouse click.
        % 'right'  - Selection type when ROI is interactively clicked using
        %            right mouse click.
        % 'double' - Selection type when ROI is interactively double 
        %            clicked.
        % 'shift'  - Selection type when ROI is interactively clicked using
        %            shift-left mouse click.
        % 'ctrl'   - Selection type when ROI is interactively clicked using
        %            control-left mouse click.
        % 'alt'    - Selection type when ROI is interactively clicked using
        %            left mouse click with alt key pressed.
        % 'middle' - Selection type when:
        %            Windows - Both left and right mouse buttons clicked
        %            Mac     - Middle mouse button or both left and right 
        %                      mouse buttons clicked
        %            Linux   - Middle mouse button clicked
        SelectionType
        
        % SelectedPart - Part of ROI that was clicked
        % 'edge' | 'face' | 'label' | 'marker'
        % 'edge'   - User clicked on the edge line of the ROI.
        % 'face'   - User clicked on the face of the ROI. FaceSelectable
        %            must be set to true to capture clicks
        % 'label'  - User clicked on the ROI label.
        % 'marker' - User clicked on a marker used to reshape the ROI.
        SelectedPart
        
        % PreviousSelected - Selection state prior to mouse click
        % true | false
        % Selection state of the ROI before the ROI was clicked
        PreviousSelected
        
        % CurrentSelected - Selection state after mouse click
        % true | false
        % Selection state of the ROI after the ROI was clicked
        CurrentSelected
        
    end
    
    methods
        
        function data = ROIClickedEventData(type,hit,oldSelected,newSelected)
            
            data.SelectionType = type;
            data.SelectedPart = hit;
            
            data.PreviousSelected = oldSelected;
            data.CurrentSelected = newSelected;
            
        end
        
    end
end