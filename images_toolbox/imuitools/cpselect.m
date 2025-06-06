function varargout = cpselect(varargin)

matlab.images.internal.errorIfgpuArray(varargin{:});

if ~images.internal.isFigureAvailable()
  error(message('images:cpselect:cpselectNotAvailableOnThisPlatform'));
end

argsin = matlab.images.internal.stringToChar(varargin);

[input, base, cpstruct, args] = ParseInputs(argsin{:});

if args.Wait && nargout~=2
  error(message('images:cpselect:Expected2OutputArgs'))
end

if ~args.Wait && (nargout > 1)
   error(message('images:cpselect:TooManyOutputArgs')); 
end

% get names to label images
inputImageName = images.internal.legacyui.utils.getImageName(argsin{1},inputname(1));
baseImageName = images.internal.legacyui.utils.getImageName(argsin{2},inputname(2));

toolIdStream = images.internal.legacyui.utils.idStreamFactory('CpselectInstance');
toolNumber = toolIdStream.nextId(); 

toolName = getString(message('images:cpselectUIString:toolName',toolNumber));

%Create invisible figure
hFig = figure('Toolbar','none',...
              'Menubar','none',...
              'HandleVisibility','callback',...
              'IntegerHandle','off',...
              'NumberTitle','off',...
              'Tag','cpselect',...
              'Name',toolName,...
              'Visible','off',...       % turn visibility off to prevent flash
              'DeleteFcn',@deleteTool);

if(strcmpi(class(getCanvas(ancestor(hFig,'figure','toplevel'))),'matlab.graphics.primitive.canvas.HTMLCanvas'))
    webImpl = true;
    hFig.AutoResizeChildren = 'off';
else
    webImpl = false;
end

matlab.ui.internal.PositionUtils.setDevicePixelPosition(hFig,...
    getInitialPosition());
          
images.internal.legacyui.utils.suppressPlotTools(hFig);

          
% Set default 'HitTest','off' as workaround to HG issue
% We only want to manually turn on 'HitTest' for objects that will have
% a 'ButtonDownFcn' set.
images.internal.legacyui.utils.turnOffDefaultHitTestFigChildren(hFig);

[hScrollPanels,hImInput,hImBase,hSpInput,hSpBase] = ...
    leftRightImscrollpanel(hFig,input,base,webImpl);
[hOverviewPanels,hImOvInput,hImOvBase] = ...
    leftRightImoverviewpanel(hFig,hImInput,hImBase,webImpl);

% Stores the id returned by IPTADDCALLBACK for the image object's
% ButtonDownFcn callback.
ovInputImageButtonDownFcnId = [];
ovBaseImageButtonDownFcnId = [];

% Create titles
inputDetailLabel = getString(message('images:cpselectUIString:movingDetailLabel',inputImageName));
baseDetailLabel = getString(message('images:cpselectUIString:fixedDetailLabel',baseImageName));

hMagPanel = lockRatioMagPanel(hFig,hImInput,hImBase,inputDetailLabel,baseDetailLabel,webImpl);

% Turn on HitTest so ButtonDownFcn will fire when images are clicked
set([hImInput hImBase hImOvInput hImOvBase],'HitTest','on')
  
if webImpl
    % Outermost grid layout
    hgrid = uigridlayout(hFig,[3 1]);
    hgrid.RowHeight = {'Fit','1x','1x'};
    hgrid.RowSpacing = 0;
    hgrid.ColumnSpacing = 0;
    hgrid.Padding = 0;

    set(hMagPanel,'Parent',hgrid);
   
else
   % Overall flow panel
    hgrid = uiflowcontainer('v0',...
        'Parent',hFig,...
        'FlowDirection','topdown',...
        'Margin',1);

    set(hMagPanel,'Parent',hgrid);
    set(hMagPanel,'HeightLimits',[30 30]); % pin height
end

set(hScrollPanels,'Parent',hgrid)
set(hOverviewPanels,'Parent',hgrid)

% Get the scroll panel API to programmatically control the view
apiInput = iptgetapi(hSpInput);
apiBase = iptgetapi(hSpBase);

cpModeManager = images.internal.legacyui.utils.makeUIModeManager(@makeDefaultModeCurrent);

toolbar = uitoolbar(hFig);

pointButtons = makePointButtons(toolbar);
buttons = images.internal.legacyui.utils.navToolFactory(toolbar);

[addItem, addPredictItem, zoomInItem, zoomOutItem, panItem,...
 editMenuItems, overviewMenuItem] = deal([]);
createMenubar % initialize menu items

% Set up modes such that tool and menu items stay in sync
% Must be defined after calling createToolbar, createMenubar  
activateAddPointMode = cpModeManager.addMode(...
  pointButtons.addPoint,  addItem,       @makeAddModeCurrent);
cpModeManager.addMode(...
  pointButtons.addPredict,addPredictItem,@makeAddPredictModeCurrent);
cpModeManager.addMode(...
  buttons.zoomInTool,     zoomInItem,    @makeZoomInModeCurrent);
cpModeManager.addMode(...
  buttons.zoomOutTool,    zoomOutItem,   @makeZoomOutModeCurrent);
cpModeManager.addMode(...
  buttons.panTool,        panItem,       @makePanModeCurrent);

pointItems = struct('addMenuItem',addItem,...
                    'addPredictMenuItem',addPredictItem,...
                    'addButton',pointButtons.addPoint,...
                    'addPredictButton',pointButtons.addPredict,...
                    'activateAddPointMode',activateAddPointMode);
cpAPI = cpManager(cpstruct,hImInput,hImOvInput,hImBase,hImOvBase,...
                  editMenuItems,pointItems);

% Initializing for function scope
cpstruct2Export = [];

% Start tool ready to add points
activateAddPointMode();

% Set up pointer manager
iptPointerManager(hFig);

set(hFig,'Visible','on'); % turn on visibility after all drawn to avoid flash

% Initialize magnification of images.
% Note: Need to call DRAWNOW here to make sure figure has come up before 
%       calling setMagnification or images won't be centered.
drawnow 
findInitMag = @(api) 2 * images.internal.findZoomMag('in', api.findFitMag());
apiInput.setMagnification(findInitMag(apiInput))
apiBase.setMagnification(findInitMag(apiBase))

if args.Wait 
  uiwait(hFig)
  
  % Resuming because user either selected file->close from menus or clicked
  % close button of figure.  Both code paths lead to UIRESUME being called
  % which brings us back to here.
  if ishghandle(hFig)
      % If the figure handle still exists, we need to get the data out of it and
      % close the figure.
      cpstruct2Export = getCpstruct2Export();      
      close(hFig)   
  end
  
  [movingPoints,fixedPoints] = cpstruct2pairs(cpstruct2Export);
  
  varargout{1} = movingPoints;
  varargout{2} = fixedPoints;
  
else  
  set(hFig,'CloseRequestFcn',@closeRequestCpselect);
  
  if (nargout > 0)
    % Only return handle if caller requested it.
    varargout{1} = hFig;
  end

end

  %-------------------------------------
  function cpstruct = getCpstruct2Export
      cpstruct = cppairsvector2cpstruct(cpAPI.getInputBasePairs());
  end

  %-----------------------------------
  function setDetailImageMode(fun,ptr)

    removeDetailImageMode      
    
    enterFcn = @(f,cp) setptr(f,ptr);    
    iptSetPointerBehavior(hImInput, enterFcn);
    iptSetPointerBehavior(hImBase,  enterFcn);

    apiInput.setImageButtonDownFcn(fun)
    apiBase.setImageButtonDownFcn(fun)    
    
  end

  %-----------------------------
  function removeDetailImageMode
    
    fun = [];
    apiInput.setImageButtonDownFcn(fun)
    apiBase.setImageButtonDownFcn(fun)    
    
  end

  %-------------------------------
  function setAllImageCursors(ptr)
      
    enterFcn = @(f,cp) set(f, 'Pointer', ptr);
    
    iptSetPointerBehavior(hImInput,   enterFcn);
    iptSetPointerBehavior(hImBase,    enterFcn);
    iptSetPointerBehavior(hImOvInput, enterFcn);
    iptSetPointerBehavior(hImOvBase,  enterFcn);
    
  end
  
  %--------------------------------
  function setAllImageMode(fun,ptr)

    removeAllImageMode      

    setAllImageCursors(ptr)

    apiInput.setImageButtonDownFcn(fun)
    apiBase.setImageButtonDownFcn(fun)    
        
    if ~isempty(fun)
      ovInputImageButtonDownFcnId = iptaddcallback(hImOvInput,'ButtonDownFcn',fun);
      ovBaseImageButtonDownFcnId = iptaddcallback(hImOvBase,'ButtonDownFcn',fun);      
    else
      ovInputImageButtonDownFcnId = [];
      ovBaseImageButtonDownFcnId = [];
    end
    
  end

  %--------------------------
  function removeAllImageMode

    fun = [];
    
    apiInput.setImageButtonDownFcn(fun)
    apiBase.setImageButtonDownFcn(fun)    
  
    if ~isempty(ovInputImageButtonDownFcnId)
      iptremovecallback(hImOvInput,'ButtonDownFcn',ovInputImageButtonDownFcnId);
    end
    
    if ~isempty(ovBaseImageButtonDownFcnId)
      iptremovecallback(hImOvBase,'ButtonDownFcn',ovBaseImageButtonDownFcnId);
    end
    
  end

  %----------------------------------------
  function makeDefaultModeCurrent(varargin)

    fun = '';
    ptr = 'arrow';

    setAllImageMode(fun,ptr)

  end

  %---------------------------------------
  function makeZoomInModeCurrent(varargin)

    fun = @images.internal.legacyui.utils.imzoomin;
    ptr = 'glassplus';    
    
    setDetailImageMode(fun,ptr)

  end

  %----------------------------------------
  function makeZoomOutModeCurrent(varargin)

    fun = @images.internal.legacyui.utils.imzoomout;
    ptr = 'glassminus';
    
    setDetailImageMode(fun,ptr)

  end

  %------------------------------------
  function makePanModeCurrent(varargin)

    fun = @images.internal.legacyui.utils.impan;
    ptr = 'hand';
    
    setDetailImageMode(fun,ptr)

  end

  %------------------------------------
  function makeAddModeCurrent(varargin)

    removeAllImageMode
    
    ptr = 'crosshair';
    setAllImageCursors(ptr)
    
    funInput = cpAPI.addInputPoint;
    funBase = cpAPI.addBasePoint;    

    wireInputImages(funInput)
    wireBaseImages(funBase)

  end
  
  %-------------------------------------------
  function makeAddPredictModeCurrent(varargin)

    removeAllImageMode      
    
    ptr = 'crosshair';
    setAllImageCursors(ptr)    
    
    funInput = cpAPI.addInputPointPredictBase;
    funBase = cpAPI.addBasePointPredictInput;    
 
    wireInputImages(funInput)
    wireBaseImages(funBase)

  end
    
  %---------------------------------
  function wireInputImages(funInput)
    
    apiInput.setImageButtonDownFcn(funInput)
        
    if ~isempty(funInput)
      ovInputImageButtonDownFcnId = iptaddcallback(hImOvInput,'ButtonDownFcn',funInput);
    else
      ovInputImageButtonDownFcnId = [];
    end

  end

  %-------------------------------
  
  function wireBaseImages(funBase)

    apiBase.setImageButtonDownFcn(funBase)    
        
    if ~isempty(funBase)
      ovBaseImageButtonDownFcnId = iptaddcallback(hImOvBase,'ButtonDownFcn',funBase);
    else
      ovBaseImageButtonDownFcnId = [];
    end
    
  end

  %----------------------------
  function deleteTool(varargin)
  
    if args.Wait
        cpstruct2Export = getCpstruct2Export();
    end
      
    % This call to delete is for performance purposes.  With larger numbers of
    % control points, delete occurs faster if hggroups defining control points
    % and their associated APIs containing callback functions are deleted in
    % advance of normal deletion order.
    delete(findobj(hFig,'Type','hggroup'));
    
    toolIdStream.recycleId(toolNumber);
    iptremovecallback(hFig,'KeyPressFcn',cpAPI.getKeyPressId())
    iptremovecallback(hFig,'WindowKeyPressFcn',cpAPI.getWindowKeyPressId())

  end  
  
  
  %---------------------------
  function createMenubar
  
    filemenu = uimenu(hFig,...
        'Label', getString(message('images:cpselectUIString:fileMenubarLabel')),...
        'Tag','file menu');

    editmenu = uimenu(hFig,...
        'Label', getString(message('images:cpselectUIString:editMenubarLabel')),...
        'Tag','edit menu');    
    
    viewmenu = uimenu(hFig,...
        'Label', getString(message('images:cpselectUIString:viewMenubarLabel')),...
        'Tag','view menu');
    
    toolmenu = uimenu(hFig,...
        'Label',getString(message('images:cpselectUIString:toolsMenubarLabel')),...
        'Tag','tools menu');
    

    matlab.ui.internal.createWinMenu(hFig);


    helpmenu = uimenu(hFig,...
        'Label',getString(message('images:cpselectUIString:helpMenubarLabel')),...
        'Tag','help menu');
    
    % File menu items
    s = [];
    s.Parent = filemenu;

    if ~args.Wait
      % only add Export menu item if 'Wait',false
      s.Label = getString(message('images:cpselectUIString:exportPointsMenubarLabel'));
      s.Accelerator = 'E';
      s.Callback = @exportPoints;
      s.Tag = 'export points menu';
      uimenu(s);
    end

    s.Label = getString(message('images:cpselectUIString:closeMenubarLabel'));
    s.Accelerator = 'W';
    s.Callback = @closeCpselect;
    s.Tag = 'close menu';
    uimenu(s);
    
    % Edit menu items
    s = [];
    s.Parent = editmenu;
    
    s.Label = getString(message('images:cpselectUIString:deleteActivePairMenubarLabel'));
    s.Callback = @deleteActivePair;
    s.Tag = 'delete active pair menu';
    editMenuItems.deleteActivePair = uimenu(s);

    s.Label = getString(message('images:cpselectUIString:deleteActiveInputPointMenubarLabel'));
    s.Callback = @deleteActiveInputPoint;
    s.Tag = 'delete active input point menu';
    editMenuItems.deleteActiveInputPoint = uimenu(s);
    
    s.Label = getString(message('images:cpselectUIString:deleteActiveBasePointMenubarLabel'));
    s.Callback = @deleteActiveBasePoint;
    s.Tag = 'delete active base point menu';
    editMenuItems.deleteActiveBasePoint = uimenu(s);

    % View menu items    
    s = [];
    s.Parent = viewmenu;

    s.Label = getString(message('images:cpselectUIString:overviewImagesMenubarLabel'));
    s.Checked = 'on';
    s.Callback = @toggleShowOverview;
    s.Tag = 'overview images menu';
    overviewMenuItem = uimenu(s);
    
    % Tools menu items
    s = [];
    s.Parent = toolmenu;

    s.Label = getString(message('images:cpselectUIString:addPointsMenubarLabel'));
    s.Tag = 'add points menu';
    addItem = uimenu(s);

    s.Label = getString(message('images:cpselectUIString:addPredictMatchesMenubarLabel'));
    s.Tag = 'add points predict matches menu';
    addPredictItem = uimenu(s);
    
    s.Label = getString(message('images:commonUIString:zoomInMenubarLabel'));
    s.Tag = 'cpselect zoom in menu';
    zoomInItem = uimenu(s);

    s.Label = getString(message('images:commonUIString:zoomOutMenubarLabel'));
    s.Tag = 'cpselect zoom out menu';
    zoomOutItem = uimenu(s);

    s.Label = getString(message('images:commonUIString:panMenubarLabel'));
    s.Tag = 'cpselect pan menu';
    panItem = uimenu(s);

    % Help menu items     
    s.Parent = helpmenu;
    s.Label = getString(message('images:cpselectUIString:cpselectHelpMenubarLabel'));
    s.Callback = @showCPSTHelp;
    s.Tag = 'cpselect help menu';
    uimenu(s);
    images.internal.legacyui.utils.iptstandardhelp(helpmenu);
    
  end
  
  %------------------------------------------
  function okPressed = exportPoints(varargin)

    cpstruct2Export = getCpstruct2Export();
    [movingPoints,fixedPoints] = cpstruct2pairs(cpstruct2Export);

    if isempty(movingPoints)
        warndlg(getString(message('images:cpselectUIString:pairsWarnDlg')));
        return
    end
    
    checkboxlabels = {getString(message('images:cpselectUIString:movingPointsOfValidPairs')),...
                      getString(message('images:cpselectUIString:fixedPointsOfValidPairs')),...
                      getString(message('images:cpselectUIString:structWithAllPoints'))};
    
    defaultvarnames = {'movingPoints',...
                       'fixedPoints',...
                       'cpstruct'};
    
    exportTitle = getString(message('images:cpselectUIString:exportTitle'));
    
    selected = [true true false];
    
    items2export = {movingPoints, fixedPoints, cpstruct2Export};
    
    [~,okPressed] = ...
        export2wsdlg(checkboxlabels,defaultvarnames,items2export,...
                     exportTitle,selected);
    
  end

  %-------------------------------
  function closeCpselect(varargin)

    if ~args.Wait
      unsavedPoints = cpAPI.getNeedToSave();
      
      if unsavedPoints
        saveIfUserRequestsSave()
      else
        delete(hFig)
      end

    else
      % Waiting for user to hit close which they've done.
      uiresume(hFig)
      
    end      
    
  end

  %------------------------------
  function saveIfUserRequestsSave

      button = questdlg(getString(message('images:cpselectUIString:saveQuestDlgText')),...
                        getString(message('images:cpselectUIString:dialogTitle')));
      
      if isempty(button)
          % user hit close button on dialog
          return
      end
      
      if strcmp(button,'Yes')
          okPressed = exportPoints();
          
          if okPressed
              delete(hFig)
          end
          
      elseif strcmp(button,'No')
          delete(hFig)
          
      end

  end
  
  %--------------------------------------
  function closeRequestCpselect(varargin)

    try
      unsavedPoints = cpAPI.getNeedToSave();
    
      if unsavedPoints
        button = questdlg(getString(message('images:cpselectUIString:closeRequestDlgText')),...
                          getString(message('images:cpselectUIString:dialogTitle')),...
                          getString(message('images:commonUIString:ok')),...
                          getString(message('images:commonUIString:cancel')),...
                          getString(message('images:commonUIString:ok')));
        
        if isempty(button)
          % user hit close button on dialog
          return
        end
        
        if strcmp(button,getString(message('images:commonUIString:ok')))
          delete(hFig)
        end
        
      else
        delete(hFig)
        
      end

    catch m_exception
      % For some reason cpAPI not initialized
      delete(hFig)
    end
    
  end

  %----------------------------------------
  function toggleShowOverview(src,varargin)
    
    % If you just clicked on a menu item, it has the 'Checked' 
    % status from prior to your click.
    previouslyChecked = strcmp(get(src,'Checked'),'on');          
    showOverview = ~previouslyChecked;
  
    state = logical2onoff(showOverview);
    set(overviewMenuItem,'Checked',state)
    set(hOverviewPanels,'Visible',state)

    if(webImpl)

        if(strcmp(state,'off'))
            hScrollPanels.Layout.Row = [2 3];
        else
            hScrollPanels.Layout.Row = 2;
        end

    end
  end
  
end % cpselect
   
%-------------------------------------------------------------
function [input, base, cpstruct, args] = ParseInputs(varargin)

  % defaults
  args.Wait = false;
  first_param_idx = [];
  
  % initialize empty cpstruct
  cpstruct = struct('movingPoints',{},...
                    'fixedPoints',{},...
                    'inputBasePairs',{},...
                    'ids',{},...
                    'inputIdPairs',{},...
                    'baseIdPairs',{},...
                    'isInputPredicted',{},...
                    'isBasePredicted',{});

  narginchk(2,6); 

  input = parseImage(varargin{1});
  base = parseImage(varargin{2});
  
  switch nargin
   case 2
    % CPSTRUCT = CPSELECT(MOVING,FIXED)
    return;
    
   case 3
    % CPSTRUCT = CPSELECT(MOVING,FIXED,CPSTRUCT)

    % TO DO: add more validation on cpstruct
    if iscpstruct(varargin{3})
      cpstruct = varargin{3};
    else
      error(message('images:cpselect:CPSTRUCTMustBeStruct'));
    end
    
   case 4
    
    if ischar(varargin{3})
      first_param_idx = 3;
    else
      
      % CPSTRUCT = CPSELECT(MOVING,FIXED,MOVINGPOINTS,FIXEDPOINTS)    
      cpstruct = loadAndValidatePoints(varargin{3:4});
      
    end
    
  otherwise  
    
    if ischar(varargin{5})
      first_param_idx = 5;
      
      % CPSTRUCT = CPSELECT(MOVING,FIXED,MOVINGPOINTS,FIXEDPOINTS,PARAM,VAL,...)    
      cpstruct = loadAndValidatePoints(varargin{3:4});
      
    else
      error(message('images:cpselect:expected5thArgString'))
      
    end
      
  end

  if ~isempty(first_param_idx)
    %parse param name/value pairs
    valid_params = {'Wait'};
    args = parseParamValuePairs(varargin(first_param_idx:end),valid_params,...
                                first_param_idx-1,...
                                mfilename);
  end
  
end

%--------------------------------------------------------------
function cpstruct = loadAndValidatePoints(xyinput_in,xybase_in)
  
  validateattributes(xyinput_in,{'double'},...
                {'real','nonsparse','finite','2d','nonempty'},...
                mfilename,'MOVINGPOINTS',3);
  validateattributes(xybase_in, {'double'},...
                {'real','nonsparse','finite','2d','nonempty'},...
                mfilename,'FIXEDPOINTS',4);
      
      
  if size(xyinput_in,1) ~= size(xybase_in,1) || ...
        size(xyinput_in,2) ~= 2 || size(xybase_in,2) ~= 2  
    error(message('images:cpselect:expectedMby2'));
  end
      
  cpstruct = xy2cpstruct(xyinput_in,xybase_in);

end
    
%------------------------------------------------------------------------
function args = parseParamValuePairs(in,valid_params,num_pre_param_args,...
                                     function_name)

  if rem(length(in),2)~=0
    error(message('images:cpselect:oddNumberArgs'))
  end    

  for k = 1:2:length(in)
    prop_string = validatestring(in{k}, valid_params, function_name,...
                               'PARAM', num_pre_param_args + k);
    
    switch prop_string
     case 'Wait'
      validateattributes(in{k+1}, {'logical'},...
                    {'scalar'}, ...
                    mfilename, 'WAIT', num_pre_param_args+k+1);
      args.(prop_string) = in{k+1};
      
     otherwise
      error(message('images:cpselect:unrecognizedParameter', prop_string, function_name));
      
    end
  end

end

%-------------------------------
function [img] = parseImage(arg)

img = []; %#ok<NASGU>

if ischar(arg)
    try 
        info = imfinfo(arg);
        if strncmp(info.ColorType,'indexed',length(info.ColorType))
            error(message('images:cpselect:imageMustBeGrayscale', arg))
        end
        img = imread(arg);
    catch m_exception
        error(message('images:cpselect:imageNotValid', arg))
    end
else 
    img = arg;
end

end

%----------------------------------------------------
function cpstruct = xy2cpstruct(xyinput_in,xybase_in)

% Create a cpstruct given two lists of equal numbers of points.

M = size(xyinput_in,1);
ids = (0:M-1)';
isPredicted = zeros(M,1);

% assign fields to cpstruct
cpstruct.inputPoints = xyinput_in;
cpstruct.basePoints = xybase_in;
cpstruct.inputBasePairs = bsxfun(@plus, ones(size(ids,1), 2), ids);
cpstruct.ids = ids;
cpstruct.inputIdPairs = cpstruct.inputBasePairs;
cpstruct.baseIdPairs = cpstruct.inputBasePairs;
cpstruct.isInputPredicted = isPredicted;
cpstruct.isBasePredicted = isPredicted;

end

%------------------------------
function showCPSTHelp(varargin)
    helpview("images", "cpselect_gui")
end    

%-------------------------------------------
function buttons = makePointButtons(toolbar)

  % Common properties
  s.toolConstructor            = @uitoggletool;
  s.properties.Parent          = toolbar;
  s.iconConstructor            = @images.internal.app.utilities.makeToolbarIconFromPNG;
  s.iconRoot                   = ipticondir;    
  
  % Add points
  s.icon                       = 'point.png';
  s.properties.TooltipString   = getString(message('images:cpselectUIString:addPointsTooltip'));
  s.properties.Tag             = 'add points';    
  buttons.addPoint             = images.internal.legacyui.utils.makeToolbarItem(s);
  
  % Add points and predict matches
  s.icon                       = 'point_predicted.png';
  s.properties.TooltipString   = getString(message('images:cpselectUIString:addPredictMatchesTooltip'));
  s.properties.Tag             = 'add points and predict matches';  
  buttons.addPredict           = images.internal.legacyui.utils.makeToolbarItem(s);

end

%------------------------------------
function initPos = getInitialPosition
    
    wa = images.internal.getWorkArea();
    
    % Specify fraction of work area to fill
    SCALE = 0.8; 
            
    w = SCALE*wa.width;
    h = SCALE*wa.height;
    x = wa.left + (wa.width - w)/2;
    y = wa.bottom + (wa.height - h)/2; 
    
    initPos = round([x y w h]);
    
end

%   Copyright 2005-2023 The MathWorks, Inc.

%   Input-output specs
%   ------------------ 
%   MOVING,FIXED:   filenames each containing a grayscale or truecolor image
%
%                OR 
%
%                real, full matrix
%                can be intensity or truecolor
%                uint8, uint16, double, or logical
%
%        Note: MOVING can be a filename while FIXED is a variable or vice versa.
%
%   CPSTRUCT:    structure containing control point pairs with fields:
%                   inputPoints
%                   basePoints
%                   inputBasePairs
%                   ids
%                   inputIdPairs
%                   baseIdPairs
%                   isInputPredicted
%                   isBasePredicted
%
%   MOVINGPOINTS, FIXEDPOINTS: M-by-2 matrices with control point coordinates.
%                          real, full, finite
