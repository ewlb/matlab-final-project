function plotChromaticity(colorTable, options)
%plotChromaticity Plot color reproduction on chromaticity diagram
%
%   plotChromaticity() plots an empty chromaticity diagram.
%
%   plotChromaticity(colorTable) plots the measured and reference colors of
%   an esfrChart or colorChecker captured in a colorTable on a chromaticity
%   diagram.
%
%   plotChromaticity(___, Name, Value) plots the measured and
%   reference colors of an esfrChart or colorChecker with additional
%   parameters controlling aspects of the display.
%
%   Parameters are:
%
%   'BrightnessThreshold'   :   Minimum Y or L value in the xyY or u'v'L
%                               color space used to display the diagram.
%                               Can be a numeric value between 0.0 and 1.0.
%                               Default is 0.15.
%
%   'ColorSpace'            :   Color space to plot in. Can be 'xy' for the
%                               xyY color space or 'uv' for the u'v'L color
%                               space. Default is 'xy'.                               
%
%   'displayROIIndex'       :   Logical controlling whether to overlay color 
%                               patch indices or not. Default is true.
%
%   'Parent'                :   Handle of an axes that specifies the parent 
%                               of the plot created by plotChromaticity.
%
%   'View'                  :   Display 2-D projection or 3-D color solid. 
%                               Can be 2 or 3. Default is 2.
%
%   Class Support
%   -------------
%   colorTable is a table that can be computed by the measureColor function.
%
%   Example 1
%   ---------
%   % Display esfrChart color measurements
%
%   % Read an image of an eSFR chart
%   I = imread('eSFRTestImage.jpg');
%   I = rgb2lin(I);
%   chart = esfrChart(I);
%   figure
%   displayChart(chart)
%
%   % Measure the color of color patch ROIs
%   colorTable = measureColor(chart);
%
%   % Plot the color measurements on a chromaticity diagram
%   figure
%   plotChromaticity(colorTable)
%
%   Example 2
%   ---------
%   % Display colorChecker color measurements
%
%   % Read an image of a Color Checker chart
%   I = imread('colorCheckerTestImage.jpg');
%   chart = colorChecker(I);
%   figure
%   displayChart(chart)
%
%   % Measure the color of ROIs
%   colorTable = measureColor(chart);
%
%   % Plot the color measurements on a chromaticity diagram
%   figure
%   plotChromaticity(colorTable)
%
%   Example 3
%   -------
%   % Plot sRGB primaries and white point
%
%   % Calculate sRGB primaries
%   primaries = rgb2xyz([1 0 0; 0 1 0; 0 0 1]);
%   xy_primaries = primaries(:,1:2)./sum(primaries,2);
%   
%   % Calculate D65 white point
%   wpt = whitepoint('D65');
%   xy_wpt = wpt(:,1:2)./sum(wpt,2);
%
%   x = [xy_primaries(:,1); xy_wpt(:,1)];
%   y = [xy_primaries(:,2); xy_wpt(:,2)];
% 
%   % Plot an empty chromaticity diagram
%   plotChromaticity()
% 
%   % Add the sRGB primaries and white point to the chromaticity diagram
%   hold on
%   scatter(x,y,36,'black');
%   plot(x([1:3 1]),y([1:3 1]),'k');
%   hold off
%
%   See also esfrChart, colorChecker, measureColor, displayColorPatch

%   Copyright 2017-2020 The MathWorks, Inc.

arguments
    colorTable {mustBeColorTable} = cell2table(cell(0,6),...
        'VariableNames', {'Measured_R' 'Measured_G' 'Measured_B'...
        'Reference_L' 'Reference_a' 'Reference_b'});
    options.displayROIIndex (1,1) {mustBeNonempty, mustBeLogical} = true
    options.View (1,1) {mustBeNumeric, mustBeMember(options.View, [2, 3])} = 2
    options.ColorSpace (1,1) string {mustBeColorSpace} = 'xy'
    options.BrightnessThreshold (1,1) {mustBeNumeric,...
        mustBeGreaterThanOrEqual(options.BrightnessThreshold, 0),...
        mustBeLessThanOrEqual(options.BrightnessThreshold, 1)} = 0.15
    options.Parent (1,1) {mustBeAxes} = getDefaultAxes()
end

matlab.images.internal.errorIfgpuArray(colorTable,...
    options.displayROIIndex,...
    options.View,...
    options.ColorSpace,...
    options.BrightnessThreshold,...
    options.Parent);

% Prevent 3D view and warn if plotting a colorTable
if options.View == 3 && ~isempty(colorTable)
    warning(message('images:plotChromaticity:view3DNotSupportedWithColorTable'));
    options.View = 2;
end

% Load CMF and white point
[lambda, xF, yF, zF] = images.color.internal.colorMatchFcn('CIE_1931');
weights = [xF' yF' zF'];
lambda = lambda';
wpt = whitepoint('D65');

% Compute chart data
[xy, shape] = calculateChartXY(lambda, weights, wpt);

XYZ = calculateChartXYZ(lambda, weights, xy, options.BrightnessThreshold);

[x, y, z, rgb] = calculateSurfData(xy, XYZ, wpt, options.View == 3, options.ColorSpace, shape);

% Plot chart
surf(options.Parent,x,y,z,rgb,'FaceColor','interp','EdgeColor', 'none');

% Set axes options and hold
set(options.Parent,'DataAspectRatioMode','Manual');
grid(options.Parent, 'on');

% Set appropriate axis labels
if strcmpi(options.ColorSpace, 'xy')
    xlabel(options.Parent, 'x');
    ylabel(options.Parent, 'y');
    zlabel(options.Parent, 'Y');
    axis(options.Parent, [0.0 0.85 0.0 0.85])
elseif strcmpi(options.ColorSpace, 'uv')
    xlabel(options.Parent, 'u''');
    ylabel(options.Parent, 'v''');
    zlabel(options.Parent, 'L');
    axis(options.Parent, [0.0 0.65 0.0 0.65])
end

% Set 2D or 3D view
view(options.Parent, options.View);

% Plot the colorTable if applicable
if ~isempty(colorTable)
    holdState = ishold(options.Parent);
    hold(options.Parent, 'on');
    
    numColorPatches = size(colorTable,1);
    
    XYZ_ref = lab2xyz([colorTable.Reference_L colorTable.Reference_a colorTable.Reference_b]);
    XYZ_measured = rgb2xyz([colorTable.Measured_R colorTable.Measured_G colorTable.Measured_B]);
    
    if strcmpi(options.ColorSpace, 'xy')
        chromaticity_coords_ref = XYZ2xy(XYZ_ref);
        chromaticity_coords_measured = XYZ2xy(XYZ_measured);
    elseif strcmpi(options.ColorSpace, 'uv')
        c = makecform('xyz2upvpl');
        chromaticity_coords_ref = applycform(XYZ_ref, c);
        chromaticity_coords_measured = applycform(XYZ_measured, c);
    end
    
    scatter_c = zeros(2*numColorPatches,3);
    scatter_c(1:numColorPatches,:) = repmat([1 0 0],numColorPatches,1);
    scatter_c((numColorPatches+1):end,:) = repmat([0 1 0],numColorPatches,1);
    
    scatter(options.Parent, [chromaticity_coords_ref(:,1);chromaticity_coords_measured(:,1)],[chromaticity_coords_ref(:,2);chromaticity_coords_measured(:,2)],50, scatter_c, 'filled');
    hold(options.Parent, 'on');
    pt_txt = cell(numColorPatches,1);
    for j=1:numColorPatches
        pt_txt{j} = num2str(j);
        p1 = [chromaticity_coords_ref(j,1) chromaticity_coords_ref(j,2)];
        p2= [chromaticity_coords_measured(j,1) chromaticity_coords_measured(j,2)];
        dp = p2-p1;
        quiver(options.Parent, p1(1),p1(2),dp(1),dp(2),0,'k','LineWidth',3, 'MaxHeadSize',0.9);
        hold(options.Parent, 'on');
    end
    if options.displayROIIndex
        text(options.Parent,chromaticity_coords_ref(:,1),chromaticity_coords_ref(:,2),pt_txt,'FontSize',12,'FontWeight','bold','Color',[0 0 0]);
    end
    % Restore previous hold state
    if ~holdState
        hold(options.Parent, 'off');
    end
end
end

function [xy, shape] = calculateChartXY(lambda, weights, wpt)
    
    % Create meshgrid of wavelengths and purities
    [wl, purity] = meshgrid(400:5:700, linspace(0,1,50));
    
    % Store meshgrid shape for later
    shape = size(wl);
    
    % Flatten arrays
    wl = wl(:);
    purity = purity(:);
    
    % Convert weights from XYZ to xy
    xy_weights = XYZ2xy(weights);
    
    % Convert white point from XYZ to xy
    xy_wpt = XYZ2xy(wpt);
    
    % Calculate the locus from the meshgrid wavelengths
    xy_locus = interp1(lambda, xy_weights, wl);
    
    % Interpolate between the locus and the white point using purity
    xy = xy_wpt + (xy_locus - xy_wpt) .* purity;
    
    % Close the surface to interpolate purple region of chart
    xy = reshape(xy, [shape 2]);
    xy = [xy xy(:,1,:)];

    shape = size(xy, [1 2]);

    xy = reshape(xy, [], 2);
end

function XYZ = calculateChartXYZ(lambda, weights, xy, brightnessThreshold)
    
    % Generate observations of colors with decreasing spectral purity,
    % combining adjacent wavelengths to move from the outer edges of the
    % chart toward the white point
    n = length(lambda);
    spectra = false((n+1)^2, n);
    ind_spectra = n+1;
    
    for width = 1:n
        for idx = n:-1:0
            row = false(1,n);
            
            ind = idx-width+1:idx;
            ind(ind < 1) = ind(ind < 1) + n;
            row(ind) = true;
            
            spectra(ind_spectra,:) = row;
            
            ind_spectra = ind_spectra + 1;
        end
    end
    
    % Convert spectra observations to XYZ
    xyz_spectra = spectra*weights;
    
    % Convert spectra XYZ to xy
    xy_spectra = XYZ2xy(xyz_spectra);
    
    % Use the spectra xy to create an interpolant returning Y
    % Locate valid rows by removing rows which contain NaNs
    valid_rows = bsxfun(@or, ~isnan(xy_spectra(:,1)), ~isnan(xy_spectra(:,2)));
    
    % Temporarily disable duplicate value warnings
    warnStruct = warning('off', 'MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');
    warnStruct.state = 'on';
    cleanup = onCleanup(@()warning(warnStruct));
    
    F = scatteredInterpolant(xy_spectra(valid_rows,1), xy_spectra(valid_rows,2), xyz_spectra(valid_rows,2), "natural", "nearest");
    
    % Use the interpolant to calculate Y for chart xy
    Y = F(xy(:,1), xy(:,2));
    
    % Normalize Y
    Y = Y ./ max(Y);
    
    % Apply brightness thresholding
    Y(Y<brightnessThreshold) = brightnessThreshold;
    
    % Convert chart xyY to XYZ
    X = Y ./ xy(:,2) .* xy(:,1);
    Z = Y ./ xy(:,2) .* (1 - sum(xy,2));
    
    XYZ = [X Y Z];
end

function [x, y, z, rgb] = calculateSurfData(xy, XYZ, wpt, view3d, colorspace, shape)
    % Calculate chart RGB values
    rgb = xyz2rgb(XYZ, 'WhitePoint', wpt);
    
    % Remove invalid RGB values
    rgb(rgb > 1) = 1;
    rgb(rgb < 0) = 0;
    
    % Reshape rgb to be surf compatible
    rgb = reshape(rgb, [shape 3]);
    
    % Calculate surface x,y,z based on color space
    if strcmpi(colorspace, 'xy')
        chart_xyz = [xy XYZ(:,2)];
    elseif strcmpi(colorspace, 'uv')
        c = makecform('xyz2upvpl');
        chart_xyz = applycform(XYZ, c);
    end
    
    % Reshape surface x,y,z to be surf compatible
    x = reshape(chart_xyz(:,1), shape);
    y = reshape(chart_xyz(:,2), shape);
    
    % If 2D, flatten chart, otherwise use z data
    if ~view3d
        z = zeros(shape);
    else
        z = reshape(chart_xyz(:,3), shape);
    end
end

% Convert XYZ values to xy values
function xy = XYZ2xy(XYZ)
    xy = XYZ(:,1:2) ./ sum(XYZ,2);
end

% Logical validation function
function mustBeLogical(l)
    if ~isa(l, 'logical')
        error(message('images:validate:invalidLogicalParam',...
        'displayROIIndex', 'plotChromaticity', 'displayROIIndex'));
    end
end

% colorTable validation function
function mustBeColorTable(colorTable)
    if ~istable(colorTable)
        error(message('images:validate:unsupportedDataType', 'table'));
    end

    req_vars = {'Measured_R' 'Measured_G' 'Measured_B'...
        'Reference_L' 'Reference_a' 'Reference_b'};
    
    for r = req_vars
       if ~ismember(r, colorTable.Properties.VariableNames)
           error(message('images:plotChromaticity:invalidColorTable', r{:}));
       end
    end
end

% Axes validation function
function mustBeAxes(ax)
    if isempty(axescheck(ax))
        error(message('images:validate:invalidAxes', 'Parent'));
    end
end

% ColorSpace validation function
function mustBeColorSpace(colorSpace)
    mustBeMember(lower(colorSpace), {'xy', 'uv'});
end

% Default axes function
function dftAx = getDefaultAxes()
dftAx = gca;
end