classdef App < handle
   
    properties (GetAccess = {?uitest.factory.Tester})
       Model
       View
       Controller
    end
    
    methods
       
        function self = App(BW)
            self.View = images.internal.app.regionAnalyzer2.View();
                        
            self.Model = images.internal.app.regionAnalyzer2.Model();
            self.Controller = images.internal.app.regionAnalyzer2.Controller(self.Model,self.View);
                        
            % Tie the lifecycle of the app to the view
            addlistener(self.View,'ObjectBeingDestroyed',@(hobj,evt) delete(self));

            % Wait for the View to be ready prior to loading data, since
            % loading data creates events that the view needs to respond
            % to, and the appropriate graphics objects like the table/image
            % display need to be ready.
            waitfor(self.View,'AppState',matlab.ui.container.internal.appcontainer.AppState.RUNNING)
            
            if nargin > 0
                loadBW(self.Model,BW);
            end
        end 
    end
end