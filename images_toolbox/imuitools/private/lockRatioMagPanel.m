function hgrid = lockRatioMagPanel(parent,hImLeft,hImRight,leftImageName,rightImageName,webImpl)
%lockRatioMagPanel Create panel to control magnification of two images.
%   HPANEL = ...
%      lockRatioMagPanel(PARENT,leftImage,rightImage,leftImageName,rightImageName)
%   displays magnification boxes for each image and a lock ratio check box.
%   PARENT is a handle to an object that can contain a uiflowcontainer.
%
%   Arguments returned include:
%      hPanel   - Handle to grid layout or Panel containing magboxes and check box

%   Copyright 2005-2021 The MathWorks, Inc.  

  hSpLeft = imshared.getimscrollpanel(hImLeft);
  hSpRight = imshared.getimscrollpanel(hImRight);
    
  apiLeft = iptgetapi(hSpLeft);
  apiRight = iptgetapi(hSpRight);
  hParentFigure = parent;

  if webImpl

      % Outer Grid layout for Label text, Mag boxes and lock ratio check box
      hgrid = uigridlayout(hParentFigure,[1 3]);
      hgrid.ColumnWidth = {'Fit','1x','Fit'};
      hgrid.Padding = 0;

      % Left label text or title
      hleftTitle = uilabel(hgrid,'Text',leftImageName);
      hleftTitle.HorizontalAlignment = 'Left';

      % Separate grid for the center three items - Mag boxes + check box
      hgrid2 = uigridlayout(hgrid,[1 5]);
      hgrid2.ColumnWidth = {'1x','Fit','Fit','Fit','1x'};

      % Left magnification dropdown 
      hleftCombo = images.internal.app.utilities.MagComboBox(hgrid2);
      hleftCombo.Layout.Column = 2;
      hleftCombo.ValueChangedFcn = @(o,e)updateScrollpanel(hleftCombo,apiLeft);

      % Initialize Left Mag box to scroll panel API magnification
      initialize(hleftCombo,apiLeft)

      hLockRatioCheckBox = uicheckbox(hgrid2,'Text',getString(message('images:privateUIString:lockRatioMagPanelString')),...
          'ValueChangedFcn',@updateRatio,'Position',[200 100 84 22],'Tag','LockRatioCheckBox' );
      hLockRatioCheckBox.Layout.Column = 3; 

      % Right magnification dropdown
      hrightCombo = images.internal.app.utilities.MagComboBox(hgrid2);
      hrightCombo.Layout.Column = 4;
      hrightCombo.ValueChangedFcn = @(o,e)updateScrollpanel(hrightCombo,apiRight);

      % Initialize Right Mag box to scroll panel API magnificationfmag
      initialize(hrightCombo,apiRight)

      % Right label text or title
      hrightTitle = uilabel(hgrid,'Text',rightImageName);
      hrightTitle.HorizontalAlignment = 'Right';

  else
      % Because we're creating MagnificationComboBoxes, we need to set the
      % Serializable property of the parent figure to 'off' (g1504700).
      while ~isa(hParentFigure, 'matlab.ui.Figure')
          hParentFigure = parent.Parent;
      end
      set(hParentFigure,'Serializable','off')

      [cbLeft,apiCbLeft] = immagboxjava;
      apiCbLeft.setScrollpanel(apiLeft);

      [cbRight,apiCbRight] = immagboxjava;
      apiCbRight.setScrollpanel(apiRight);

      % FLOW for titles and mag boxes
      hgrid = uiflowcontainer('v0',...
          'parent',parent,...
          'FlowDirection','lefttoright',...
                           'DeleteFcn',@deleteMagPanel);
  
      % Note: Order matters for these 3 calls as they all get parented to the same
      % object, and the order of the calls determines the location in the flow layout.
      hLeftTitlePanel           = uiflowcontainer('v0',...
          'Parent',hgrid,...
          'FlowDirection','lefttoright');
      hMagBoxesAndCheckBoxPanel = uiflowcontainer('v0',...
          'Parent',hgrid,...
          'FlowDirection','lefttoright');
      hRightTitlePanel          = uiflowcontainer('v0',...
          'Parent',hgrid,...
          'FlowDirection','righttoleft');

      uicontrol('Parent',hLeftTitlePanel,...
          'Style','text',...
          'HorizontalAlignment','left',...
          'String',leftImageName);

      uicontrol('Parent',hRightTitlePanel,...
          'Style','text',...
          'HorizontalAlignment','Right',...
          'String',rightImageName);

      % pin size to fit 2 magboxes plus checkbox
      midPanelW = 260;
      set(hMagBoxesAndCheckBoxPanel,'WidthLimits',[midPanelW midPanelW])

      % waiting for Bill York's update to javacomponent
      %javacomponentBY(cbLeft, [20 20 100 30], hMagBoxesAndCheckBoxPanel);

      hFig = ancestor(parent,'figure');

      % Note: Order matters for these calls as they all get parented to the same
      % object, and the order of the calls determines the location in the flow layout.

      % Add left mag box to panel
      % Workaround to parent java component to uiflowcontainer
      [dummy, hcLeft] = matlab.ui.internal.JavaMigrationTools.suppressedJavaComponent(cbLeft, [20 20 100 30], hFig); %#ok dummy
      cbLeft.setOpaque(true);
      set(hcLeft, 'Parent', hMagBoxesAndCheckBoxPanel);

      % Add spacer panel to leave a little space
      hSpacerPanel = uipanel('BorderType','none',...
          'Parent',hMagBoxesAndCheckBoxPanel);
      set(hSpacerPanel,'WidthLimits',[2 2]);

      % Create "Lock ratio" checkbox and get it looking pretty
      hLockRatioPanel = uipanel('Parent',hMagBoxesAndCheckBoxPanel);
      hLockRatioCheckBox = uicontrol('Parent',hLockRatioPanel,...
          'Style','checkbox',...
          'String',getString(message('images:privateUIString:lockRatioMagPanelString')),...
          'Callback',@updateRatio,...
          'Tag','LockRatioCheckBox');
      checkBoxExtent = get(hLockRatioCheckBox,'Extent');
      checkBoxW = checkBoxExtent(3) + 25; % + 25 gives room for box plus text
      set(hLockRatioPanel,'WidthLimits',[checkBoxW checkBoxW]);
      set(hLockRatioCheckBox,'Position',[0 0 checkBoxW-2 checkBoxExtent(4)])

      % Add right mag box to panel
      % Workaround to parent java component to uiflowcontainer
      [dummy, hcRight] = matlab.ui.internal.JavaMigrationTools.suppressedJavaComponent(cbRight, [20 20 100 30], hFig); %#ok dummy
      cbRight.setOpaque(true);
      set(hcRight, 'Parent', hMagBoxesAndCheckBoxPanel);

  end
  % Initialize for function scope
  fLeftOverRightMagnification = [];
  setLeftOverRightMagnification

  idMagLeft = apiLeft.addNewMagnificationCallback(@respondToLeftMagChange);
  idMagRight = apiRight.addNewMagnificationCallback(@respondToRightMagChange);

  %--------------------------------------------
    function initialize(hcombo,spapi)

        currentMag = spapi.getMagnification();
        hcombo.MagnificationValue = currentMag;

    end

%--------------------------------------------
    function updateScrollpanel(hcombo,spapi)
       
        if hcombo.isFitMag % Fit to Window
            newMag = spapi.findFitMag();
            hcombo.MagnificationValue = newMag;

        else % Others
            newMag = hcombo.MagnificationValue;
        end

        currentMag = spapi.getMagnification();
        % Make sure input data exists
        if (~isempty(currentMag) && ~isempty(newMag))
            % Only call setMagnification if the magnification changed.
            if images.internal.magPercentsDiffer(currentMag, newMag)
                spapi.setMagnification(newMag);
            end
        end
    end
%--------------------------------
    function deleteMagPanel(varargin) %#ok varargin needed by HG caller.

        apiLeft.removeNewMagnificationCallback(idMagLeft)
        apiRight.removeNewMagnificationCallback(idMagRight)

    end
  
  %--------------------------------------------
  function respondToLeftMagChange(mag)
    
    if isCheckBoxSelected
      magLeft = mag / getLeftOverRightMagnification;
      apiRight.setMagnification(magLeft)
    end

    if webImpl
        if isCheckBoxSelected
            hrightCombo.MagnificationValue = magLeft;
        else
            % Needed to trigger the update function in MagComboBox that
            % will parse the string for a custom value entered
            hleftCombo.MagnificationValue =  apiLeft.getMagnification();
        end
    end
     
  end
  
  %--------------------------------------------
  function respondToRightMagChange(mag)
    
    if isCheckBoxSelected
      magRight = mag * getLeftOverRightMagnification;
      apiLeft.setMagnification(magRight)
    end

    if webImpl
        if isCheckBoxSelected
            hleftCombo.MagnificationValue = magRight;
        else

            hrightCombo.MagnificationValue = apiRight.getMagnification();
        end
    end

  end
  
  %-----------------------------
  function updateRatio(varargin) %#ok varargin needed by HG caller.

    if isCheckBoxSelected
      setLeftOverRightMagnification
    end

  end

  %--------------------------------------------
  function setLeftOverRightMagnification

     fLeftOverRightMagnification = apiLeft.getMagnification() / ...
                                   apiRight.getMagnification();

  end

  %--------------------------------------------
  function ratio = getLeftOverRightMagnification

     ratio = fLeftOverRightMagnification;


  end
  
  %--------------------------------------------
  function isSelected = isCheckBoxSelected
    
     isSelected = isequal(get(hLockRatioCheckBox,'Value'),1);
   
  end

end
