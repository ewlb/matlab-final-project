function setBackgroundPointer(fig,cursor,varargin)
% SETBACKGROUNDPOINTER Set figure pointer for Image Processing Toolbox ROIs.
%   SETBACKGROUNDPOINTER(FIG,CURSOR) sets the cursor of the figure
%   with handle FIG according to the name CURSOR. After setting the figure
%   pointer with this function, the pointer will be restored to CURSOR
%   anytime the mouse is not hovering over an ROI.
%
%   When using ROIs, this function is recommended over setting the figure
%   pointer directly. 
%
%   The following ROI-specific pointers are supported:
%      'drag'       - fleur symbol
%      'circle'     - circle symbol
%      'crosshair'  - crosshair symbol
%      'rotate'     - rotation symbol modified from circle and drag
%      'hand'       - hand symbol
%      'restricted' - international prohibition symbol
%      'north'      - up/down bidirectional arrow
%      'south'      - up/down bidirectional arrow
%      'east'       - left/right bidirectional arrow
%      'west'       - left/right bidirectional arrow
%      'NE'         - 45/225 degree bidirectional arrow
%      'SW'         - 45/225 degree bidirectional arrow
%      'NW'         - 135/315 degree bidirectional arrow
%      'SE'         - 135/315 degree bidirectional arrow
%      'dot'        - small dot symbol
%      'paintcan'   - paint can symbol
%
%   The following figure pointers are supported:
%      'arrow'
%      'ibeam'
%      'watch'
%      'topl'
%      'topr'
%      'botr'
%      'botl'
%      'cross'
%      'fleur'
%      'left'
%      'right'
%      'top'
%      'bottom'
%      'push' (standard figure 'hand' pointer)
%
%   SETBACKGROUNDPOINTER(FIG,CURSOR,CDATA,HOTSPOT) sets the cursor for the
%   figure as a custom cursor with CDATA and HOTSPOT as the figure
%   PointerShapeCData and PointerShapeHotSpot, respectively. When providing
%   CDATA and HOTSPOT, CURSOR must be set as 'custom'.
%
%   CDATA is specified as a 32-by-32 matrix (for a 32-by-32 pixel pointer)
%   or as a 16-by-16 matrix (for a 16-by-16 pixel pointer). Each element in
%   the matrix defines the brightness level for 1 pixel in the pointer.
%   Element (1,1) of the matrix corresponds to the pixel in the upper left
%   corner in the pointer. Set the matrix elements to one of these values:
%       1 — Black pixel.
%       2 — White pixel.
%       NaN — Transparent pixel, such that underlying screen shows through.
%
%   HOTSPOT is the active pixel of the pointer, specified as a two-element
%   vector. The vector contains the row and column indices of a particular
%   element in the CDATA matrix that corresponds to the desired active
%   pixel. The default value of [1 1] corresponds to the pixel in the upper
%   left corner of the pointer. If you specify a value outside the range of
%   the PointerShapeCData matrix, then the pointer uses the default active
%   pixel of [1 1] instead.

% Copyright 2019, The Mathworks Inc.

narginchk(2,4);

if any(strcmp(cursor,{'drag','circle','rotate','crosshair','hand','restricted','north','south','east','west','NE','SW','NW','SE','dot','paintcan'}))
    % User has specified one of the named ROI pointers. Let the internal
    % pointer switchyard handle validation.
    images.roi.internal.setROIPointer(fig,cursor);
    
elseif nargin == 2
    % User has specified one of the named figure pointers. Let the figure
    % handle validation.
    if strcmp(cursor,'push')
        set(fig,'Pointer','hand');
    else
        set(fig,'Pointer',cursor);
    end
    
else
    % User has specified a custom pointer and provided cdata and a hotspot.
    % Let the figure handle validation.
    set(fig,'Pointer',cursor,'PointerShapeCData',varargin{1},'PointerShapeHotSpot',varargin{2});
    
end

% The figure and pointer were both valid.
% Create the pointer manager if needed and add the pointer to the manager.
images.roi.internal.IPTROIPointerManager(fig);
fig.IPTROIPointerManager.Pointer = getptr(fig);

end