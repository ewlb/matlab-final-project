classdef LabelColormapHelper
    %LabelColormapHelper Static helper methods for colormaps applied to labels.

    %   Copyright 2021 The MathWorks, Inc.

    methods (Static)
        function cmap = defaultColormap(numColors)
            persistent cmap_
            if size(cmap_,1)~=numColors
                cmap_ =images.internal.LabelColormapHelper.formPermutedColormap(jet(numColors));
            end
            cmap = cmap_;
        end

        function TF = validateColormap(cmap)
            if isnumeric(cmap)
                validateattributes(cmap,{'single','double'},...
                    {'real','2d','nonsparse','ncols',3,'<=',1,'>=',0},...
                    mfilename,'Colormap');
            end
            TF = true;
        end

        function cmap = normalizeColormap(cmap, totalLabels)
            arguments
                cmap
                totalLabels = 256
            end
            persistent cmap_ totalLabels_
            
            if isequal(cmap_, cmap) && isequal(totalLabels, totalLabels_)
                cmap = cmap_;
            else

                if ~isnumeric(cmap)
                    try
                        cmapTemp = feval(cmap,totalLabels);
                        cmap = images.internal.LabelColormapHelper.formPermutedColormap(cmapTemp);
                    catch
                        error(message('images:common:invalidColormapString'));
                    end
                end
                cmap_ = cmap;
                totalLabels_ = totalLabels;
            end
        end

        function cmapOut = formPermutedColormap(cmap)
            % Create run-to-run reproducible shuffled version of the
            % specified colormap. When viewing labeled regions, you don't
            % want nearby regions to have similar colors. Many of the
            % built-in colormaps take a path through some colorspace, so
            % nearby elements in colormaps tend to have similar colors,
            % which we don't want.
            s = rng;
            c = onCleanup(@() rng(s));
            rng('default');
            totalLabels = size(cmap,1);
            cmapOut = cmap(randperm(totalLabels),:);
        end

    end
end