function plotSFR(varargin)

narginchk(1,9);
matlab.images.internal.errorIfgpuArray(varargin{:});

options = parseInputs(varargin{:});
sharpnessTable = options.sharpnessTable;
ROIIndex = options.ROIIndex;
displayLegend = options.displayLegend;
displayTitle = options.displayTitle;
flagAggregateTable = options.flagAggregateTable;
parentAxis = options.Parent;

inValidROIs = [];
if flagAggregateTable
    % Plot both vertical and horizontal for aggregate tables
    tableRowNumbers = 1:size(sharpnessTable,1);
else
    if isempty(ROIIndex)
        % Plot first row only in case no ROIs are specified
        tableRowNumbers = 1;        
    else
        % Find and plot valid ROIs that exist in the table
        [validROIs,tableRowNumbers, ~] = intersect(sharpnessTable.ROI,ROIIndex);
        inValidROIs = setdiff(ROIIndex, validROIs);
    end
end

if isempty(tableRowNumbers)
    origErrorID = "images:esfrChart:noSlantedEdgeROIs";
    errorMsg = getString(message(origErrorID));
    errorIDToUse = replace(origErrorID, "esfrChart", "plotSFR");
    error(errorIDToUse, errorMsg);
end

if ~isempty(parentAxis)
    if length(parentAxis) ~= length(tableRowNumbers)
        error(message('images:plotSFR:unequalNumberOfAxes'));
    end
end

if ~isempty(inValidROIs)
    warning(message('images:plotSFR:inValidROIIndices'));
end

isOneFigure = isscalar(tableRowNumbers);

% Identify the names of all the channels in the SFR Table
chanNames = string(sharpnessTable.SFR{1}.Properties.VariableNames);
chanNames = chanNames(contains(chanNames, "SFR"));
chanNames = erase(chanNames, "SFR_");

% The Luminance and Intensity channels are drawn using black color. Update
% the color to use suitably
chanColors = lower(replace(chanNames, ["I" "Y"], "K"));
numChansToPlot = numel(chanNames);

% The loop below plots SFR for the selected ROIs.
for index=1:length(tableRowNumbers)
    row = tableRowNumbers(index);
    currSFR = sharpnessTable.SFR{row};

    % This constructs the input arguments to plot independent of the number
    % of channels in the SFR Table. They will contain values like:
    % {Fs, SFR_Chan1, plotColor, Fs, SF_Chan2, plotColor, ...}
    plotArgsLeft = cell(numChansToPlot*3, 1);
    plotArgsRight = cell(numChansToPlot*3, 1);

    F = sharpnessTable.SFR{row}.F;
    n_half = sum(F<=0.5) + 1;

    [plotArgsLeft{1:3:end}] = deal(F(1:n_half));
    tempChanColors = cellstr(chanColors);
    [plotArgsLeft{3:3:end}] = deal(tempChanColors{:});
    
    [plotArgsRight{1:3:end}] = deal(F(n_half:end));
    tempChanColors = cellstr(":" + chanColors);
    [plotArgsRight{3:3:end}] = deal(tempChanColors{:});

    for cnt = 1:numChansToPlot
        chanSFRData = currSFR{:, cnt+1};
        plotArgsLeft{cnt*3-1} = chanSFRData(1:n_half);
        plotArgsRight{cnt*3-1} = chanSFRData(n_half:end);
    end
    
    if isempty(parentAxis)
        
        if isOneFigure
            h = gcf;
        else
            h = figure;
        end
        plot(plotArgsLeft{:}, LineWidth=1.5); hold on;
        plot(plotArgsRight{:}, LineWidth=1.5); hold off;

        currAxes = gca;
        
        if flagAggregateTable
            set(h,'Name',getString(message('images:plotSFR:AverageSFRPlotFigureName',sharpnessTable.Orientation{row})));
            if displayTitle
                title(getString(message('images:plotSFR:AverageSFRPlotTitle',sharpnessTable.Orientation{row})));
            end
        else
            set(h,'Name',getString(message('images:plotSFR:SFRPlotFigureName',sharpnessTable.ROI(row))));
            if displayTitle
                title(getString(message('images:plotSFR:SFRPlotTitle',sharpnessTable.ROI(row))));
            end
        end
    else
        currAxes = parentAxis(index);

        plot(currAxes, plotArgsLeft{:}, LineWidth=1.5); hold(currAxes,'on');
        plot(currAxes, plotArgsRight{:}, LineWidth=1.5); hold(currAxes,'off');
    end

    if displayLegend
        if numChansToPlot == 1
            legend( currAxes, ...
                    getString(message('images:plotSFR:IChannelLegend')), ...
                    getString(message('images:plotSFR:IChannelBeyondNyquistLegend')) );
        else
            legend( currAxes, ...
                    getString(message('images:plotSFR:RChannelLegend')), ...
                    getString(message('images:plotSFR:GChannelLegend')), ...
                    getString(message('images:plotSFR:BChannelLegend')), ...
                    getString(message('images:plotSFR:LChannelLegend')), ...
                    getString(message('images:plotSFR:RChannelBeyondNyquistLegend')), ...
                    getString(message('images:plotSFR:GChannelBeyondNyquistLegend')), ...
                    getString(message('images:plotSFR:BChannelBeyondNyquistLegend')), ...
                    getString(message('images:plotSFR:LChannelBeyondNyquistLegend')) );
        end
    end

    if displayTitle
        if flagAggregateTable
            title(currAxes,getString(message('images:plotSFR:AverageSFRPlotTitle',sharpnessTable.Orientation{row})));
            if isempty(parentAxis)
                set(h,'Name',getString(message('images:plotSFR:AverageSFRPlotFigureName',sharpnessTable.Orientation{row})));
            end
        else
            title(currAxes,getString(message('images:plotSFR:SFRPlotTitle',sharpnessTable.ROI(row))));
            if isempty(parentAxis)
                set(h,'Name',getString(message('images:plotSFR:SFRPlotFigureName',sharpnessTable.ROI(row))));
            end
        end
    end

    axis(currAxes,'tight');
    grid(currAxes,'on');
    
    xlabel(currAxes,getString(message('images:plotSFR:SFRPlotXLabel')));
    ylabel(currAxes,getString(message('images:plotSFR:SFRPlotYLabel')));
    
end
end

function options = parseInputs(varargin)

parser = inputParser();
parser.addRequired('sharpnessTable',@validateTable);
parser.addParameter('ROIIndex',[],@validateROIIndex);
parser.addParameter('displayLegend',true,@validateDisplayFlag);
parser.addParameter('displayTitle',true,@validateDisplayFlag);
parser.addParameter('Parent',[],@validateParentAxis);

parser.parse(varargin{:});
options = parser.Results;

flagAggregateTable = false;
if strcmp(options.sharpnessTable.Properties.VariableNames(1),'Orientation')
    flagAggregateTable = true;
end
options.flagAggregateTable = flagAggregateTable;

end

function validateTable(sharpnessTable)
validateattributes(sharpnessTable,{'table'},{'nonempty'},mfilename,'sharpnessTable',1);
end

function validateDisplayFlag(flag)
supportedClasses = {'logical'};
attributes = {'nonempty','finite','nonsparse','scalar','nonnan'};
validateattributes(flag,supportedClasses,attributes,...
    mfilename);
end

function validateROIIndex(ROIIndex)
supportedClasses = images.internal.iptnumerictypes;
attributes = {'nonempty','nonsparse','real','nonnan','finite','integer', ...
    '<=',60,'positive','nonzero','vector'};
validateattributes(ROIIndex,supportedClasses,attributes,mfilename, ...
    'ROIIndex');
end

function validateParentAxis(Parent)
validateattributes(Parent, {'matlab.graphics.axis.Axes'},{'nonempty','nonsparse','vector'}, mfilename);
end

%   Copyright 2017-2023 The MathWorks, Inc.
