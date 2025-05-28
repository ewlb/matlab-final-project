classdef ColorSpaceMontageViewWeb < handle
    %

    %   Copyright 2021-2023 The MathWorks, Inc.

    properties
        % Handles to figure and panels
        hFigDocument
        hFig             
        hPanels
        hGam

        % Background color of 3D plots
        rgbColor
        
        % Default projections for each color space
        pcaProjHolder
        
        RGBButton
        HSVButton
        YCBCRButton 
        LABButton
    end
    
    properties (SetObservable)
       
        % String specifying color space that was chosen by user
        SelectedColorSpace
        
        % Transformation matrix for current 3D view
        tMat
        
        % Camera Position for current view
        camPosition
        camVector
        
    end
    
    methods
        
        function self = ColorSpaceMontageViewWeb(app,RGB,rgbColor,rotatePointer, statusBar)
            
            group = app.getDocumentGroup('Tabs');
            
            if isempty(group)
                group = matlab.ui.internal.FigureDocumentGroup();
                group.Title = "Tabs";
                group.Tag = "Tabs";
                app.add(group);
            end
            
            % Add a figure-based document
            figOptions.Title = getString(message('images:colorSegmentor:chooseColorspace'));
            figOptions.DocumentGroupTag = group.Tag;
            figOptions.Tag = "csMontage";
            
            self.hFigDocument = matlab.ui.internal.FigureDocument(figOptions);
            
            self.hFig = self.hFigDocument.Figure;
            
            self.hFig.Tag = 'clusterFigure';
            self.hFig.AutoResizeChildren = 'off';

            app.add(self.hFigDocument);
            
            % Set the WindowKeyPressFcn to a non-empty function. This is
            % effectively a no-op that executes everytime a key is pressed
            % when the App is in focus. This is done to prevent focus from
            % shifting to the MATLAB command window when a key is typed.
            self.hFig.WindowKeyPressFcn = @(~,~)[];
            
            self.rgbColor = rgbColor;
            iptPointerManager(self.hFig);
         
            hGrid = uigridlayout(self.hFig, [3 4], ...
                                 "ColumnSpacing",20,"RowSpacing",20);
            hGrid.RowHeight = {'1x', '4x', '5x'};
            
            [hRGB, self.RGBButton]    = self.layoutMontageView(hGrid,1,'R','G','B','RGB');
            [hHSV, self.HSVButton]    = self.layoutMontageView(hGrid,2,'H','S','V','HSV');
            [hYCbCr, self.YCBCRButton]  = self.layoutMontageView(hGrid,3,'Y','Cb','Cr','YCbCr');
            [hLAB, self.LABButton]    = self.layoutMontageView(hGrid,4,'L*','a*','b*','L*a*b*');

            impanel = uigridlayout(hGrid, [1 1], 'Tag','imPreview');
            impanel.Layout.Row = 3;
            impanel.Layout.Column = [1 4];
            
            hImax = axes('Parent',impanel,'hittest','off','tag','previewAxes');
            hImax.Toolbar.Visible = 'off';
            
            % Obtain thumbnail sized representation of RGB input image so
            % that we can avoid needing to compute full scale color
            % transformation.  
            imPreview = iptui.internal.resizeImageToFitWithinAxes(hImax,RGB);
            
            doubleDataOutsideZeroOneRange = isfloat(imPreview) && (any(imPreview(:) < 0) || any(imPreview(:) > 1));
            
            if doubleDataOutsideZeroOneRange
                imPreview = mat2gray(imPreview);
            end
            
            S = warning('off','images:imshow:magnificationMustBeFitForDockedFigure');
            imshow(RGB,'Parent',hImax);            
            warning(S);
            
            self.hPanels = [hRGB, hHSV, hYCbCr, hLAB, impanel];

            [hgamRGB, tMatRGB] = displayColorSpaceInPanel(hRGB, imPreview, 'RGB', self.rgbColor, rotatePointer);
            [hgamHSV, tMatHSV] = displayColorSpaceInPanel(hHSV, imPreview, 'HSV', self.rgbColor, rotatePointer);
            [hgamYCbCr, tMatYCbCr] = displayColorSpaceInPanel(hYCbCr, imPreview, 'YCbCr', self.rgbColor, rotatePointer);
            [hgamLAB, tMatLAB] = displayColorSpaceInPanel(hLAB, imPreview, 'L*a*b*', self.rgbColor, rotatePointer);
            
            self.hGam = [hgamRGB hgamHSV hgamYCbCr hgamLAB];
            self.pcaProjHolder = {tMatRGB, tMatHSV, tMatYCbCr, tMatLAB};
            
            % No colorspace is selected in the initial state.
            self.SelectedColorSpace = '';
                                             
            set(self.hFig,'HandleVisibility','callback');
            
            % Make the panel visible once set up
            impanel.Visible = 'on';
            
            statusBar.setStatus( getString(message('images:colorSegmentor:colorSpaceHintMessage')));
                         
        end

        function [hImagePanel, b] = layoutMontageView(self,hParent,gridColumn,~,~,~,colorSpaceString)
            % layoutMontageView - layout each color space 
            hImagePanel = uigridlayout(hParent, [1 1], 'Tag','imagepanel');

            hImagePanel.Layout.Row = 2;
            hImagePanel.Layout.Column = gridColumn;

            g = uigridlayout(hParent, [4 3]);
            g.Layout.Row = 1;
            g.Layout.Column = gridColumn;

            g.RowHeight = {'1x','1x','1x','1x'};
            b = uibutton(g, 'Text',colorSpaceString,...
                'ButtonPushedFcn',@(src,evt) self.selectFromButtons(src,evt),...
                'FontWeight','bold');
            
            b.Layout.Row = [1 3];
            b.Layout.Column = 2;
            

        end


        function selectFromButtons(self,src,~)
            % selectFromButtons - Callback for when a color space is
            % selected
            
            % Updating the contents of SelectedColorSpace will trigger an
            % event in ColorSegmentationTool to create a new document
            if isempty(self.SelectedColorSpace)
                self.customProjection(src.Text)
                self.SelectedColorSpace = src.Text;
                if(isvalid(self.hFig))
                    close(self.hFig);
                end
                if(isvalid(self.hFigDocument))
                    close(self.hFigDocument); 
                end
            end
            
        end
        
        
        function customProjection(self,csname)
            % customProjection - Determines the transformation matrix for
            % the current view of the selected color space
            
            % Find selected color space
            switch csname
                case 'RGB'
                    hAx = findobj(self.hGam(1).Children,'type','axes');
                case 'HSV'
                    hAx = findobj(self.hGam(2).Children,'type','axes');
                case 'YCbCr'
                    hAx = findobj(self.hGam(3).Children,'type','axes');
                case 'L*a*b*'
                    hAx = findobj(self.hGam(4).Children,'type','axes');
            end
            
            % Obtain the transformation matrix for the current projection
            T = view(hAx);
            
            % Define matrix to normalize transformation matrix based on
            % axes limits
            xl=get(hAx,'xlim');
            yl=get(hAx,'ylim');
            zl=get(hAx,'zlim');
            
            N=[1/(xl(2)-xl(1)) 0 0 0; ...
              0 1/(yl(2)-yl(1)) 0 0; ...
              0 0 1/(zl(2)-zl(1)) 0; ...
              0 0 0 1];
          
            % Normalize transformation matrix
            self.tMat = T*N;
            
            % Get relative camera position vector to apply to 3D view
            self.camPosition = hAx.CameraPosition - hAx.CameraTarget;
            self.camVector = hAx.CameraUpVector;
             
        end
        
        
        function updateScatterBackground(self,rgbColor)
            % updateScatterBackground - Set the background color of the 3D
            % plots
            
            self.rgbColor = rgbColor;
            hScat = findall(self.hPanels,'type','scatter');
            arrayfun( @(h) set(h.Parent, 'Color',rgbColor), hScat);
            
        end
        
        
        function delete(self)
            % Cleanup associated figure when delete is called
            delete(self.hFig);
        end
        
        
        function bringToFocusInSpecifiedPosition(self)
            % Bring document tab to front 
            self.hFigDocument.Showing = 1;
        end
        
        
        function setVisible(self)
            set(self.hFig,'Visible','on');
        end
        
        
        function setInvisible(self)
            set(self.hFig,'Visible','off');
        end
        
    end
    
    % Methods provided for testing
    methods
        
        function hButton = getButtonHandle(self,csname)
            %getButtonHandle - This method returns the handle to the
            %uicontrol that selects the color space in the montage view.
            %Possible values for csname are 'RGB', 'HSV', 'YCbCr', and
            %'L*a*b*'
            
            hButton = findobj(self.hPanels,'Style','pushbutton','-and','String',csname);
            
        end

    end
    
end

function [hgam, tMatPCA] = displayColorSpaceInPanel(hpanel, RGB, csname, rgbColor, rotatePointer)

% Add axes containing each PCA projection. 0,0 is at bottom left of
% parent panel.

hgam = findobj(hpanel,'tag','imagepanel');

createScatterPlot(RGB, csname, hgam);

% Customize colorcloud axes
hAx = findobj(hgam,'Type','Axes');
reset(hAx)

hAx.Toolbar.Visible = 'off';

hScat = findobj(hgam,'Type','Scatter');

% Obtain PCA projection to use as default view
if strcmp(csname,'L*a*b*') || strcmp(csname,'YCbCr')
    im = [hScat.ZData' hScat.XData' hScat.YData'];
    im = bsxfun(@minus, im, cast(mean(im,1), 'like', im));
    set(hScat,'XData',im(:,2),'YData',im(:,3),'ZData',im(:,1));
else
    im = [hScat.XData' hScat.YData' hScat.ZData'];
    im = bsxfun(@minus, im, cast(mean(im,1), 'like', im));
    set(hScat,'XData',im(:,1),'YData',im(:,2),'ZData',im(:,3));
end

if size(im,1) < 3
    im = padarray(im,[1 0],'symmetric','both');
end

[~,~,coeff] = svd(im,'econ');
tMatPCA = double(coeff(1:3,1:3));

% Set axes settings for scatter plots
hAx.XLim = images.internal.app.colorThresholderWeb.setAxesLimits(hScat.XData);
hAx.YLim = images.internal.app.colorThresholderWeb.setAxesLimits(hScat.YData);
hAx.ZLim = images.internal.app.colorThresholderWeb.setAxesLimits(hScat.ZData);
set(hAx,'box','on',...
    'Color',rgbColor,...
    'XColor',[0.5 0.5 0.5],...
    'YColor',[0.5 0.5 0.5],...
    'ZColor',[0.5 0.5 0.5],...
	'XTick',[],...
    'YTick',[],...
    'ZTick',[],...
    'Units','normalized',...
	'Position',[0.05 0.05 0.9 0.9]);

grid(hAx,'off')
set(hgam,'Tag','gamut');

% Set viewpoint
view(hAx,tMatPCA(:,3));

% Turn off hittest for all children of gamut panels for
% callback that toggles rotate3d on and off
handleList = allchild(hgam.Children);
arrayfun( @(h) set(h, 'HitTest','off'), handleList);

iptSetPointerBehavior(hAx,@(hObj,evt) set(hObj,'Pointer','custom','PointerShapeCData',rotatePointer));

hAx.Interactions = rotateInteraction;
end

function createScatterPlot(RGB, csname, hgamut)

hAx = axes('Parent',hgamut);

% Convert RGB data into specified colorspace
colorData = computeColorspaceRepresentation(RGB,csname);

% Resize data into 1D array
[m,n,~] = size(RGB);
colorData = reshape(colorData,[m*n 3]);
RGB = reshape(RGB,[m*n 3]);
colorData = single(colorData);

switch (csname)
    case 'RGB'
        scatter3(hAx,colorData(:,1),colorData(:,2),colorData(:,3),6,im2double(RGB),'.');
        
    case 'HSV'
        % Convert to cartesian coordinates from conical coordinates for
        % plotting with scatter3
        Xcoord = colorData(:,2).*colorData(:,3).*cos(2*pi*colorData(:,1));
        Ycoord = colorData(:,2).*colorData(:,3).*sin(2*pi*colorData(:,1));
        Zcoord = colorData(:,3);
        
        s = scatter3(hAx,Xcoord,Ycoord,Zcoord,6,im2double(RGB),'.');
        s.PickableParts = 'none';
        view(hAx,20,30);
        
    case 'YCbCr'
        scatter3(hAx,colorData(:,2),colorData(:,3),colorData(:,1),6,im2double(RGB),'.');

    case 'L*a*b*'
        scatter3(hAx,colorData(:,2),colorData(:,3),colorData(:,1),6,im2double(RGB),'.');

    otherwise
        assert(false,'Unknown color space specified.');
end

end


function cdata = computeColorspaceRepresentation(RGB,csname)

% Convert data into specified colorspace representation
switch (csname)   
    case 'RGB'
        cdata = RGB;
    case 'HSV'
        cdata = rgb2hsv(RGB);
    case 'YCbCr'
        cdata = rgb2ycbcr(RGB);
    case 'L*a*b*'
        cdata = rgb2lab(RGB);
    otherwise
        assert(false,'Unknown color space specified.')
end

end

