function [im, label, badge, userData] = defaultReadFcn(source, optionalReadFcn)
% Default Read Function
%  If source is string/char, use readAllIPTFormats() to read in full image
%  Then convert numeric image to uint8 RGB.

% Copyright 2020-2022 The MathWorks, Inc.

if isnumeric(source)
    im = source;
    label = "";
    badge = images.internal.app.browser.data.Badge.Empty;
    userData.ClassUnderlying = string(class(source));
    userData.OriginalSize = size(source);
    
elseif ischar(source) || (isstring(source) && numel(source)==1)
    try
        if nargin==2
            im = optionalReadFcn(source);
        else
            [im, cmap] = images.internal.app.utilities.readAllFormatsAndBlockedImage(source);
            if ~isempty(cmap)
                im = ind2rgb(im, cmap);
            end
        end
        userData.ClassUnderlying = string(class(im));
        userData.OriginalSize = size(im);
        
    catch ALL %#ok<NASGU>
        % Read failed, use a 'broken' placeholder
        im = imread(fullfile(toolboxdir('images'),'imuitools',...
            '+images','+internal','+app','+browser','+icons',...
            'BrokenPlaceholder_100.png'));
        userData.ClassUnderlying = "";
        userData.OriginalSize = [];
    end
        
    % Label is just the file name (no path, no extensions)
    [~, fileName] = fileparts(source);
    label = string(fileName);

    % No badge by default
    badge = images.internal.app.browser.data.Badge.Empty;
    
else
    assert(false, 'Unsupported source format');
end
end
