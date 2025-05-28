classdef ImageSelectionEventData < event.EventData
%   Class that represents the event that is generated when thumbnails are
%   selected in the Thumbnail Browser.

%   Copyright 2021, The MathWorks Inc.

   properties(SetAccess=private, GetAccess=public)
       % Numeric Index of the Image(s) selected
       SelectedImageIdx;
       
       % Cell array of paths to the images selected
       SelectedImagePath;
   end
   
   methods
       function obj = ImageSelectionEventData(imageIdx, imagePath)
           obj.SelectedImageIdx = imageIdx;
           obj.SelectedImagePath = imagePath;
       end
   end
end