classdef DataBrowser < handle
    %

    % Copyright 2015-2020
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private) 
        
        HistoryList
        SegmentationList

        SegmentationPanel
        HistoryPanel
        
    end
    
    methods
        
        function self = DataBrowser(hApp)
            
            panelOptions.Title = getString(message('images:imageSegmenter:segmentationsBrowserLabel'));
            panelOptions.Tag = "ASegmentation Panel";
            panelOptions.Region = "left";
            self.SegmentationPanel = matlab.ui.internal.FigurePanel(panelOptions);
            
            set(self.SegmentationPanel.Figure,...
                'Units','pixels',...
                'HandleVisibility','off',...
                'AutoResizeChildren','off');
            
            hApp.App.add(self.SegmentationPanel);
            
            panelOptions.Title = getString(message('images:imageSegmenter:historyBrowserLabel'));
            panelOptions.Tag = "History Panel";
            panelOptions.Region = "left";
            self.HistoryPanel = matlab.ui.internal.FigurePanel(panelOptions);
            hApp.App.add(self.HistoryPanel);
            
            set(self.HistoryPanel.Figure,...
                'Units','pixels',...
                'HandleVisibility','off',...
                'AutoResizeChildren','off');
            
            hApp.App.LeftCollapsed = false;

            self.createSegmentationsSection(hApp)
            self.createHistorySection(hApp)
            
            drawnow;
            
            addlistener(self.SegmentationPanel.Figure,'WindowScrollWheel',@(src,evt) scroll(self.SegmentationList,evt.VerticalScrollCount));
            addlistener(self.HistoryPanel.Figure,'WindowScrollWheel',@(src,evt) scroll(self.HistoryList,evt.VerticalScrollCount));
            
        end
        
        function hBrowser = getHistoryBrowser(self)
            hBrowser = self.HistoryList;
        end
        
        function hBrowser = getSegmentationBrowser(self)
            hBrowser = self.SegmentationList;
        end
        
        function disable(self)
            disable(self.SegmentationList);
            disable(self.HistoryList);
        end
        
        function enable(self)
            enable(self.SegmentationList);
            enable(self.HistoryList);
        end
        
        function h = getHistoryFigure(self)
            h = self.HistoryPanel.Figure;
        end
        
        function h = getSegmentationFigure(self)
            h = self.SegmentationPanel.Figure;
        end
        
        function resize(self)
            resize(self.SegmentationList);
            resize(self.HistoryList);
        end
            
    end
    
    methods (Access = private)
        
        function createSegmentationsSection(self, hApp)
            self.SegmentationList = images.internal.app.segmenter.image.web.SegmentationBrowser(self.SegmentationPanel.Figure, hApp);
        end
        
        function createHistorySection(self, hApp)
            self.HistoryList = images.internal.app.segmenter.image.web.HistoryBrowser(self.HistoryPanel.Figure, hApp);
        end
        
    end
    
end
