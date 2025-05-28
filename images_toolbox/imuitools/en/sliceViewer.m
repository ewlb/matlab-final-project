%SLICEVIEWER Browse slices in grayscale or RGB volume.
%   SLICEVIEWER(S) displays the image stack S in a figure, where S can be
%   grayscale or RGB image stack.
%
%   H = SLICEVIEWER(S) returns the handle to the sliceViewer object.
%
%   H = SLICEVIEWER(__, Name, Value) specifies additional parameters which
%   are the properties of the sliceViewer object.
%
%   sliceViewer properties:
%
%   'Parent'           Parent is specified as a handle to a uipanel, figure
%                      or uifigure. When no parent is provided, the sliceViewer
%                      object is parented to gcf.
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
%   'SliceDirection'   Direction to browse image stack in, specified as a
%                      [1x3] nonnegative numeric array or as a string or
%                      character and take following values:
%                         'X' or [1 0 0] - Browse in X direction
%                         'Y' or [0 1 0] - Browse in Y direction
%                         'Z' or [0 0 1] - Browse in Z direction
%                         
%                      Default: [0 0 1]
%
%   'SliceNumber'      A nonnegative numeric scalar, specifying the index
%                      of the image to be displayed from the image stack.
%                      The corresponding slice at the index is displayed in
%                      the axes.
%                      Default: Center slice in the specified SliceDirection
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
%   sliceViewer methods:
%
%   getAxesHandle      Returns handle to the axes displaying the slice
%                      hAxes = getAxesHandle(h)
%
%   sliceViewer events:
%
%    SliderValueChanging      Event to notify when the slider value is
%                             being interactively changed.
%
%    SliderValueChanged       Event to notify when the slider value has 
%                             finished being interactively changed.
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
%   Example 1
%   ---------
%   % Visualize MRI data
%   % Load MRI data
%   load mristack
%
%   % View slices with custom Colormap
%   cmap = parula(256);
%   s = sliceViewer(mristack,'Colormap',cmap);
%
%   Example 2
%   ---------
%   % Create a GIF of a slices
%   % Load and view MRI data
%   load mristack
%   s = sliceViewer(mristack);
% 
%   % Get axes handle where slice is displayed
%   hAx = getAxesHandle(s);
% 
%   % Specify the name of the GIF file
%   filename = 'animatedSlice.gif';
% 
%   % Create an array of SliceNumbers
%   sliceNums = 1:21;
% 
%   % Loop through and create an image at slice position
%   for idx = sliceNums
%       % Update slice number
%       s.SliceNumber = idx;
% 
%       % Use getframe to capture image
%       I = getframe(hAx);
%       [indI,cm] = rgb2ind(I.cdata,256);
% 
%       % Write frame to the GIF File
%       if idx == 1
%           imwrite(indI, cm, filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.05);
%       else
%           imwrite(indI, cm, filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.05);
%       end
%   end
%
%
% See also orthosliceViewer, slice, volshow, volumeViewer, drawcrosshair

% Copyright 2019-2020 The MathWorks, Inc.
