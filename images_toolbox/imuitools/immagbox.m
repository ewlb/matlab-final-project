function h = immagbox(varargin)
  narginchk(2, 2);
  parent = varargin{1};
  himage = varargin{2};
  
  iptcheckhandle(parent,{'figure','uipanel','uicontainer'},mfilename,'HPARENT',1)
  iptcheckhandle(himage,{'image'},mfilename,'HIMAGE',2)
  
  hScrollpanel = images.internal.legacyui.utils.checkimscrollpanel(himage,mfilename,'HIMAGE');
  apiScrollpanel = iptgetapi(hScrollpanel);

  h = uicontrol('Style','edit',...
                'BackgroundColor','w',...
                'Callback',@updateMag,...
                'Parent',parent);

  % initialize mag
  updateMagString(apiScrollpanel.getMagnification())
  
  % Give scroll panel a hook to update the mag box when mag changes
  apiScrollpanel.addNewMagnificationCallback(@setMagnification);
  
  % Allow other objects to tell the magnification box that the
  % magnification of its associated scroll panel has changed.
  api.setMagnification = @setMagnification;  
  iptsetapi(h,api)
  
  %----------------------------
  function updateMag(src,event)
  
    % The magnification stored in the scroll panel is treated as the "truth."
    origMag = apiScrollpanel.getMagnification();
    
    [newMag, isStringTypedValid] = parseMagString(src,origMag);
  
    if (isStringTypedValid)
       apiScrollpanel.setMagnification(newMag);
    end

    % Always update string, even if just to restore what was there before
    % bogus typing. 
    updateMagString(newMag)
       
  end 
  
  %-------------------------------   
  function updateMagString(newMag)
    
    set(h,'String',sprintf('%s%%',num2str(100*newMag)))
    
  end

  %----------------------
  function setMagnification(newMag)

    validateattributes(newMag,{'numeric'},...
                  {'real','scalar','nonempty','nonnan','finite',...
                   'positive','nonsparse'},'setMagnification','newMag',1)
    
    updateMagString(newMag)
    
  end
  
end

%----------------------------------------------------------------
function [newMag, isStringTypedValid] = parseMagString(src,origMag)

  s = get(src,'String');
  num = sscanf(s,'%f%%');

  if isempty(num) || ~isfinite(num) || num==0
      newMag = origMag;
      isStringTypedValid = false;
  else
      newMag = abs(num/100);
      isStringTypedValid = true;
  end

end

%   Copyright 2003-2023 The MathWorks, Inc.
