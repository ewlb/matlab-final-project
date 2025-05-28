classdef Toolstrip < handle
    %

    % Copyright 2015-2023 The MathWorks, Inc.
    
    properties (GetAccess = ?uitest.factory.Tester, SetAccess = private)
        hActiveContoursTab
        hFloodFillTab
        hMorphologyTab
        hSegmentTab
        hThresholdTab
        hGraphCutTab
        hFindCirclesTab
        hGrabCutTab
        hROITab
        hPaintTab
        hSAMAddTab
        hSAMRefineTab
    end

    properties(Access = private)
        TabList
    end
    
    methods
        
        function self = Toolstrip(toolGroup, mainApp)
            self.addToolstripTabs(toolGroup, mainApp)
        end
        
        function showSegmentTab(self)
            self.hSegmentTab.show()
            self.hSegmentTab.makeActive()
        end
        
        function showActiveContourTab(self)
            self.hActiveContoursTab.show()
            self.hActiveContoursTab.makeActive()
        end
        
        function showFloodFillTab(self)
            self.hFloodFillTab.show()
            self.hFloodFillTab.makeActive()
        end
        
        function showMorphologyTab(self)
            self.hMorphologyTab.show()
            self.hMorphologyTab.makeActive()
        end

        function showThresholdTab(self)
            self.hThresholdTab.show()
            self.hThresholdTab.makeActive()
        end
        
        function showGraphCutTab(self)
            self.hGraphCutTab.show()
            self.hGraphCutTab.makeActive()
        end
        
        function showGrabCutTab(self)
            self.hGrabCutTab.show()
            self.hGrabCutTab.makeActive()
        end
        
        function showROITab(self)
            self.hROITab.show()
            self.hROITab.makeActive()
        end
        
        function showPaintTab(self)
            self.hPaintTab.show()
            self.hPaintTab.makeActive()
        end
        
        function showFindCirclesTab(self)
            self.hFindCirclesTab.show()
            self.hFindCirclesTab.makeActive()
        end

        function showSAMAddTab(self)
            self.hSAMAddTab.show();
            self.hSAMAddTab.makeActive();
        end

        function showSAMRefineTab(self)
            self.hSAMRefineTab.show();
            self.hSAMRefineTab.makeActive();
        end
        
        function hideSegmentTab(self)
            self.hSegmentTab.hide()
        end
        
        function hideActiveContourTab(self)
            self.hActiveContoursTab.hide()
        end
        
        function hideFloodFillTab(self)
            self.hFloodFillTab.hide()
        end
        
        function hideMorphologyTab(self)
            self.hMorphologyTab.hide()
        end

        function hideThresholdTab(self)
            self.hThresholdTab.hide()
        end
        
        function hideGraphCutTab(self)
            self.hGraphCutTab.hide()
        end
        
        function hideGrabCutTab(self)
            self.hGrabCutTab.hide()
        end
        
        function hideROITab(self)
            self.hROITab.hide()
        end
        
        function hidePaintTab(self)
            self.hPaintTab.hide()
        end
        
        function hideFindCirclesTab(self)
            self.hFindCirclesTab.hide()
        end

        function hideSAMAddTab(self)
            self.hSAMAddTab.hide()
        end

        function hideSAMRefineTab(self)
            self.hSAMRefineTab.hide()
        end
        
        function deleteTimers(self)
            state = saveState(self.hSegmentTab.TechniqueGallery.Popup);
            s = settings;
            s.images.imagesegmentertool.GalleryFavorites.PersonalValue = state;
            self.hFindCirclesTab.deleteTimer();
            self.hActiveContoursTab.deleteTimer();
            delete(self.hSegmentTab.CreateGallery);
            delete(self.hSegmentTab.AddGallery);
            delete(self.hSegmentTab.RefineGallery);
        end
        
        function setMode(self, mode)
            
            for idx = 1:numel(self.TabList)
                tab = self.TabList{idx};
                tab.setMode(mode)
            end
            
        end
       
        function opacity = getOpacity(self)
            opacity = self.hSegmentTab.getOpacity();
        end
        
        function TF = loadImageInSegmentTab(self,im)
            TF = self.hSegmentTab.importImageData(im);
        end
        
        function idx = findVisibleTabs(self)
            idx = [];
            for p = 1:numel(self.TabList)
                if (self.TabList{p}.Visible)
                    idx(end + 1) = p; %#ok<AGROW>
                end
            end
        end
        
        function TF = tabHasUncommittedState(self, tabIndex)
            TF = self.TabList{tabIndex}.HasUncommittedState;
        end
        
        function closeTab(self, tabIndex)
            self.TabList{tabIndex}.onClose()
        end
        
        function applyCurrentSettings(self, tabIndex)
            self.TabList{tabIndex}.onApply()
        end
        
        function stopActiveContours(self)
            self.hActiveContoursTab.forceSegmentationToStop()
        end
    end
    
    % Layout
    methods (Access=private)
        
        function addToolstripTabs(self, toolGroup, mainApp)
            
            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = "ImageSegmenterTabGroup";
            self.hSegmentTab = images.internal.app.segmenter.image.web.SegmentTab(toolGroup, tabGroup, self, mainApp, 1);
            self.hActiveContoursTab = images.internal.app.segmenter.image.web.ActiveContoursTab(toolGroup, tabGroup, self, mainApp, 2);
            self.hThresholdTab = images.internal.app.segmenter.image.web.ThresholdTab(toolGroup, tabGroup, self, mainApp, 3);
            self.hFloodFillTab = images.internal.app.segmenter.image.web.FloodFillTab(toolGroup, tabGroup, self, mainApp, 4);
            self.hMorphologyTab = images.internal.app.segmenter.image.web.MorphologyTab(toolGroup, tabGroup, self, mainApp, 5);
            self.hGraphCutTab = images.internal.app.segmenter.image.web.GraphCutTab(toolGroup, tabGroup, self, mainApp, 6);
            self.hFindCirclesTab = images.internal.app.segmenter.image.web.FindCirclesTab(toolGroup, tabGroup, self, mainApp, 7);
            self.hGrabCutTab = images.internal.app.segmenter.image.web.GrabCutTab(toolGroup, tabGroup, self, mainApp, 8);
            self.hROITab = images.internal.app.segmenter.image.web.ROITab(toolGroup, tabGroup, self, mainApp, 9);
            self.hPaintTab = images.internal.app.segmenter.image.web.PaintBrushTab(toolGroup, tabGroup, self, mainApp, 10);
            self.hSAMAddTab = images.internal.app.segmenter.image.web.SAMAddTab(toolGroup, tabGroup, self, mainApp, 11);
            self.hSAMRefineTab = images.internal.app.segmenter.image.web.SAMRefineTab(toolGroup, tabGroup, self, mainApp, 12);
            
            self.TabList = {self.hSegmentTab, ...
                self.hActiveContoursTab, ...
                self.hThresholdTab, ...
                self.hFloodFillTab, ...
                self.hMorphologyTab, ...
                self.hGraphCutTab, ...
                self.hFindCirclesTab, ...
                self.hGrabCutTab, ...
                self.hROITab, ...
                self.hPaintTab, ...
                self.hSAMAddTab, ...
                self.hSAMRefineTab };

            toolGroup.addTabGroup(tabGroup);

        end
        
    end
    
end