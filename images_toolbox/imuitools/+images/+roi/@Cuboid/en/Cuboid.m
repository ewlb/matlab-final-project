%images.roi.Cuboid Create draggable, rotatable, reshapable cuboidal ROI
%   
%    Cuboid properties:
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
%    'Vertices'        Locations of cuboid corners, specified as an 8-by-3
%                      array of vertices that lie along the perimeter of
%                      the cuboid after any rotation is applied. 
%                      Read-access only.
%
%    'Visible'         ROI visibility, specified as one of these values:
%
%                      'on'  - Display the ROI (default).
%                      'off' - Hide the ROI without deleting it. You
%                              still can access the properties of an
%                              invisible ROI.
%
%
%    Cuboid methods:
%
%    beginDrawingFromPoint  Begin drawing ROI from specified point.
%                           beginDrawingFromPoint(ROI, [x,y,z]) enters
%                           interactive mode to draw the shape for object
%                           ROI starting at location (x,y,z) in the axes.
%                           This method is intended to be used within the
%                           ButtonDownFcn callback of a Scatter or Axes
%                           object.
%
%                           beginDrawingFromPoint(ROI, [x,y,z], s) enters
%                           interactive mode to draw the shape for object
%                           ROI starting at location (x,y,z) in the axes,
%                           snapping to the nearest location to the mouse
%                           from the Scatter object s.
%
%                           beginDrawingFromPoint(ROI, [x,y,z], pos) enters
%                           interactive mode to draw the shape for object
%                           ROI starting at location (x,y,z) in the axes,
%                           snapping to the nearest location to the mouse
%                           from pos, specified as an Nx3 numeric array
%                           where each row represents the 3D spatial
%                           location of a potential placement position.
%  
%                           Example:
%     
%                           function cuboidExample
%                               [x,y,z] = sphere(16);
%                               X = [x(:)*.5 x(:)*.75 x(:)];
%                               Y = [y(:)*.5 y(:)*.75 y(:)];
%                               Z = [z(:)*.5 z(:)*.75 z(:)];
%   
%                               % Specify the size and color of each marker.
%                               S = repmat([1 .75 .5]*10,numel(x),1);
%                               C = repmat([1 2 3],numel(x),1);
%   
%                               % Create a 3-D scatter plot
%                               figure
%                               hScatter = scatter3(X(:),Y(:),Z(:),S(:),C(:),'filled'); 
%                               view(-60,60);
%
%                               % Begin drawing cuboids when a scatter
%                               % point is clicked
%                               hScatter.ButtonDownFcn = @(~,~) buttonPressedCallback(hScatter.Parent);
%  
%                               function buttonPressedCallback(hAx)
%                                   cp = hAx.CurrentPoint;
%                                   cp = cp(1,1:3);
%                                   obj = images.roi.Cuboid('Parent',hAx,'Color',rand([1,3]));
%                                   obj.beginDrawingFromPoint(cp);
%                               end
%                           end
%
%    bringToFront           Bring ROI to the front of the Axes stacking order.
%                           bringToFront(ROI) changes the stacking order of
%                           the Axes children to place the object ROI in
%                           front, giving the appearance that the ROI is in
%                           front of any other overlapping objects in the
%                           Axes. This method does not change the spatial
%                           location of the ROI.
%  
%                           This method is recommended over uistack when
%                           bringing a single ROI to the front of the
%                           stack. For alternate restacking behaviors, use
%                           uistack.
%
%    draw                   Begin drawing ROI.
%                           draw(ROI) enters interactive mode to draw the 
%                           shape for object ROI. If no parent has been 
%                           specified for ROI, the current axes (gca) will 
%                           be used when draw is called.
%
%                           draw(ROI, s) enters interactive mode to draw
%                           the shape for object ROI, snapping to the
%                           nearest location to the mouse from the Scatter
%                           object s.
%
%                           draw(ROI, pos) enters interactive mode to draw
%                           the shape for object ROI, snapping to the
%                           nearest location to the mouse from pos,
%                           specified as an Nx3 numeric array where each
%                           row represents the (x,y,z) location of a
%                           potential placement position.
%
%    inROI                  Points located inside or on edge of ROI.
%                           inROI(ROI,X,Y,Z) Returns logical array indicating
%                           if data points with coordinates (X,Y,Z) are 
%                           inside ROI. This method is intended for use 
%                           with scattered data.
%
%    wait                   Block MATLAB command line until ROI placement 
%                           is finished.
%                           wait(ROI) blocks execution of the MATLAB
%                           command line until you finish positioning the
%                           ROI object. Indicate completion by
%                           double-clicking on the ROI object.
%
%
%
%    Cuboid events:
%
%    DeletingROI       Event to notify when the ROI is about to be 
%                      interactively deleted.
%
%    DrawingStarted    Event to notify when the ROI is about to be 
%                      interactively drawn.
%
%    DrawingFinished   Event to notify when the ROI has been interactively 
%                      drawn.
%
%    MovingROI         Event to notify when the ROI shape or location is
%                      being interactively changed.
%
%    ROIMoved          Event to notify when the ROI shape or location has 
%                      finished being interactively changed.
%
%    ROIClicked        Event to notify when the ROI has been clicked.
%

%   Copyright 2018-2020 The MathWorks, Inc.