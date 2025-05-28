classdef FilterDialog < images.internal.app.utilities.CloseDialog
    %

    % Copyright 2020-2023 The MathWorks, Inc.
    
    properties (GetAccess = {?uitest.factory.Tester})
        Tag = "FilterDialog"
        Checkboxes (1,5) matlab.ui.control.CheckBox
        PropertyDropdowns (1,5) matlab.ui.control.DropDown
        FilterTypeDropdowns (1,5) matlab.ui.control.DropDown
        MinRangeSpinners (1,5) matlab.ui.control.Spinner
        MaxRangeSpinners (1,5) matlab.ui.control.Spinner
        AndLabels (1,5) matlab.ui.control.Label
        MinSpinnerLimits (5,2) double
        MaxSpinnerLimits (5,2) double
    end
    
    properties (SetAccess = private)
        NumRows = 5;
    end
    
    events
       FilterUpdateEvent
       FilterPropertyUpdateEvent
       FilterTypeUpdateEvent
    end
      
    methods
       
        function self = FilterDialog(loc, dlgTitle)
            self = self@images.internal.app.utilities.CloseDialog(loc, dlgTitle);
            self.Size = [650, 260];
            create(self);
            addFilterControls(self);
            setupDialogListeners(self);
            self.FigureHandle.Visible = true;
            self.FigureHandle.WindowStyle = "normal";
        end
            
        function bringToForeground(self)
            figure(self.FigureHandle);
        end
        
        function updateWithNewData(self,filterData,regionMinData,regionMaxData,propIncrements)
            for idx = 1:self.NumRows
                self.Checkboxes(idx).Value = filterData(idx).Enable;
                enableControlsInRow(self,idx,filterData(idx).Enable);
                self.PropertyDropdowns(idx).Value = filterData(idx).Property;
                self.FilterTypeDropdowns(idx).Value = iTranslateFilterTypeToLocale(filterData(idx).FilterType);
                setSpinnerAndLabelVisibilityForFilterType(self,idx,iTranslateFilterTypeToLocale(filterData(idx).FilterType));
                setMinSpinnerLimits(self,self.MinRangeSpinners(idx),[regionMinData.(filterData(idx).Property),regionMaxData.(filterData(idx).Property)],filterData(idx).Enable,idx);
                setMaxSpinnerLimits(self,self.MaxRangeSpinners(idx),[regionMinData.(filterData(idx).Property),regionMaxData.(filterData(idx).Property)],filterData(idx).Enable,idx);
                self.MinRangeSpinners(idx).Step = propIncrements.(filterData(idx).Property);
                self.MaxRangeSpinners(idx).Step = propIncrements.(filterData(idx).Property);
                updateSpinnerValues(self,idx,filterData(idx).Range,iTranslateFilterTypeToLocale(filterData(idx).FilterType));
            end
        end
        
        function updateFilterLimits(self,limits)
            for idx = 1:self.NumRows
                iSetSpinnerLimits(self.MinRangeSpinners(idx),limits(idx,:));
                iSetSpinnerLimits(self.MaxRangeSpinners(idx),limits(idx,:));
            end
        end
                    
        function create(self)
            create@images.internal.app.utilities.CloseDialog(self);            
        end
        
        function addFilterControls(self)
            hpanel = uipanel('Parent',self.FigureHandle','Units','Normalized',...
                'Position',[0 0.15 1 0.85]);
            g = uigridlayout(hpanel,[self.NumRows 6]);
            g.ColumnWidth = {'1x','2x','2x','1x','1x','1x'};
            g.RowHeight = repmat({30},1,self.NumRows);
             
            for idx = 1:self.NumRows
                createFilterRow(self,g,idx);
            end
        end
        
        function setupDialogListeners(self)
            for idx = 1:numel(self.MinRangeSpinners)
                addlistener(self.MinRangeSpinners(idx),'ValueChanged',@(hobj,evt) manageMinValueChange(self,hobj,evt));
                addlistener(self.MaxRangeSpinners(idx),'ValueChanged',@(hobj,evt) manageMaxValueChange(self,hobj,evt));
                addlistener(self.PropertyDropdowns(idx),'ValueChanged',@(hobj,evt) managePropertyChange(self,hobj,evt));
            end
        end
        
        function managePropertyChange(self,hobj,~)
           
            import images.internal.app.regionAnalyzer2.*
            
            idx = find(hobj == self.PropertyDropdowns);
            propName = self.PropertyDropdowns(idx).Value;
                        
            notify(self,'FilterPropertyUpdateEvent',FilterPropertyUpdateEventData(propName,idx));
        end
        
        function manageFilterTypeChange(self,hFilterTypeDropdown)
            
            import images.internal.app.regionAnalyzer2.*

            idx = find(hFilterTypeDropdown == self.FilterTypeDropdowns);
            setSpinnerAndLabelVisibilityForFilterType(self,idx,hFilterTypeDropdown.Value);
            
            propName = self.PropertyDropdowns(idx).Value;
            
            if self.FilterTypeDropdowns(idx).Value == string(getString(message('images:regionAnalyzer:between')))
                lowVal = self.MinRangeSpinners(idx).Value;
                highVal = self.MaxRangeSpinners(idx).Value;
                range = [lowVal,highVal];
            else
                range = iGetRange(self.MinRangeSpinners(idx).Value,self.FilterTypeDropdowns(idx));
            end
            
            notify(self,'FilterTypeUpdateEvent',FilterBoundsUpdateEventData(propName,range,idx,self.Checkboxes(idx).Value,iTranslateFilterTypeToEnglish(self.FilterTypeDropdowns(idx).Value))); 
        end
        
        function manageMinValueChange(self,hobj,~)
            
            import images.internal.app.regionAnalyzer2.*

            manageMinSpinnerBounds(self,hobj);

            idx = find(hobj == self.MinRangeSpinners);
            propName = self.PropertyDropdowns(idx).Value;
            if self.FilterTypeDropdowns(idx).Value == string(getString(message('images:regionAnalyzer:between')))
                lowVal = self.MinRangeSpinners(idx).Value;
                highVal = self.MaxRangeSpinners(idx).Value;
                range = [lowVal,highVal];
            else
                range = iGetRange(self.MinRangeSpinners(idx).Value,self.FilterTypeDropdowns(idx));
            end
            notify(self,'FilterUpdateEvent',FilterBoundsUpdateEventData(propName,range,idx,self.Checkboxes(idx).Value,self.FilterTypeDropdowns(idx).Value));
        end
        
        function manageMaxValueChange(self,hobj,~)
            
            import images.internal.app.regionAnalyzer2.*

            manageMaxSpinnerBounds(self,hobj);

            idx = find(hobj == self.MaxRangeSpinners);
            propName = self.PropertyDropdowns(idx).Value;
            lowVal = self.MinRangeSpinners(idx).Value;
            highVal = self.MaxRangeSpinners(idx).Value;
            range = [lowVal,highVal];
            
            notify(self,'FilterUpdateEvent',FilterBoundsUpdateEventData(propName,range,idx,true,self.FilterTypeDropdowns(idx).Value));
        end

        function manageMinSpinnerBounds(self,hobj)
           
            rowIdx = hobj == self.MinRangeSpinners;
            if self.FilterTypeDropdowns(rowIdx).Value ~= string(getString(message('images:regionAnalyzer:between')))
                return
            end
            
            maxSpinnerValue = self.MaxRangeSpinners(rowIdx).Value;
            self.MinRangeSpinners(rowIdx).Value = min(hobj.Value,maxSpinnerValue);
        end
        
        
        function manageMaxSpinnerBounds(self,hobj)
            rowIdx = hobj == self.MaxRangeSpinners;
            if self.FilterTypeDropdowns(rowIdx).Value ~= string(getString(message('images:regionAnalyzer:between')))
                return
            end
            
            minSpinnerValue = self.MinRangeSpinners(rowIdx).Value;
            self.MaxRangeSpinners(rowIdx).Value = max(hobj.Value,minSpinnerValue);
        end

        function createFilterRow(self,gridLayout,rowIdx)
           self.Checkboxes(rowIdx) =  uicheckbox('Parent',gridLayout,'Text',"",'ValueChangedFcn',@(hobj,evt) checkboxClicked(self,hobj,evt));
           self.PropertyDropdowns(rowIdx) = uidropdown('Parent',gridLayout,'Items',iPropertyNames,'Enable',false);
           self.FilterTypeDropdowns(rowIdx) = uidropdown('Parent',gridLayout,'Items',iFilterOptions,'Enable',false,'ValueChangedFcn',@(hobj,evt) manageFilterTypeChange(self,hobj));
           self.MinRangeSpinners(rowIdx) = uispinner('Parent',gridLayout,'Enable',false,'ValueDisplayFormat','%g');
           self.AndLabels(rowIdx) = uilabel('Parent',gridLayout,'Text',getString(message('images:regionAnalyzer:and')),'Enable',false,'HorizontalAlignment','center');
           self.MaxRangeSpinners(rowIdx) = uispinner('Parent',gridLayout,'Enable',false,'ValueDisplayFormat','%g');
           
           % Set tags:
           rowIdStr = string(num2str(rowIdx));
           self.Checkboxes(rowIdx).Tag = "FilterCheckbox"+rowIdStr;
           self.PropertyDropdowns(rowIdx).Tag = "FilterProperty"+rowIdStr;
           self.FilterTypeDropdowns(rowIdx).Tag = "FilterType"+rowIdStr;
           self.MinRangeSpinners(rowIdx).Tag = "FilterMin"+rowIdStr;
           self.AndLabels(rowIdx).Tag = "FilterAndLabel"+rowIdStr;
           self.MaxRangeSpinners(rowIdx).Tag = "FilterMax"+rowIdStr;
        end
               
        function setSpinnerAndLabelVisibilityForFilterType(self,rowClicked,filterType)
            if filterType == string(getString(message('images:regionAnalyzer:between')))
                self.MaxRangeSpinners(rowClicked).Visible = 'on';
                self.AndLabels(rowClicked).Visible = 'on';
            else
                self.MaxRangeSpinners(rowClicked).Visible = 'off';
                self.AndLabels(rowClicked).Visible = 'off';
            end
        end
        
        function checkboxClicked(self,hobj,evt)
           rowClicked = find(hobj == self.Checkboxes);
           enableControlsInRow(self,rowClicked,evt.Value);
           
           % At this point the filter state changes by becoming active or
           % inactive. Call manageMinValueChange so that the appropriate
           % events are broadcast by the view to reflect its state change.
           manageMinValueChange(self,self.MinRangeSpinners(rowClicked));            
        end
        
        function enableControlsInRow(self,rowIdx,TF)
            self.PropertyDropdowns(rowIdx).Enable = TF;
            self.FilterTypeDropdowns(rowIdx).Enable = TF;
            
            if diff(self.MinSpinnerLimits(rowIdx,:))
                self.MinRangeSpinners(rowIdx).Enable = TF;
            else 
                self.MinRangeSpinners(rowIdx).Enable = false;
            end
            
            if diff(self.MaxSpinnerLimits(rowIdx,:))
                self.MaxRangeSpinners(rowIdx).Enable = TF;
            else
                self.MaxRangeSpinners(rowIdx).Enable = false;
            end
            
            self.AndLabels(rowIdx).Enable = TF;
        end
        
        function updateSpinnerValues(self,rowIdx,range,filterType)
            
            if filterType == string(getString(message('images:regionAnalyzer:between')))
                self.MinRangeSpinners(rowIdx).Value = range(1);
                self.MaxRangeSpinners(rowIdx).Value = range(2);
            elseif contains(filterType,"<")
                self.MinRangeSpinners(rowIdx).Value = range(2);
            elseif contains(filterType,">")
                self.MinRangeSpinners(rowIdx).Value = range(1);
            elseif filterType == "=="
                self.MinRangeSpinners(rowIdx).Value = range(1);
            else
                assert(false,"Unexpected filter type");
            end 
        end
        
        function setMinSpinnerLimits(self,hSpinner,limits,enable,idx)
            self.MinSpinnerLimits(idx,:) = limits;
            iSetSpinnerLimits(hSpinner,limits,enable);
        end
        
        function setMaxSpinnerLimits(self,hSpinner,limits,enable,idx)
            self.MaxSpinnerLimits(idx,:) = limits;
            iSetSpinnerLimits(hSpinner,limits,enable);
        end

    end
    
    methods (Access = protected)
        
        function keyPress(~,~)
            % no-op, stub to override. Don't want default behavior because
            % it steals focus from the spinners.
        end
        
    end
    
end

function out = iPropertyNames
out = ["Area","Circularity","ConvexArea","Eccentricity","EquivDiameter","EulerNumber",...
    "Extent","FilledArea","MajorAxisLength","MinorAxisLength","Orientation",...
    "Perimeter","Solidity"];
end

function out = iFilterOptions
out = [string(getString(message('images:regionAnalyzer:between'))),"==",">",">=","<","<="];
end

function range = iGetRange(spinnerVal,filterType)

if filterType.Value == "=="
    range = [spinnerVal,spinnerVal];
elseif (filterType.Value == ">") || (filterType.Value == ">=")
    range = [spinnerVal,Inf];
elseif (filterType.Value == "<=") || (filterType.Value == "<")
    range = [-Inf spinnerVal];
else
   assert(false,'Unexpected filter type'); 
end
end

function out = iTranslateFilterTypeToLocale(in)
    % The Model always maintains the filter type in english. Move the
    % string to the appropriate translation for updates of the dialog.
    if string(in) == "Between"
        out = getString(message('images:regionAnalyzer:between'));
    else
        out = in;
    end
end

function out = iTranslateFilterTypeToEnglish(in)
    % The View always maintains the filter type in locale. Move the
    % string to the english translation to pass to model.
    if string(in) == getString(message('images:regionAnalyzer:between'))
        out = "Between";
    else
        out = in;
    end
end

function iSetSpinnerLimits(hSpinner,limits,enable)
% Workaround g2445655 in which limits are forced to be
% non-degenerate range, even with inclusive bounds.

if limits(1) == limits(2)
    % If degenerate range, set the limits wide open but disable
    % interaction with the spinner.
    hSpinner.Enable = 'off';
    hSpinner.Limits = [-inf,inf];
else
    hSpinner.Enable = enable;
    hSpinner.Limits = limits;
end
end
