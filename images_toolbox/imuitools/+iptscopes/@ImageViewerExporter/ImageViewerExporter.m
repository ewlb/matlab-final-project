classdef ImageViewerExporter < matlabshared.scopes.tool.Tool
   %IMAGEVIEWEREXPORTER Class definition for ImageViewerExporter
   
   %    Copyright 2015-2023 The MathWorks, Inc.
   
   properties(Access=protected)
       % Maintain a list of imageViewer app's that have been launched by
       % client. These apps are not all closed when the client app shuts
       % down. It is upto the user to close them as they see fit. Matches
       % the old behaviour
       IVAppList = []

       IVExporterButton
       IVExporterMenu
   end
   
   methods
       %Constructor
       function this = ImageViewerExporter(varargin)
           
           this@matlabshared.scopes.tool.Tool(varargin{:});
           
       end
   end
   
   methods(Access=protected)
       plugInGUI = createGUI(this)
       
       enableGUI(this, enabState)
       
       function lclExport(this)
           try
               export(this);
           catch ME
               uiscopes.errorHandler(ME.message);
           end
       end
   end
   
    methods(Static)
        propSet = getPropertySet
        
    end
end