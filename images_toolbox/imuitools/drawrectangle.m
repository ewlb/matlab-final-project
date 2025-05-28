function h = drawrectangle(varargin)
%drawrectangle Create draggable, rotatable, reshapable rectangular ROI
%    H = drawrectangle begins interactive placement of a rectangular region
%    of interest (ROI) on the current axes. The function returns H, a handle
%    to an images.roi.Rectangle object. You can modify an ROI interactively
%    using the mouse. The ROI also supports a context menu that controls
%    aspects of its appearance and behavior.
%
%    H = drawrectangle(AX,____) creates the ROI on the axes specified by AX
%    instead of the current axes (gca).
%
%    H = drawrectangle(____, Name, Value) modifies the appearance of the ROI
%    using one or more name-value pairs.
%
%    Parameters include:
%
%    'AspectRatio'     Aspect ratio of the rectangle, specified as a numeric
%                      scalar, defined as height/width. The value of this
%                      property changes automatically when you draw or move
%                      the ROI.
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
%    'FixedAspectRatio'   Aspect ratio remains constant during interaction,
%                         specified as true or false. When true,
%                         DRAWRECTANGLE maintains the aspect ratio as you
%                         draw or resize the ROI. When false (default), the
%                         aspect ratio can change when you draw or resize
%                         the ROI. You can change the state of this
%                         property in the default context menu.
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
%
%    'LabelVisible'    Visibility of the label, specified as one of these 
%                      values:
%                      'on'      - Label is visible when the ROI is visible
%                                  and the Label property is nonempty 
%                                  (default).
%                      'hover'   - Label is visible only when the mouse is
%                                  hovering over the ROI.
%                      'inside'  - Label is visible only when there is
%                                  adequate space inside the ROI to display
%                                  the label.
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
%    'Position'        Position of the rectangle, specified as an 1-by-4
%                      array of the form [xmin, ymin, width, height]. This
%                      property updates automatically when you draw or move
%                      the rectangle.
%
%    'Rotatable'       Ability of the rectangle to be rotated, specified as
%                      true or false (default). When false, the rectangle
%                      cannot be rotated. When true, you can rotate the
%                      rectangle by clicking near the markers at the
%                      corners of the rectangle.
%
%    'RotationAngle'   Angle the rectangle is rotated, specified as a numeric
%                      scalar. The angle value is in degrees and measured
%                      in a clockwise direction around the center of the
%                      rectangle. The value of this property changes
%                      automatically when you rotate the rectangle.
%                      The default value is 0. The value of RotationAngle
%                      does not impact the values in the Position property.
%                      Position represents the rectangle prior to any
%                      rotation. When the rectangle is rotated, use the
%                      Vertices property to determine the location of the
%                      rotated rectangle.
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
%                      'off' - Hide the ROI without deleting it. You
%                              still can access the properties of an
%                              invisible ROI.
%
%    Example 1
%    ---------
%
%    % Display an image
%    figure;
%    imshow(imread('baby.jpg'));
%
%    % Begin interactive placement of a rectangle
%    h1 = drawrectangle('Label','OuterRectangle','Color',[1 0 0]);
%
%    % Begin drawing a new rectangle and enforce that the new rectangle must
%    % be drawn inside the first rectangle
%    h2 = drawrectangle('Label','InnerRectangle','DrawingArea',h1.Position);
%
%
%    See also: images.roi.Rectangle, drawcircle, drawellipse, drawfreehand,
%    drawline, drawpoint, drawpolygon, drawpolyline, drawassisted,
%    drawcuboid

% Copyright 2018-2020 The MathWorks, Inc.

% Create ROI using formal interface
h = images.roi.Rectangle(varargin{:});

if isempty(h.Parent)
    h.Parent = gca;
end

% If ROI was not fully defined, start interactive drawing
if isempty(h.Position)
    if h.RotationAngle ~= 0
        warning(message('images:imroi:unusedParameter','RotationAngle'));
    end
    figure(ancestor(h,'figure'))
    h.draw;
end