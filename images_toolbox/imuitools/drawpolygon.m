function h = drawpolygon(varargin)
%drawpolygon Create draggable, reshapable polygonal ROI
%    H = drawpolygon begins interactive placement of a polygonal region of
%    interest (ROI) on the current axes. The function returns H, a handle to
%    an image.roi.Polygon object. You can modify the ROI interactively using
%    the mouse.  The ROI also supports a context menu that controls aspects
%    of its appearance and behavior.
%
%    H = drawpolygon(AX,____) creates the ROI in the axes specified by AX
%    instead of the current axes (gca).
%
%    H = drawpolygon(____, Name, Value) modifies the appearance of the ROI
%    using one or more name-value pairs.
%
%    During interactive placement, left-click to add vertices as you move
%    the mouse over the image. To finish (close) the polygon, double-click.
%
%    To add a vertex after finishing a polygon, position the cursor over the
%    ROI and double-click or right-click and choose Add Vertex from the
%    context menu. To remove a vertex, position the cursor over the vertex,
%    right-click, and select "Delete Vertex" from the context menu.
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
%    'Position'        Position of the polygon, specified as an n-by-2
%                      array of the form [x1 y1; ...; xn yn] where each row
%                      specifies the position of a vertex of the polygon.
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
%    % Begin interactive placement of a polygon
%    h = drawpolygon();
%
%    % Make the polygon face transparent but still clickable
%    h.FaceAlpha = 0;
%    h.FaceSelectable = true;
%
%
%    See also: images.roi.Polygon, drawcircle, drawellipse, drawfreehand,
%    drawline, drawpoint, drawpolyline, drawrectangle, drawassisted,
%    drawcuboid

% Copyright 2018-2020 The MathWorks, Inc.

% Create ROI using formal interface
h = images.roi.Polygon(varargin{:});

if isempty(h.Parent)
    h.Parent = gca;
end

% If ROI was not fully defined, start interactive drawing
if isempty(h.Position)
    figure(ancestor(h,'figure'))
    h.draw;
end