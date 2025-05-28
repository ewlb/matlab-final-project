function displayColorPatch(varargin)
%displayColorPatch Display visual color reproduction as color patches
%
%   displayColorPatch(colorTable) displays measured color values from color
%   patches of esfrChart or colorChecker as color patches surrounded by a
%   thick boundary of the corresponding reference color.
%
%   displayColorPatch(___, Name, Value, ___) displays measured color values
%   from color patches with additional parameters controlling aspects of
%   the display.
%
%   Parameters are:
%
%   'displayROIIndex'   :   Logical controlling whether color patch indices
%                           are overlaid or not. Default is true.
%
%   'displayDeltaE'     :   Logical controlling whether delta E values are 
%                           overlaid or not. Default is true.
%
%   'Parent'            :   Handle of an axes that specifies the parent of
%                           the image object created by displayColorPatch.
%
%   Class Support
%   -------------
%   colorTable is a table computed by the measureColor function of
%   colorChecker or ecfrChart. Any table with the following variables can
%   also be used: 'Measured_R', 'Measured_G', 'Measured_B', 'Reference_L',
%   Reference_a', 'Reference_b' and 'Delta_E'. See the help of
%   colorChecker/measureColor for more information about these variables.
%
%   Notes
%   -----
%   1.  For an esfrChart, numbering convention for color patches match the
%       displayed numbers when using displayChart function.
%   2.  deltaE values in tables returned by measureColor are according to
%       CIE76 specifications and are Euclidean distances between measured
%       and reference colors in CIELab space.
%   3.  The reference RGB values used for patches in the displayColorPatch 
%       output are derived from the respective D65 L*a*b values. 
%
%   Example 1
%   ---------
%   % This example shows the procedure for measuring color
%   % and plotting the results
%
%   I = imread('eSFRTestImage.jpg');
%   I = rgb2lin(I);
%   chart = esfrChart(I);
%   figure
%   displayChart(chart);
%   colorTable = measureColor(chart);
%
%   % Plot results
%   figure
%   displayColorPatch(colorTable)
%
%   Example 2
%   ---------
%   % This example shows the procedure for measuring color
%   % and plotting the results from a colorChecker
%
%   I = imread('colorCheckerTestImage.jpg');
%   chart = colorChecker(I);
%   figure
%   displayChart(chart);
%   colorTable = measureColor(chart);
%
%   % Plot results
%   figure
%   plotChromaticity(colorTable)
%
%   See also esfrChart, colorChecker, esfrChart/measureColor, 
%            colorChecker/measureColor, plotChromaticity

%   Copyright 2017-2020 The MathWorks, Inc.
            
narginchk(1,7);

options = parseInputs(varargin{:});
colorTable = options.colorTable;
displayROIIndex = options.displayROIIndex;
displayDeltaE = options.displayDeltaE;
parentAxis = options.Parent;

numPatches = size(colorTable,1);
numRows = floor(sqrt(numPatches));
numCols = ceil(numPatches/numRows);
 

measuredRGB = im2double([colorTable.Measured_R colorTable.Measured_G colorTable.Measured_B]);
referenceRGB = lab2rgb([colorTable.Reference_L colorTable.Reference_a colorTable.Reference_b],'OutputType','double');
del_E = colorTable.Delta_E;
displayTextLocation = zeros(numPatches,2);

col_sq_sz = 180;
col_sq_width=round(col_sq_sz/6);

full_col_ch = zeros(numRows*col_sq_sz,numCols*col_sq_sz,3);

displayText = cell(numPatches,1);

% Patches are numbered in col major order
ind = 1;
for rowInd = 1:numRows
    for colInd = 1:numCols  
        if ind>numPatches
            % Handle numPatches which dont fill the grid
            break
        end
        col_sq = zeros(col_sq_sz,col_sq_sz,3);
        col_sq(:,:,1) = referenceRGB(ind,1)*255;
        col_sq(:,:,2) = referenceRGB(ind,2)*255;
        col_sq(:,:,3) = referenceRGB(ind,3)*255;
        
        col_sq(col_sq_width:end-col_sq_width,col_sq_width:end-col_sq_width,1) = measuredRGB(ind,1)*255;
        col_sq(col_sq_width:end-col_sq_width,col_sq_width:end-col_sq_width,2) = measuredRGB(ind,2)*255;
        col_sq(col_sq_width:end-col_sq_width,col_sq_width:end-col_sq_width,3) = measuredRGB(ind,3)*255;
        
        full_col_ch(col_sq_sz*(rowInd-1)+1:col_sq_sz*(rowInd-1)+col_sq_sz,col_sq_sz*(colInd-1)+1:col_sq_sz*(colInd-1)+col_sq_sz,:) = col_sq;
        displayTextLocation(ind,1) = round(col_sq_sz*(colInd-1)+1+col_sq_sz/4); % X location
        displayTextLocation(ind,2) = round(col_sq_sz*(rowInd-1)+1+col_sq_sz/2); % Y location
                
        if displayROIIndex && displayDeltaE            
            displayText{ind} = sprintf('Patch %d \n\n$$\\Delta$$E = %3.1f ', ind, del_E(ind));
        elseif displayROIIndex && ~displayDeltaE
            displayText{ind} = sprintf('Patch %d', ind);
        elseif ~displayROIIndex && displayDeltaE
            displayText{ind} = sprintf('$$\\Delta$$E = %3.1f ', del_E(ind));
        end
        ind = ind+1;
    end
end

if isempty(parentAxis)
    hIm = imshow(uint8(full_col_ch));
    h = ancestor(hIm,'figure');
    parentAxis = ancestor(hIm,'axes');
    set(h,'Name','Visual Color Comparison')
else
    imshow(uint8(full_col_ch), 'Parent', parentAxis);
end

% Make text color darker for lighter colors to prevent washout
colorLightness = rgb2lightness(reshape(measuredRGB, [size(measuredRGB,1) 1 3]));
lightColors = colorLightness>60;
darkColors = ~lightColors;
text(displayTextLocation(darkColors,1),displayTextLocation(darkColors,2),...
    displayText(darkColors),...
    'FontSize',15,'FontWeight','bold','Color',[1 1 1],'Interpreter','latex',...
    'Parent',parentAxis);
text(displayTextLocation(lightColors,1),displayTextLocation(lightColors,2),...
    displayText(lightColors),...
    'FontSize',15,'FontWeight','bold','Color',[0 0 0],'Interpreter','latex',...
    'Parent',parentAxis);
end

function options = parseInputs(varargin)

parser = inputParser();
parser.addRequired('colorTable',@validateTable);
parser.addParameter('displayROIIndex',true,@validateDisplayFlag);
parser.addParameter('displayDeltaE',true,@validateDisplayFlag);
parser.addParameter('Parent',[],@validateParentAxis);

parser.parse(varargin{:});
options = parser.Results;
end

function validateTable(colorTable)
    validateattributes(colorTable,{'table'},{'nonempty'},mfilename,'colorTable',1);
end

function validateDisplayFlag(flag)
    supportedClasses = {'logical'};
    attributes = {'nonempty','finite','nonsparse','scalar','nonnan'};
    validateattributes(flag,supportedClasses,attributes,...
        mfilename);
end

function validateParentAxis(Parent)
validateattributes(Parent, {'matlab.graphics.axis.Axes'},{'nonempty','nonsparse'});
end
