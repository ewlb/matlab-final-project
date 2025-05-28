function hout = imtool(varargin)

    if nargin >=1
        [varargin{:}] = convertStringsToChars(varargin{:});
        % Determine the name of the variable storing the source of the
        % image. The variable name can be non-empty if the caller stores
        % the image data or file name as a variable and then calls imtool
        % using it.
        inputVarName = inputname(1);
        if ischar(varargin{1}) || isstring(varargin{1})
            inputFileName = varargin{1};
        else
            inputFileName = '';
        end
        imageName = images.internal.legacyui.utils.getImageName( ...
                                            inputFileName, inputVarName );
    end

    if ( nargin == 2 && strcmpi(varargin{1}, "close") && ...
            strcmpi(varargin{2}, "all") )
        % imtool close all
        % syntax. No output handle must be generated
        images.compatibility.imtool.r2023b.imtool(varargin{:});
    elseif nargout == 0
        % imtool(...)
        % syntax. The output argument is needed to update the tool name if
        % a non-empty app is launched.
        htool = images.compatibility.imtool.r2023b.imtool(varargin{:});
        if nargin > 0
            updateToolName(htool, imageName);
        end
    else
        % Return a handle to the tool only when requested
        % htool = imtool(...)
        % syntax. The output argument is needed to update the tool name if
        % a non-empty app is launched.
        hout = images.compatibility.imtool.r2023b.imtool(varargin{:});
        if nargin > 0 
            updateToolName(hout, imageName);
        end
    end
end

function updateToolName(htool, imageName)
    % Update the Tool name by ensuring the incorporate the variable name

    % Name has the format: "Image Tool <NUM> <SOURCE>
    % We want to extract <NUM>
    currToolNum = extract(htool.Name, digitsPattern);
    currToolNum = str2double(currToolNum(1));

    toolName = getString( message( 'images:imtoolUIString:toolNameWithImageName', ...
                            currToolNum, imageName) );
    htool.Name = toolName;
end

%   Copyright 2004-2023 The MathWorks, Inc.