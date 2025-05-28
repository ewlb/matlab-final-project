%ORTHOSLICEVIEWER Browse orthogonal slices in grayscale or RGB volume.
%   ORTHOSLICEVIEWER(S) displays the image stack S in a figure, where S can
%   be a grayscale or RGB image stack.
%
%   H = ORTHOSLICEVIEWER(S) returns the handle to the orthosliceViewer object.
%
%   H = ORTHOSLICEVIEWER(__, Name, Value) specifies additional parameters
%   which are the properties of the orthosliceViewer object.
%
%   orthosliceViewer properties:
%
%   'Parent'           Parent is specified as a handle to a uipanel, figure
%                      or uifigure. When no parent is provided, the
%                      orthosliceViewer object is parented to gcf.
%
%   'Colormap'         Colormap of the image stack, with values in the range
%                      [0 1]. Colormap has no effect when RGB image stack
%                      is used.
%                      Default: gray(256)
%                      Note: This property has no affect when working with
%                      MxNxPxC RGB volumes.
%
%   'DisplayRange'     Two-element vector [LOW HIGH] that controls the
%                      display range of an image stack. The value LOW (and
%                      any value less than LOW) displays as black, the
%                      value HIGH (and any value greater than HIGH)
%                      displays as white. Values in between are displayed
%                      as intermediate shades of gray, using the default
%                      number of gray levels. When specified as an empty
%                      matrix ([]), the display range is set to the default
%                      value. DisplayRange has no effect when RGB image
%                      stack is used.
%                      Default: [min(S(:)) max(S(:))]
%                      Note: This property has no affect when working with
%                      MxNxPxC RGB volumes.
%
%   'ScaleFactors'     Scale factors used to rescale the image stack,
%                      specified as a [1x3] positive numeric array. The
%                      values in the array correspond to the scale factor
%                      applied in the x, y, and z direction.
%                      Default: [1 1 1]
%
%   'SliceNumbers'     A [1x3] nonnegative numeric vector, specifying the
%                      indices of the images to be displayed from the image
%                      stack. The corresponding slices at the [x,y,z]
%                      indices are displayed in YZ, XZ and XY axes in the
%                      Orthogonal view.
%                      Default: Center slices in the orthogonal directions.
%
%   'CrosshairColor'         Crosshair color, specified as a MATLAB ColorSpec.
%                            The intensities must be in the range [0,1].
%
%   'CrosshairLineWidth'     Line width, specified as a positive value in
%                            points.
%                            Default: Number of points per screen pixel.
%
%   'CrosshairStripeColor'   Color of the crosshair stripe, specified as a
%                            MATLAB ColorSpec. If you specify a StripeColor,
%                            the crosshair edge is striped, using a
%                            combination of the Color value and this value.
%                            The intensities must be in the range [0,1].
%                            Default: The edge of a crosshair is solid
%                            colored.
%
%   'CrosshairEnable'        State of the linked crosshair objects,
%                            specified as one of the following values:
%
%                            'on'        Visible and can be interacted with 
%                            'inactive'  Visible but no interactions allowed 
%                            'off'       Not visible
%                             
%                            Default: 'on'
%
%   'DisplayRangeInteraction'   Interactively control the DisplayRange of a
%                               grayscale image stack by left clicking the
%                               mouse and dragging it on the axes, specified
%                               as one of the following values:
%
%                               'on'   - DisplayRange interactions turned on
%                               'off'  - DisplayRange interactions turned off
%                               
%                               Default: 'on'  (grayscale intensity volumes)
%                                        'off' (logical or RGB volumes)
%
%   orthosliceViewer methods:
%
%   getAxesHandles      Returns handles to the XY, YZ and XZ axes displaying
%                       the corresponding slice
%                       [hXY, hYZ, hXZ] = getAxesHandles(h)
%
%   orthosliceViewer events:
%
%    CrosshairMoving    Event to notify when the Crosshair location is
%                       being interactively changed.
%
%    CrosshairMoved     Event to notify when the Crosshair location has 
%                       finished being interactively changed.
%
%   DisplayRange Interactions
%   -------------------------
%   Clicking and dragging the mouse within the target image interactively
%   changes the image's window values. Dragging the mouse horizontally from
%   left to right changes the window width (i.e., contrast). Dragging the
%   mouse vertically up and down changes the window center (i.e.,
%   brightness). Holding down the CTRL key when clicking accelerates
%   changes. Holding down the SHIFT key slows the rate of change. Keys must
%   be pressed before clicking and dragging.
%
%   Class Support
%   -------------
%   S is a scalar valued MxNxPxC image where C can be 1 or 3 for grayscale
%   or RGB volumes respectively. A MxNxPx3 RGB volume can be of class
%   uint8, uint16, single or double and MxNxP grayscale volume can be of
%   class logical, uint8, uint16, uint32, int8, int16, int32, single, or
%   double.
%
%
%   Example 1
%   ---------
%   % Visualize and easily browse MRI data using Crosshairs
%   % Load MRI data
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','images','vol_001.mat'));
% 
%   % View slices with custom Colormap
%   cmap = parula(256);
%   s = orthosliceViewer(vol,'Colormap',cmap);
%
%   Example 2
%   ---------
%   % Create a GIF of a slices
%   % Load and view MRI data
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','images','vol_001.mat'));
%   s = orthosliceViewer(vol);
% 
%   % Get axes handle where slice is displayed
%   [hXYAxes, hYZAxes, hXZAxes] = getAxesHandles(s);
%   
%   % Turn off Crosshair for better visibility
%   set(s,'CrosshairEnable','off');
% 
%   % Specify the name of the GIF file
%   filename = 'animatedYZSlice.gif';
% 
%   % Create an array of SliceNumbers in the required direction
%   % Consider YZ direction here
%   sliceNums = 1:240;
% 
%   % Loop through and create an image at slice position
%   for idx = sliceNums
%       % Update X slice number to get YZ Slice
%       s.SliceNumbers(1) = idx;
% 
%       % Use getframe to capture image
%       I = getframe(hYZAxes);
%       [indI,cm] = rgb2ind(I.cdata,256);
% 
%       % Write frame to the GIF File
%       if idx == 1
%           imwrite(indI,cm,filename,'gif','Loopcount',inf,'DelayTime',0.05);
%       else
%           imwrite(indI,cm,filename,'gif','WriteMode','append','DelayTime',0.05);
%       end
%   end
%
%
% See also sliceViewer, slice, volshow, volumeViewer, drawcrosshair

% Copyright 2019-2020 The MathWorks, Inc.
