function h = drawassisted(varargin)
%DRAWASSISTED Create freehand region on image with assistance from image edges
%   H = DRAWASSISTED begins interactive placement of a freehand region of
%   interest on an image in the current axes. The drawing process is
%   assisted by edges in the underlying image. The function returns H, a
%   handle to an assisted freehand object.
%
%   H = DRAWASSISTED(hImage,____) begins interactive placement of a
%   freehand region of interest on the image in the provided image handle,
%   hImage.
%
%   H = DRAWASSISTED(____, Name, Value) modifies the behavior of the
%   assisted freehand using one or more name-value pairs.
%
%   During interactive placement, left click and release to place first
%   waypoint. A live segment of the freehand boundary follows the mouse
%   cursor snapping to nearby edges in the image. Waypoints are placed by a
%   left click. Use the backspace key to delete the last waypoint. Click
%   and drag to override the assisted segment. Double click, right click or
%   click on the first waypoint to close the region. After the shape has
%   been drawn, click on the waypoints to reshape the corresponding region
%   of the freehand. No assistance is available in this mode.
%
%   When assistance cannot be computed in the available time, a straight
%   segment is returned. When assistance becomes available, moving the
%   mouse re-acquire the assisted segment.
%
%   New waypoints can be added after drawing via context menu or by
%   double-clicking on the freehand edge. Remove waypoints by
%   right-clicking on the waypoint and selecting "Remove Waypoint" from the
%   context menu.
%
%   Parameters include:
%
%    'Closed'          Set the geometry of the freehand ROI, specified as
%                      true (default) or false. If true, DRAWASSISTED draws
%                      an assisted segment to connect the point where you
%                      finish drawing with the point where you started
%                      drawing the ROI. If false, DRAWASSISTED leaves the
%                      first and last points unconnected.
%
%    'Color'           ROI color, specified as a MATLAB ColorSpec. The
%                      intensities must be in the range [0,1].
%
%    'ContextMenu'     Context menu, specified as a ContextMenu object. Use
%                      this property to display a custom context menu when
%                      you right-click on the ROI. Create the context menu
%                      using the uicontextmenu function.
%
%    'Deletable'       ROI can be interactively deleted via a context menu,
%                      specified as a logical scalar. When true (default),
%                      you can delete the ROI via the context menu. To
%                      disable this context menu item, set this property to
%                      false. Even when set to false, you can still delete
%                      the ROI by calling the delete function specifying the
%                      handle to the ROI, delete(H).
%
%    'FaceAlpha'       Transparency of ROI face, specified as a scalar
%                      value in the range [0 1]. When set to 1, the ROI is
%                      fully opaque. When set to 0, the ROI is completely
%                      transparent. Default value is 0.2.
%
%    'FaceSelectable'  Ability of the ROI face to capture clicks, specified
%                      as true or false. When true (default), you can
%                      select the ROI face. When false, you cannot select
%                      the ROI face by clicking.
%
%    'HandleVisibility'   Visibility of the ROI handle in the Children
%                         property of the parent, specified as one of these
%                         values:
%                         'on'      - Object handle is always visible
%                                     (default).
%                         'off'     - Object handle is never visible.
%                         'callback'- Object handle is visible from within
%                                     callbacks or functions invoked by
%                                     callbacks, but not from within
%                                     functions invoked from the command
%                                     line.
%
%    'Image'           Image handle, specified as an image object. If
%                      Parent is specified, it should be the parent axes of
%                      this image handle.
%
%    'InteractionsAllowed' Interactivity of the ROI, specified as one of
%                          these values:
%                          'all'      - ROI is fully interactable (default).
%                          'none'     - ROI is not interactable and no drag
%                                       points are visible.
%                          'reshape'  - ROI can be reshaped.
%                          'translate'- ROI can be translated (moved)
%                                       within the drawing area, but not
%                                       reshaped.
%
%    'Label'           ROI label, specified as a character vector or string.
%                      When this property is empty, no label is
%                      displayed (default).
%
%    'LabelAlpha'      Transparency of the text background, specified as a 
%                      scalar value in the range [0 1]. When set to 1, the
%                      text background is fully opaque. When set to 0, the
%                      text background is completely transparent. Default
%                      value is 1.
%
%    'LabelTextColor'  Label text color, specified as a MATLAB ColorSpec. 
%                      The intensities must be in the range [0,1].
%
%    'LabelVisible'    Visibility of the label, specified as one of these 
%                      values:
%                      'on'      - Label is visible when the ROI is visible
%                                  and the Label property is nonempty 
%                                  (default).
%                      'hover'   - Label is visible only when the mouse is
%                                  hovering over the ROI.
%                      'off'     - Label is not visible.
%
%    'LineWidth'       Line width, specified as a positive value in points.
%                      The default value is three times the number of points
%                      per screen pixel.
%
%    'MarkerSize'      Marker size, specified as a positive value in 
%                      points. The default value is eight times the number 
%                      of points per screen pixel.
%
%    'Parent'          ROI parent, specified as an axes object.
%
%    'Position'        Position of the ROI, specified as an n-by-2 array
%                      of the form, [x1 y1; ...; xn yn] where each row
%                      specifies the position of a vertex of the ROI.
%
%    'Selected'        Selection state of the ROI, specified as true or
%                      false. To set this property to true interactively,
%                      click the ROI. To clear the selection of the ROI,
%                      and set this property to false, ctrl-click the ROI.
%
%    'SelectedColor'   Color of the ROI when the Selected property is true,
%                      specified as a MATLAB ColorSpec. The intensities must
%                      be in the range [0,1]. If you specify the value
%                      'none', the Color property specifies the ROI color,
%                      irrespective of the value of the Selected property.
%
%    'Smoothing'       Standard deviation of the smoothing kernel used to
%                      filter the ROI, specified as numeric scalar.
%                      DRAWASSISTED uses a Gaussian smoothing kernel to
%                      filter the x- and y-coordinates of the freehand
%                      ROI after assisted placement. By default, the
%                      standard deviation is 1. The filter size is defined
%                      as 2*ceil(2*Smoothing) + 1.
%
%    'StripeColor'     Color of the ROI stripe, specified as a MATLAB
%                      ColorSpec. By default, the edge of an ROI is solid
%                      colored. If you specify a StripeColor, the ROI edge
%                      is striped, using a combination of the Color value
%                      and this value. The intensities must be in the range
%                      [0,1].
%
%    'Tag'             Tag to associate with the ROI, specified as a
%                      character vector or string.
%
%    'UserData'        Data to associate with the ROI, specified as any
%                      MATLAB data, for example, a scalar, vector,
%                      matrix, cell array, string, character array, table,
%                      or structure. MATLAB does not use this data.
%
%    'Visible'         ROI visibility, specified as one of these values:
%
%                      'on'  - Display the ROI (default).
%                      'off' - Hide the ROI without deleting it. You
%                              still can access the properties of an
%                              invisible ROI.
%
%    'Waypoints'       Placement of waypoints, specified as an n-by-1
%                      logical array where each row is either true or false.
%                      Where the Waypoints array is true, DRAWASSISTED
%                      places a waypoint at the position specified by the
%                      corresponding row of the Position property. The
%                      Waypoint array must be the same length as the
%                      Position property. If you interactively drag a
%                      waypoint, you modify the ROI between the specified
%                      waypoint and its immediate neighboring waypoints.
%                      If you specify an empty array, DRAWASSISTED generates
%                      the Waypoints array automatically at locations of
%                      increased curvature.
%
%
%   Example 1
%   ---------
%
%   % Display an image
%   figure;
%   im = imread('peppers.png');
%   imshow(im);
%
%   % Begin interactive placement of a freehand
%   h = drawassisted();
%
%   % Create an alpha mat
%   bw = createMask(h);
%   alphamat = imguidedfilter(single(bw), im, 'DegreeOfSmoothing', 2);
%
%   % Obtain target image and resize source and mask
%   target = imread('fabric.png');
%   alphamat = imresize(alphamat, [size(target,1), size(target,2)]);
%   im = imresize(im, [size(target,1), size(target,2)]);
%
%   % Alpha blend the source ROI into the target image
%   fused = single(im).*alphamat + (1-alphamat).*single(target);
%   fused = uint8(fused);
%   imshow(fused)
%
%   See also: images.roi.AssistedFreehand, drawfreehand, drawcircle,
%   drawellipse, drawline, drawpoint, drawpolygon, drawpolyline,
%   drawrectangle

% Copyright 2018-2020 The MathWorks, Inc.

% Create ROI using the formal interface
h = images.roi.AssistedFreehand(varargin{:});


% If ROI was not fully defined, start interactive drawing
if isempty(h.Position)
    if ~isempty(h.Waypoints)
        warning(message('images:imroi:unusedParameter','Waypoints'));
    end
    h.setAndCheckImage();
    figure(ancestor(h,'figure'))
    h.draw;
else
    % Position data given, show as a free hand on an axes (image check not
    % needed)
    h.Parent = gca;
end