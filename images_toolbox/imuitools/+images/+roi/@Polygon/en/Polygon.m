%images.roi.Polygon Create draggable, reshapable polygonal ROI
%   
%    Polygon properties:
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
%    Polygon methods:
%
%    beginDrawingFromPoint  Begin drawing ROI from specified point.
%                           beginDrawingFromPoint(ROI, [x,y]) enters
%                           interactive mode to draw the shape for object
%                           ROI starting at location (x,y) in the axes.
%                           This method is intended to be used within the
%                           ButtonDownFcn callback of an Image or Axes
%                           object.
%  
%                           Example:
%     
%                           function lineExample
%                               hIm = imshow(imread('coins.png'));
%                               hIm.ButtonDownFcn = @(~,~) buttonPressedCallback(hIm.Parent);
%  
%                               function buttonPressedCallback(hAx)
%                                   cp = hAx.CurrentPoint;
%                                   cp = [cp(1,1) cp(1,2)];
%                                   obj = images.roi.Line('Parent',hAx,'Color',rand([1,3]));
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
%    createMask             Create mask within image.
%                           createMask(ROI) returns a mask, or binary image
%                           of the same size as the target image, with
%                           pixels underneath the line are set to be true.
%                           The target image and the ROI must be parented
%                           to the same axes.
%  
%                           createMask(ROI,I) returns a mask, or binary
%                           image, with size equal to the first two
%                           dimensions of image I.
%  
%                           createMask(ROI,m,n) returns a mask, or binary
%                           image, that is size [m,n].
%
%                           createMask(ROI,hImage) returns a mask, or binary
%                           image, with size equal to the first two
%                           dimensions of the image in Image object hImage.
%
%    draw                   Begin drawing ROI.
%                           draw(ROI) enters interactive mode to draw the 
%                           shape for object ROI. If no parent has been 
%                           specified for ROI, the current axes (gca) will 
%                           be used when draw is called.
%
%    inROI                  Points located inside or on edge of ROI.
%                           inROI(ROI,X,Y) Returns logical array indicating
%                           if data points with coordinates (X,Y) are 
%                           inside ROI. this method is intended for use 
%                           with scattered data. To obtain a gridded mask, 
%                           use createMask.
%
%    reduce                 Reduce ROI vertices 
%                           reduce(ROI) reduces the number of points in the
%                           ROI as specified by the 'Position' property
%                           of the ROI.
%                            
%                           reduce(ROI,TOLERANCE)  reduces the number of
%                           points in a ROI with tolerance as an
%                           optional input argument. Tolerance must be in
%                           the range [0,1]. A tolerance of 0 would have a
%                           minimum reduction in points. A tolerance of 1
%                           would result in maximum reduction leaving only
%                           the end points of the polygon. The default
%                           value for tolerance is 0.001.
%
%    wait                   Block MATLAB command line until ROI placement 
%                           is finished.
%                           wait(ROI) blocks execution of the MATLAB
%                           command line until you finish positioning the
%                           ROI object. Indicate completion by
%                           double-clicking on the ROI object.
%
%
%    Polygon events:
%
%    AddingVertex      Event to notify when a vertex has been 
%                      interactively added to the ROI.
%
%    VertexAdded       Event to notify when a vertex is about to be 
%                      interactively added to the ROI.
%
%    DeletingVertex    Event to notify when a vertex is about to be 
%                      interactively deleted from the ROI.
%
%    VertexDeleted     Event to notify when a vertex has been 
%                      interactively deleted from the ROI.
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