classdef Model < handle & matlab.mixin.SetGet
    %

    % Copyright 2020-2023 The MathWorks, Inc.
    
    properties (Dependent)
        BW
        TableRowsSelected
        ExcludeBordersEnabled
        FillHolesEnabled
        SelectedPropertyState
        FilterData
    end
      
    properties (Access = private)
        BWInternal
        TableRowsSelectedInternal
        FillHolesEnabledInternal
        ExcludeBordersEnabledInternal
        SelectedPropertyStateInternal
        FilterDataInternal
        RegionDataFullInternal
        RegionDataFullFilledClearedInternal
        HasLotsOfObjects
    end
    
    properties (Dependent, SetAccess = private)
        BWFinal % BW filled, cleared and with filters applied
        BWFilledCleared % BW with holes filled and borders cleared
        RegionData
        RegionDataMin
        RegionDataMax
    end
    
    events
        NewImageDataEvent % New image data loaded into add
        SelectedRegionUpdateEvent
        ImageDataModifiedEvent % Image data modified by clear border/fill holes
        UnableToLoadFileEvent
        ExportImageDataEvent
        ExportRegionDataEvent
        CodeGeneratedEvent
        FilterDataUpdate
        FilteredMaxRegionsEvent
    end
    
    methods
        
        function self = Model(bw)
            initialize(self);
            
            if nargin > 0
                self.BW = manageMaxAllowedRegions(bw);
            end
        end
        
        function initialize(self)
            initializeWithNewData(self);
            self.SelectedPropertyStateInternal = iDefaultSelectedPropertyState();
        end

        function initializeWithNewData(self)
            self.ExcludeBordersEnabledInternal = false;
            self.FillHolesEnabledInternal = false;
            self.FilterDataInternal = iDefaultFilterData();
        end
        
        function data = get.RegionDataMin(self)
            if ~isempty(self.RegionDataFullFilledClearedInternal)
                data = varfun(@(x) floor(min(x)),self.RegionDataFullFilledClearedInternal,'InputVariables',string(fields(iSupportedRegionProps)));
                varNames = string(data.Properties.VariableNames);
                data.Properties.VariableNames = extractAfter(varNames,"Fun_");
            else
                % All false input edge case
                s = structfun(@(f) 0,iSupportedRegionProps,'UniformOutput',false);
                data = struct2table(s);
            end
        end
        
        function data = get.RegionDataMax(self)
            if ~isempty(self.RegionDataFullFilledClearedInternal)
                data = varfun(@(x) ceil(max(x)),self.RegionDataFullFilledClearedInternal,'InputVariables',string(fields(iSupportedRegionProps)));
                varNames = string(data.Properties.VariableNames);
                data.Properties.VariableNames = extractAfter(varNames,"Fun_");
            else
                % All false input edge case
                s = structfun(@(f) 0,iSupportedRegionProps,'UniformOutput',false);
                data = struct2table(s);
            end
        end
       
        function broadcastCurrentImageDataForExport(self)
            import images.internal.app.regionAnalyzer2.*

            notify(self,'ExportImageDataEvent',ExportDataEventData(self.BWFinal,[]));
        end
        
        function broadcastCurrentRegionDataForExport(self)
            import images.internal.app.regionAnalyzer2.*

            varsToExport = setdiff(self.RegionData.Properties.VariableNames,{'PixelIdxList'});
            tableToExport = self.RegionData(:,varsToExport);
            notify(self,'ExportRegionDataEvent',ExportDataEventData([],tableToExport));
        end
        
        function broadcastFilterData(self)            
            import images.internal.app.regionAnalyzer2.*

            notify(self,'FilterDataUpdate',FilterDataUpdateEventData(self.FilterData,self.RegionDataMin,self.RegionDataMax,iPropIncrements));
        end
           
        function dataOut = modifyFilterRangesToFitRegionStats(self,data)
            % The user specified ranges for filters are narrowed if the
            % current data range for a given region prop is smaller than
            % the range of a previously specified filter. This comes into
            % play when a user has previously specified a filter and then a
            % data modifying option like "Fill Holes" or "Clear Boundary"
            % is selected, which might narrow the range of a given
            % property.
            
            % The user range is always maintained in the filter data on the
            % model side but is narrowed by this function before pushing
            % out via notification.
            
            dataOut = data;
            for idx = 1:length(data)
                propName = data(idx).Property;
                minPropVal = self.RegionDataMin.(propName);
                maxPropVal = self.RegionDataMax.(propName);
                if data(idx).Range(1) > minPropVal
                    dataOut(idx).Range(1) = min(data(idx).Range(1),maxPropVal);
                else
                    dataOut(idx).Range(1) = minPropVal; % Use data range otherwise
                end
                
                if data(idx).Range(2) < maxPropVal
                    dataOut(idx).Range(2) = max(data(idx).Range(2),minPropVal);
                else
                    dataOut(idx).Range(2) = self.RegionDataMax.(propName); % Use data range otherwise
                end
            end
        end
        
        function modifyFilterData(self,modifyFilterData)
            
            import images.internal.app.regionAnalyzer2.*

            self.FilterDataInternal(modifyFilterData.Index).Range = modifyFilterData.Range;
            self.FilterDataInternal(modifyFilterData.Index).Enable = modifyFilterData.Enabled;
            self.FilterDataInternal(modifyFilterData.Index).FilterType = modifyFilterData.FilterType;
            self.FilterDataInternal(modifyFilterData.Index).Property = modifyFilterData.PropName;
            
            updateRegionData(self);

            notify(self,'ImageDataModifiedEvent',NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData)); 
        end
        
        function modifyFilterType(self,modifyFilterData)
           
            import images.internal.app.regionAnalyzer2.*
            
            % On the view side, the min spinner is always guaranteed to be
            % in a valid state. The max spinner state is not because it is
            % not used for anything other than Between. The logic of how to
            % interpret the proposed range in this case is left up to the
            % model here.
            newRange = modifyFilterData.Range;
            if diff(newRange) < 0
                newRange = [newRange(1),inf];
            end
            
            self.FilterDataInternal(modifyFilterData.Index).Range = newRange;
            self.FilterDataInternal(modifyFilterData.Index).Enable = modifyFilterData.Enabled;
            self.FilterDataInternal(modifyFilterData.Index).FilterType = modifyFilterData.FilterType;
            self.FilterDataInternal(modifyFilterData.Index).Property = modifyFilterData.PropName;
            
            updateRegionData(self);
            
            broadcastFilterData(self);

            notify(self,'ImageDataModifiedEvent',NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData));
            
        end
        
        function modifyFilterProperty(self,modifyPropertyData)
           
            import images.internal.app.regionAnalyzer2.*

            self.FilterDataInternal(modifyPropertyData.Index).Property = modifyPropertyData.PropName;
            self.FilterDataInternal(modifyPropertyData.Index).Enable = true;
            self.FilterDataInternal(modifyPropertyData.Index).Range = [-Inf,Inf];
            self.FilterDataInternal(modifyPropertyData.Index).FilterType = 'Between';
            
            updateRegionData(self);
            
            broadcastFilterData(self);

            notify(self,'ImageDataModifiedEvent',NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData));

        end
        
        function data = get.FilterData(self)
            data = self.FilterDataInternal;
            
            % Report the narrowed range fit to the data
            data = modifyFilterRangesToFitRegionStats(self,data);
        end
        
        function set.FilterData(self,data)
           self.FilterDataInternal =  data;
        end
           
        function set.FillHolesEnabled(self,data)
            import images.internal.app.regionAnalyzer2.*
            
            self.FillHolesEnabledInternal = data;
            self.TableRowsSelected = [];
            
            updateRegionData(self);
            
            notify(self,'ImageDataModifiedEvent',NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData));
        end
        
        function set.ExcludeBordersEnabled(self,data)
            import images.internal.app.regionAnalyzer2.*
            
            self.ExcludeBordersEnabledInternal = data;
            self.TableRowsSelected = [];
            
            updateRegionData(self);

            notify(self,'ImageDataModifiedEvent',NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData));
        end
        
        function data = get.ExcludeBordersEnabled(self)
            data = self.ExcludeBordersEnabledInternal;
        end
        
        function data = get.FillHolesEnabled(self)
            data = self.FillHolesEnabledInternal;
        end
        
        function set.TableRowsSelected(self,data)
            import images.internal.app.regionAnalyzer2.*
            
            self.TableRowsSelectedInternal = data;
            selectedMask = false(size(self.BWInternal));
            
            % Merge the pixel index lists from each region into a single
            % vector and set all of those linear indices to true.
            if ~isempty(data)
                if iscell(self.RegionData(data,:).PixelIdxList)
                    selectedMask(vertcat(self.RegionData(data,:).PixelIdxList{:})) = true;
                else
                    selectedMask(self.RegionData(data,:).PixelIdxList) = true;
                end
            end
            notify(self,'SelectedRegionUpdateEvent',SelectedRegionUpdateEventData(selectedMask,self.BWFinal));
        end
        
        function data = get.TableRowsSelected(self)
            data = self.TableRowsSelectedInternal;
        end
        
        function data = get.RegionData(self)
            % We don't want PixelIdxList to show up in the table we push
            % out to the view but we do want to maintain it on the model
            % side.
            c = currentlySelectedProperties(self);
            c{end+1} = 'PixelIdxList';
            data = self.RegionDataFullInternal(:,c);
        end
        
        function set.BW(self,data)
            
            import images.internal.app.regionAnalyzer2.*
  
            self.BWInternal = data;
            
            updateRegionData(self);
            
            notify(self,'NewImageDataEvent',...
                NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData));
        end
        
        function set.SelectedPropertyState(self,newState)
            
            import images.internal.app.regionAnalyzer2.*
            
            self.SelectedPropertyStateInternal = newState;
                   
            notify(self,'ImageDataModifiedEvent',NewImageDataEventData(self.BWFinal,...
                self.RegionData,...
                self.SelectedPropertyState,...
                self.ExcludeBordersEnabled,...
                self.FillHolesEnabled,...
                self.FilterData));
        end
        
        function data = get.SelectedPropertyState(self)
            data = self.SelectedPropertyStateInternal;
        end
        
        function data = get.BW(self)
            data = self.BWInternal;
        end
        
        function out = get.BWFilledCleared(self)       
            out = self.BW;
            if self.ExcludeBordersEnabled
                out = imclearborder(out);
            end
            
            if self.FillHolesEnabled
                out = imfill(out,'holes');
            end
        end
        
        function out = get.BWFinal(self)
            out = self.BWFilledCleared;
            for idx = 1:length(self.FilterDataInternal) 
                if self.FilterDataInternal(idx).Enable
                    range = iGetFilterRange(self.FilterDataInternal(idx).Range,self.FilterDataInternal(idx).FilterType);
                    out = bwpropfilt(out,self.FilterDataInternal(idx).Property,range);
                end
            end
        end
        
        function loadBW(self,bw)
            bw = manageMaxAllowedRegions(self,bw);
            
            % Reset app state when new data loaded
            initializeWithNewData(self);
            
            self.BW = bw; 
        end
        
        function loadFromWorkspace(self,varname)
            imgData = evalin('base',varname);
            loadBW(self,imgData);
        end
        
        function loadFromFile(self,filename)
            
            import images.internal.app.regionAnalyzer2.*
            try
                bw = imread(filename);
            catch ME
                notify(self,'UnableToLoadFileEvent',ErrorEventData(ME.message));
                return;
            end
            
            if iValidBWImage(bw)
                loadBW(self,bw);
            else
                invalidBWMessage = getString(message('images:regionAnalyzer:unsupportedImageType'));
                notify(self,'UnableToLoadFileEvent',ErrorEventData(invalidBWMessage));
            end
        end
        
        function generateCode(self)
            
            import images.internal.app.regionAnalyzer2.*
            
            codeGenerator = iptui.internal.CodeGenerator();
            
            % Write function definition
            h1Line = 'Filter BW image using auto-generated code from imageRegionAnalyzer app.';
            addFunctionDeclaration(codeGenerator,'filterRegions',{'BW_in'},{'BW_out','properties'},h1Line);
            codeGenerator.addReturn()
            codeGenerator.addHeader('imageRegionAnalyzer');
            
            if ~self.HasLotsOfObjects
                codeGenerator.addLine('BW_out = BW_in;');
            else
                codeGenerator.addLine('BW_out = bwareafilt(BW_in,1000);');
            end
            
            % Checkboxes
            if self.ExcludeBordersEnabled
                codeGenerator.addComment('Remove portions of the image that touch an outside edge.')
                codeGenerator.addLine('BW_out = imclearborder(BW_out);')
            end
            
            if self.FillHolesEnabled
                codeGenerator.addComment('Fill holes in regions.')
                codeGenerator.addLine('BW_out = imfill(BW_out, ''holes'');')
            end
            
            % Filters
            if any([self.FilterDataInternal.Enable]) 
                codeGenerator.addComment('Filter image based on image properties.');

                enabledFilterData = self.FilterDataInternal([self.FilterDataInternal.Enable]);

                if isscalar(enabledFilterData)
                    fcnCallStr = "BW_out = bwpropfilt(BW_out," + makeFilterArgStr(enabledFilterData) + ");";
                    codeGenerator.addLine(char(fcnCallStr));
                else
                    % CC based optimization is for improving performance
                    % for multiple property filtering.
                    codeGenerator.addLine('CC = bwconncomp(BW_out);');
                    for cnt = 1:numel(enabledFilterData)
                        fcnCallStr = "CC = bwpropfilt(CC," + makeFilterArgStr(enabledFilterData(cnt)) + ");";
                        codeGenerator.addLine(char(fcnCallStr));
                    end
                    codeGenerator.addLine('BW_out = cc2bw(CC);');
                end
            end

            % Helper function that creates the filter argument string
            function filterArgStr = makeFilterArgStr(filter)
                if filter.FilterType == ">"
                    filterLimitStr = sprintf('[%.9g + eps(%.9g), Inf]', filter.Range(1), filter.Range(1));
                elseif filter.FilterType == "<"
                    filterLimitStr = sprintf('[-Inf, %.9g - eps(%.9g)]', filter.Range(2), filter.Range(2));
                else
                    filterLimitStr = sprintf('[%.9g, %.9g]', filter.Range(1), filter.Range(2));
                end

                filterArgStr = "'" + filter.Property + "'," + filterLimitStr;
            end
            
            propsToDisplay = structfun(@(TF) TF,self.SelectedPropertyState);
            if any(propsToDisplay)
                fnames = fieldnames(self.SelectedPropertyState);
                propertyList = fnames(propsToDisplay);
                propertyString = ['{', sprintf('''%s'', ', propertyList{:})];
                propertyString(end-1:end) = '';
                propertyString = [propertyString '}'];
                
                codeGenerator.addComment('Get properties.')
                codeGenerator.addLine(sprintf('properties = regionprops(BW_out, %s);', ...
                    propertyString))
            else
                % There are no properties to export
                codeGenerator.addReturn()
                codeGenerator.addLine('properties = struct([]);');
            end
                
            % Just push the code char array as the thing that leaves the
            % model to maintain the MVC pattern.
            notify(self,'CodeGeneratedEvent',CodeGeneratedEventData(codeGenerator.codeString)); 
        end
        
    end
    
    methods (Access = private)
       
        function bw = manageMaxAllowedRegions(self,bw)
            maxNumberOfRegions = 1000;
            cc = bwconncomp(bw);
            self.HasLotsOfObjects = cc.NumObjects > maxNumberOfRegions;
            if self.HasLotsOfObjects              
                w = warning('off', 'images:bwfilt:tie');
                c = onCleanup(@() warning(w));
                bw = bwpropfilt(bw, 'area', maxNumberOfRegions);
                notify(self,'FilteredMaxRegionsEvent');
            end
        end
        
        function updateRegionData(self)
            allProps = fieldnames(iSupportedRegionProps());
            allProps{end+1} = 'PixelIdxList';
            
            % Maintain full cache of all possible regionprops
            self.RegionDataFullFilledClearedInternal = struct2table(regionprops(self.BWFilledCleared,allProps),'AsArray',true);
            self.RegionDataFullInternal = struct2table(regionprops(self.BWFinal,allProps),'AsArray',true);
        end
        
        function names = currentlySelectedProperties(self)
            c = fieldnames(self.SelectedPropertyState);
            tf = structfun(@(TF) TF,self.SelectedPropertyState);
            names = c(tf);
        end
        
    end
    
end

function s = iDefaultSelectedPropertyState
s = iSupportedRegionProps();
c = iDefaultSubsetOfProps();
for idx = 1:length(c)
    s.(c{idx}) = true;
end
end

function propNames = iDefaultSubsetOfProps

propNames = {...
    'Area'
    'Circularity'
    'Eccentricity'
    'EquivDiameter'
    'EulerNumber'
    'MajorAxisLength'
    'MinorAxisLength'
    'Orientation'
    'Perimeter'};
end

function s = iSupportedRegionProps

s = struct('Area',false,...
    'Circularity', false,...
    'ConvexArea',false,...
    'Eccentricity',false,...
    'EquivDiameter',false,...
    'EulerNumber',false,...
    'Extent',false,...
    'FilledArea',false,...
    'MajorAxisLength',false,...
    'MinorAxisLength',false,...
    'Orientation',false,...
    'Perimeter',false,...
    'Solidity',false);
end

function s = iPropIncrements
s = struct('Area',1,...
    'Circularity',0.1,...
    'ConvexArea',1,...
    'Eccentricity',0.05,...
    'EquivDiameter',1,...
    'EulerNumber',1,...
    'Extent',0.05,...
    'FilledArea',1,...
    'MajorAxisLength',1,...
    'MinorAxisLength',1,...
    'Orientation',1,...
    'Perimeter',1,...
    'Solidity',0.05);
end

function TF = iValidBWImage(im)
supportedDataType = isa(im,'logical');
supportedAttributes = isreal(im) && all(isfinite(im(:))) && ~issparse(im);
supportedDimensionality = ismatrix(im);

TF = supportedDataType && supportedAttributes && supportedDimensionality;
end

function s = iDefaultFilterData()
s = struct('Property','Area','Enable',false,'FilterType','Between','Range',[-Inf Inf]);
s = repmat(s,[5 1]);
end

function range = iGetFilterRange(range,type)
% bwpropfilt uses inclusive range definition. To achieve > or <, nudge the
% input range so that it does not include the boundary.
if type == ">"
    range(1) = range(1) + eps(range(1));
elseif type == "<"
    range(2) = range(2) - eps(range(2));
else
    range = range; %#ok<ASGSL>
end
end



