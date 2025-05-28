classdef Interpolation < handle
    % For internal use only. This class may change in a future release.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    events
        
        % Error Thrown - Event fires when an error occurs during
        % interpolation.
        ErrorThrown
        
        % Auto Interpolation Failed - Event fires when the interpolation
        % object was not able to automatically identify a single region of
        % interest in a neighboring slice.
        AutoInterpolationFailed
        
        % Interpolation Completed - Event fires when interpolation is
        % completed successfully.
        InterpolationCompleted
        
    end
    
    
    properties
        
        Downsample (1,1) logical = true;
        
    end
    
    
    properties (Access = private, Hidden, Transient)
        
        Start (1,1) double
        End (1,1) double
        
        Value (1,1) uint8
        
        StartROI
        EndROI
        
        CenterOfMassDelta (1,2) double
        
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Interpolate
        %------------------------------------------------------------------
        function interpolate(self,pos1,pos2,val,startidx,endidx,dim,sz)
            % INTEPROLATE(SELF,ROI1,ROI2,VAL,IDX1,IDX2,DIM,SZ) performs
            % interpolation between regions of interest specified by ROI1
            % and ROI2 at the slice number IDX1 and IDX2, respectively, in
            % the dimensions specified by DIM. VAL is the numeric value of
            % the labels defined by ROI1 and ROI2. SZ is the size of the
            % volume to be used to create a dense volume with the
            % interpolation results.
            
            try
                self.StartROI = pos1;
                self.EndROI = pos2;
                self.Value = val;
                self.Start = startidx;
                self.End = endidx;
                
                if self.Downsample
                    downsampleLargerROI(self);
                else
                    upsampleSmallerROI(self);
                end
                
                matchOrientation(self);
                
                morphShape(self,sz,dim);
            catch ME
                if strcmp(ME.identifier,'MATLAB:nomem')
                    myMessage = getString(message('images:segmenter:outOfMemory'));
                else
                    myMessage = ME.message;
                end
                throwError(self,myMessage);
            end
            
        end
        
        %------------------------------------------------------------------
        % Auto Interpolate
        %------------------------------------------------------------------
        function autoInterpolate(self,pos,val,slice,startidx,endidx,dim)
            % AUTOINTEPROLATE(SELF,ROI1,VAL,SLICE,IDX1,IDX2,DIM) performs
            % interpolation between regions of interest specified by ROI1
            % and an automatically deteced region in SLICE at the slice
            % number IDX1 and IDX2, respectively, in the dimensions
            % specified by DIM. VAL is the numeric value of the labels
            % defined by ROI1. If the method finds more than one region in
            % SLICE that matches ROI1, it will not interpolate
            % successfully.
            
            try
                self.StartROI = pos;
                self.Value = val;
                self.Start = startidx;
                self.End = endidx;
                
                self.EndROI = findRegionInSlice(self,slice);
                
                if isempty(self.EndROI)
                    notify(self,'AutoInterpolationFailed');
                    return;
                end
                
                downsampleLargerROI(self);
                
                matchOrientation(self);
                
                morphShape(self,size(slice),dim);
                
            catch ME
                if strcmp(ME.identifier,'MATLAB:nomem')
                    myMessage = getString(message('images:segmenter:outOfMemory'));
                else
                    myMessage = ME.message;
                end
                throwError(self,myMessage);
            end
            
        end
        
    end
    
    
    methods (Access = private)
        
        %--Morph Shape-----------------------------------------------------
        function morphShape(self,sz,dim)
            
            mask = preallocateMask(self,sz,dim);
            
            numSlices = abs(self.Start - self.End) - 1;
            
            if self.End > self.Start
                
                delta = self.EndROI - self.StartROI;
                
                for i = 1:numSlices
                    roi = self.StartROI + (delta.*((i)/(numSlices + 1)));
                    
                    switch dim
                        case 1
                            mask(i,:,:) = poly2mask(roi(:,1),roi(:,2),sz(1),sz(2))';
                        case 2
                            mask(:,i,:) = poly2mask(roi(:,1),roi(:,2),sz(1),sz(2));
                        case 3
                            mask(:,:,i) = poly2mask(roi(:,1),roi(:,2),sz(1),sz(2));
                        otherwise
                            return;
                    end
                    
                end
                
            else
                
                delta = self.StartROI - self.EndROI;
                
                for i = 1:numSlices
                    roi = self.EndROI + (delta.*((i)/(numSlices + 1)));
                    
                    switch dim
                        case 1
                            mask(i,:,:) = poly2mask(roi(:,1),roi(:,2),sz(1),sz(2))';
                        case 2
                            mask(:,i,:) = poly2mask(roi(:,1),roi(:,2),sz(1),sz(2));
                        case 3
                            mask(:,:,i) = poly2mask(roi(:,1),roi(:,2),sz(1),sz(2));
                        otherwise
                            return;
                    end
                    
                end
                
            end
            
            startSlice = min(self.Start,self.End) + 1;
            
            evt = images.internal.app.utilities.events.InterpolationCompletedEventData(mask,self.Value,startSlice);
            evt.SliceDimension = dim;
            notify(self,'InterpolationCompleted', evt);
            
        end
        
        %--Match Orientation-----------------------------------------------
        function matchOrientation(self)
            % We now can find a 1-1 mapping of locations in the first ROI
            % to locations in the second ROI. We need to determine how we
            % can shuffle the starting index of one ROI to best fit the
            % next ROI.
            %
            % The number of points has been modified to guarantee that they
            % always match. The point ordering always moves around the
            % object in a clockwise order. The next step is to determine
            % how to reorder the points to best fit both objects:
            %
            %        14 13 12 11               7  6  5  4
            %       15          10           8            3
            %       1           9             9            2
            %        2         8               10          1
            %          3 4     7               11         15
            %              5 6                   12 13 14
            %        First Shape               Second Shape
            %
            % Reorder the points in the first shape (while still moving
            % clockwise) to best match the oprientation of the second
            % shape. This will help prevent the intermediate result from
            % folder over itself.
            %
            % The best orientation is one that minimizes the total amount
            % of displacement between matches points on the objects. for
            % example, a circle with minimal displacement has an
            % orientation like this:
            %
            %         11 10               11 10
            %       1       9           1       9
            %      2         8         2         8
            %       3       7           3       7
            %         4 5 6               4 5 6
            %
            % where a circle with maximum displacement has an orientation
            % like this:
            %
            %         11 10               6 5 4
            %       1       9           7       3
            %      2         8         8         2
            %       3       7           9       1
            %         4 5 6               10 11
            %
            
            self.CenterOfMassDelta = mean(self.EndROI,1) - mean(self.StartROI,1);
            
            n = size(self.StartROI,1);
            
            if n <= 10
                % Special case small shapes. Search all possible candidates
                idxToStartSearch = round(linspace(1,n,n));
            else
                % Search 20 spots along the shape. This can be optimized to
                % perform a global minima search operation to find a more
                % precise location
                idxToStartSearch = round(linspace(1,n,20));
                
            end
            
            totalDispToStartSearch = zeros([numel(idxToStartSearch),1]);
            
            for i = 1:numel(idxToStartSearch)
                totalDispToStartSearch(i) = computeTotalDisplacement(self,idxToStartSearch(i));
            end
            
            [~,minidx] = min(totalDispToStartSearch);
            self.StartROI = shuffleStartROI(self,idxToStartSearch(minidx));
            
        end
        
        %--Compute Total Displacement--------------------------------------
        function totalDisplacement = computeTotalDisplacement(self,idx)
            
            pos = shuffleStartROI(self,idx);
            
            % This code considers the possibility of rigid rotation when
            % identify the best match. It finds the amount of rotation and
            % translation between the points and transforms the points
            % forward. The resulting displacement field do not include an
            % rigid body translation or rotation.
            % tform = fitgeotrans(pos,self.EndROI,'NonreflectiveSimilarity');
            % [X,Y] = transformPointsForward(tform,pos(:,1),pos(:,2));
            % totalDisplacement = sum(sum((self.EndROI - [X,Y]).^2,2),1);
            
            % This code considers only the possibility of rigid body
            % translation. The translation is removed and the resulting
            % displacement field does not consider rigid translation
            totalDisplacement = sum(sum((self.EndROI - pos - self.CenterOfMassDelta).^2,2),1);
            
        end
        
        %--Shuffle ROI-----------------------------------------------------
        function pos = shuffleStartROI(self,idx)
            
            pos = self.StartROI(idx:end,:);
            
            if idx > 1
                pos = [pos; self.StartROI(1:idx - 1,:)];
            end
            
        end
        
        %--Downsample Larger ROI-------------------------------------------
        function downsampleLargerROI(self)
            
            if size(self.StartROI,1) > size(self.EndROI,1)
                
                idx = round(linspace(1,size(self.StartROI,1),size(self.EndROI,1)));
                
                self.StartROI = self.StartROI(idx,:);
                
            elseif size(self.StartROI,1) < size(self.EndROI,1)
                
                idx = round(linspace(1,size(self.EndROI,1),size(self.StartROI,1)));
                
                self.EndROI = self.EndROI(idx,:);
                
            else
                % The number of points matches between the two ROIs, there
                % is nothing more to be done.
                return;
            end
            
        end
        
        %--Upsample Smaller ROI--------------------------------------------
        function upsampleSmallerROI(self)
            
            if size(self.StartROI,1) < size(self.EndROI,1)
                
                idx = round(linspace(1,size(self.StartROI,1),size(self.EndROI,1)));
                
                self.StartROI = self.StartROI(idx,:);
                
            elseif size(self.StartROI,1) > size(self.EndROI,1)
                
                idx = round(linspace(1,size(self.EndROI,1),size(self.StartROI,1)));
                
                self.EndROI = self.EndROI(idx,:);
                
            else
                % The number of points matches between the two ROIs, there
                % is nothing more to be done.
                return;
            end
            
        end
        
        %--Find Region In Slice--------------------------------------------
        function roi = findRegionInSlice(self,slice)
            
            % This assume that only one object exists in the slice. If
            % multiple regions are found, this method returns an empty
            % value. This method ignores any holes.
            
            pos = images.internal.builtins.bwborders(bwlabel(slice == self.Value, 4), 4);
            
            if numel(pos) == 1
                roi = fliplr(pos{1});
            else
                roi = [];
            end
            
        end
        
        %--Preallocate Mask------------------------------------------------
        function mask = preallocateMask(self,sz,dim)
            
            switch dim
                case 1
                    mask = false([abs(self.Start - self.End) - 1, sz(2), sz(1)]);
                case 2
                    mask = false([sz(1), abs(self.Start - self.End) - 1, sz(2)]);
                case 3
                    mask = false([sz, abs(self.Start - self.End) - 1]);
            end
            
        end
        
        %--Throw Error-----------------------------------------------------
        function throwError(self,msg)
            notify(self,'ErrorThrown',images.internal.app.utilities.events.ErrorEventData(msg));
        end
        
    end
    
    
end