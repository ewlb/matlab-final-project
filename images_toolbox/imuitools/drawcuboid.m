function h = drawcuboid(varargin)
%drawcuboid Create draggable, rotatable, reshapable cuboidal ROI
%    H = drawcuboid begins interactive placement of a cuboidal region
%    of interest (ROI) on the current axes. The function returns H, a handle
%    to an images.roi.Cuboid object. You can modify an ROI interactively
%    using the mouse. The ROI also supports a context menu that controls
%    aspects of its appearance and behavior.
%
%    H = drawcuboid(AX,____) creates the ROI on the axes specified by AX
%    instead of the current axes (gca).
%
%    H = drawcuboid(S,____) creates the ROI on the axes ancestor of the
%    Scatter object specified by S. During interactive placement, the
%    cuboid will snap to the nearest point defined by the Scatter object S.
%
%    H = drawcuboid(____, Name, Value) modifies the appearance of the ROI
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
%                      'auto'        - The drawing area is a superset of
%                                      the current axes limits and a
%                                      bounding box that surrounds the ROI
%                                      (default).
%                      'unlimited'   - The drawing area has no boundary and
%                                      ROIs can be drawn or dragged to
%                                      extend beyond the axes limits.
%                      [x,y,z,w,h,d] - The drawing area is restricted to an
%                                      area beginning at (x,y,z), with
%                                      width w, height h, and depth d.
%
%    'EdgeAlpha'       Transparency of ROI edge, specified as a scalar
%                      value in the range [0 1]. When set to 1, the ROI
%                      edge is fully opaque. When set to 0, the ROI edge is
%                      completely transparent. Default value is 1.
%
%    'FaceAlpha'       Transparency of ROI face, specified as a scalar
%                      value in the range [0 1]. When set to 1, the ROI
%                      faces are fully opaque. When set to 0, the ROI is
%                      completely transparent. Default value is 0.2.
%
%    'FaceAlphaOnHover' Transparency of ROI face directly underneath the 
%                       mouse pointer, specified as a scalar value in the
%                       range [0 1], 'none' to indicate no change to face
%                       transparency. When set to 1, the face under the
%                       mouse pointer is fully opaque. When set to 0, the
%                       face is completely transparent. Default value is
%                       0.4.
%
%    'FaceColorOnHover' Color of the ROI face directly underneath the mouse
%                       pointer, specified as a MATLAB ColorSpec or 'none'.
%                       By default, no change is made to the ROI face on
%                       hover. If you specify a FaceColorOnHover, the ROI
%                       face is colored by this value when the mouse is
%                       hovering over the face, and colored by the ROI
%                       Color otherwise. The intensities must be in the
%                       range [0,1].
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
%                      'off'     - Label is not visible.
%
%    'LineWidth'       Line width, specified as a positive value in points.
%                      The default value is three times the number of points
%                      per screen pixel.
%
%    'Parent'          ROI parent, specified as an axes object.
%
%    'Position'        Position of the cuboid, specified as a 1-by-6 array
%                      of the form [xmin, ymin, zmin, width, height, depth].
%                      This property updates automatically when you draw or
%                      move the cuboid.
%
%    'Rotatable'       Ability of the cuboid to be rotated, specified as
%                      one of these values:
%                      'none'  - ROI is not rotatable (default).
%                      'all'   - ROI is fully rotatable.
%                      'x'     - ROI can only be rotated about the x axis.
%                      'y'     - ROI can only be rotated about the y axis.
%                      'z'     - ROI can only be rotated about the z axis.
%
%    'RotationAngle'   Angle the ROI is rotated, specified as a 1-by-3
%                      numeric array of rotation angles in degrees about
%                      the x, y, and z axis, respectively. Rotation is
%                      applied about the ROI centroid in order z, then y,
%                      then x. The default value is [0 0 0]. When the ROI
%                      is rotated, use the Vertices property to determine
%                      the location of the rotated ROI. The value of
%                      RotationAngle does not impact the values in the
%                      Position property. Position represents the cuboid
%                      prior to any rotation. When the cuboid is
%                      rotated, use the Vertices property to determine the
%                      location of the rotated cuboid.
%
%    'ScrollWheelDuringDraw'   Ability of the scroll wheel to adjust the
%                              size of the cuboid during interactive
%                              placement, specified as one of these values:
%                              'allresize' - Scroll wheel will impact all
%                                            ROI dimensions.
%                              'xresize'   - Scroll wheel will impact only
%                                            the x dimension.
%                              'yresize'   - Scroll wheel will impact only
%                                            the y dimension.
%                              'zresize'   - Scroll wheel will impact only
%                                            the z dimension.
%                              'none'      - Scroll wheel has no effect.
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
%   % Define vectors for 3-D scattered data.
%   [x,y,z] = sphere(16);
%   X = [x(:)*.5 x(:)*.75 x(:)];
%   Y = [y(:)*.5 y(:)*.75 y(:)];
%   Z = [z(:)*.5 z(:)*.75 z(:)];
% 
%   % Specify the size and color of each marker.
%   S = repmat([1 .75 .5]*10,numel(x),1);
%   C = repmat([1 2 3],numel(x),1);
% 
%   % Create a 3-D scatter plot and use view to change the angle of the
%   % axes in the figure.
%   figure
%   hScatter = scatter3(X(:),Y(:),Z(:),S(:),C(:),'filled'); 
%   view(-60,60);
% 
%   % Begin placing a cuboid in the axes that snaps to the nearest point
%   % from the scatter plot. Adjust the size of the cuboid during
%   % interactive placement by using the scroll wheel.
%   drawcuboid(hScatter);
%
%
%    See also: images.roi.Cuboid, drawcircle, drawellipse, drawfreehand,
%    drawline, drawpoint, drawpolygon, drawpolyline, drawrectangle,
%    drawassisted

% Copyright 2018-2020 The MathWorks, Inc.

% Get handle to Scatter object
if nargin > 0 && isa(varargin{1},'matlab.graphics.chart.primitive.Scatter')
    s = varargin{1};
    varargin{1} = ancestor(s,'axes');
    snapToPoints = true;
else
    snapToPoints = false;
end

% Create ROI using formal interface
h = images.roi.Cuboid(varargin{:});

if isempty(h.Parent)
    h.Parent = gca;
end

% If ROI was not fully defined, start interactive drawing
if isempty(h.Position)
    if any(h.RotationAngle ~= 0)
        warning(message('images:imroi:unusedParameter','RotationAngle'));
    end
    figure(ancestor(h,'figure'))
    if snapToPoints
        h.draw(s);
    else
        h.draw;
    end
end