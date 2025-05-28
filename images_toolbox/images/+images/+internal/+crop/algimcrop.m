% This file stores the algorithms used in imcrop, both cpu and gpu version

% Copyright 2020 The MathWorks, Inc.

function varargout = algimcrop(x,y,a,cm,spatial_rect,h_image,placement_cancelled,outputNum)


% return empty if user cancels operation
if placement_cancelled
    varargout = repmat({[]},outputNum,1);
    return;
end

% the hg properties may have changed during the crop operation (e.g.
% imcontrast), so we refresh them here
if ~isempty(h_image) && ishghandle(h_image)
    a = get(h_image,'CData');
    is_indexed_image = strcmpi(get(h_image,'CDataMapping'),'direct');
    cm = colormap(ancestor(h_image,'axes'));
end

makeOutputCategorical = false;
inputCategories =[];

if iscategorical(a)
    inputCategories = categories(a);
    a = images.internal.categorical2numeric(a);
    makeOutputCategorical = true;
end

m = size(a,1);
n = size(a,2);
xmin = min(x(:));
ymin = min(y(:));
xmax = max(x(:));
ymax = max(y(:));

% Transform rectangle into row and column indices.
if (m == 1)
    pixelsPerVerticalUnit = 1;
else
    pixelsPerVerticalUnit = (m - 1) / (ymax - ymin);
end
if (n == 1)
    pixelsPerHorizUnit = 1;
else
    pixelsPerHorizUnit = (n - 1) / (xmax - xmin);
end

[r1, c1, r2, c2] = images.internal.crop.computeImageIndices( ...
                        spatial_rect, xmin, ymin, ...
                        pixelsPerHorizUnit, pixelsPerVerticalUnit );

% Check for selected rectangle completely outside the image
if ((r1 > m) || (r2 < 1) || (c1 > n) || (c2 < 1))
    b = [];
else
    r1 = max(r1, 1);
    r2 = min(r2, m);
    c1 = max(c1, 1);
    c2 = min(c2, n);
    b = a(r1:r2, c1:c2, :);
end

if makeOutputCategorical
    b = categorical(b, 1:numel(inputCategories), inputCategories);
end

switch outputNum
    case 0
        if (isempty(b))
            warning(message('images:imcrop:cropRectDoesNotIntersectImage'))
        end
        
        % imshow behavior with 0 output argument is not supported with
        % categorical inputs. In this case, assign the output to ans.
        if iscategorical(b)
           varargout{1} = b;
           return;
        end

        figure;
        if ~isempty(cm)
            if is_indexed_image
                imshow(b,cm);
            else
                imshow(b,'Colormap',cm);
            end
        else
            imshow(b);
        end

    case 1
        varargout{1} = b;

    case 2
        varargout{1} = b;
        varargout{2} = spatial_rect;

    case 4
        varargout{1} = x;
        varargout{2} = y;
        varargout{3} = b;
        varargout{4} = spatial_rect;

    otherwise
        error(message('images:imcrop:tooManyOutputArguments'))
end

end %algimcrop