function h = drawpoint(varargin)
%drawpoint Create draggable point ROI
%    H = drawpoint begins interactive placement of a point region of
%    interest (ROI) on the current axes. The function returns H, a handle to
%    an images.roi.Point object. You can modify an ROI interactively using
%    the mouse. The ROI also supports a context menu that controls
%    aspects of its appearance and behavior.
%
%    H = drawpoint(AX,____) creates the ROI on the axes specified by AX
%    instead of the current axes (gca)
%
%    H = drawpoint(____, Name, Value) modifies the appearance of the ROI
%    using one or more name-value pairs.
%
%    Parameters include:
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
%    'DrawingArea'     Area of the axes in which you can interactively place
%                      the ROI, specified as one of these values:
%
%                      'auto'      - The drawing area is a superset of the 
%                                    current axes limits and a bounding box
%                                    that surrounds the ROI (default).
%                      'unlimited' - The drawing area has no boundary and
%                                    ROIs can be drawn or dragged to
%                                    extend beyond the axes limits.
%                      [x,y,w,h]   - The drawing area is restricted to an
%                                    area beginning at (x,y), with
%                                    width w and height h.
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
%    'InteractionsAllowed' Interactivity of the ROI, specified as one of
%                          these values:
%                          'all'      - ROI is fully interactable (default).
%                          'none'     - ROI is not interactable and no drag
%                                       points are visible.
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
%
%    'Parent'          ROI parent, specified as an axes object.
%
%    'Position'        Position of the point, specified as a 1-by-2 array
%                      of the form [x y] where x and y are coordinates of
%                      the point ROI. This property updates automatically
%                      when you draw or move the ROI.
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
%                      'off' - Hide the ROI without deleting it. You still
%                              can access the properties of an invisible ROI.
%
%
%    Example 1
%    ---------
%
%    % Display an image
%    figure;
%    imshow(imread('baby.jpg'));
%
%    % Begin interactive placement of a point
%    h = drawpoint();
%
%    % Add a tag to the ROI
%    h.Tag = 'My Point';
%
%
%    Example 2
%    ---------
%
%    % Display an image
%    figure;
%    imshow(imread('baby.jpg'));
%
%    % Programmatically place ROI
%    h = drawpoint('Position',[100,100]);
%
%
%    See also: images.roi.Point, drawcircle, drawellipse, drawfreehand,
%    drawline, drawpolygon, drawpolyline, drawrectangle, drawassisted,
%    drawcuboid

% Copyright 2018-2020 The MathWorks, Inc.

% Create ROI using formal interface
h = images.roi.Point(varargin{:});

if isempty(h.Parent)
    h.Parent = gca;
end

% If ROI was not fully defined, start interactive drawing
if isempty(h.Position)
    figure(ancestor(h,'figure'))
    h.draw;
end