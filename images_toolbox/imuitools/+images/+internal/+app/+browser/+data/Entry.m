classdef Entry < handle & matlab.mixin.SetGet
    %
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (SetAccess = protected)
        Image
    end
    
    properties
        Badge       (1,1) images.internal.app.browser.data.Badge = images.internal.app.browser.data.Badge.Empty;
        Label       (:,1) string
        Color  (1,3) double {mustBeInRange(Color,0,1)} = [0.349 0.667 0.847];
    end
    
    
    properties (SetAccess = private, GetAccess = public)
        UserData (1,1) struct = struct()
    end
    
    properties (SetAccess = immutable, GetAccess = protected)
        Source
    end
    
    
    methods
        
        %------------------------------------------------------------------
        % Entry
        %------------------------------------------------------------------
        function self = Entry(imgSource)
            self.Source = imgSource;
        end

        %------------------------------------------------------------------
        % Read Image Userdata
        %------------------------------------------------------------------
        function userData = readImageUserData(self, readFcn)
            if isequal(self.UserData, struct())
                % Edge case - image was not read in yet for thumbnail
                % creation, but user data is requested.
                try
                    [~, ~, ~, userData] = readFcn(self.Source);
                    assert(isa(userData,'struct') && isscalar(userData),...
                        "UserData should be a scalar struct");
                catch ALL %#ok<NASGU>
                    userData = struct();
                end
            else
                % User data is already available
                userData = self.UserData;
            end
        end

        %------------------------------------------------------------------
        % Read Image
        %------------------------------------------------------------------
        function readImage(self, readFcn, requestedThumbnailSize)
            if ~readRequired(self, requestedThumbnailSize)
                return
            end
            
            try
                [fullImage, label, badge, userData] = readFcn(self.Source);
                createRGBThumbnail(self,fullImage, requestedThumbnailSize);
                
                assert(isa(label,'string'),...
                    "Label should be a scalar string");
                assert(isa(userData,'struct') && isscalar(userData),...
                    "UserData should be a scalar struct");
                assert(isa(badge,'images.internal.app.browser.data.Badge'),...
                    "Badge should be an enum from images.internal.app.browser.data.Badge");
                
            catch ALL %#ok<NASGU>
                if isstring(self.Source) || ischar(self.Source)
                    [~, label] = fileparts(self.Source); % drop extension
                else
                    label = '';
                end  
                badge = images.internal.app.browser.data.Badge.Empty;
                userData = struct();
                self.Image = imread(fullfile(toolboxdir('images'),...
                    'imuitools','+images','+internal','+app','+browser','+icons','BrokenPlaceholder_100.png'));
            end
            
            if isempty(self.Label)
                % Set a label ONLY if one was not set earlier (by an
                % explicit setLabel call)
                self.Label = label;
            end

            if self.Badge == images.internal.app.browser.data.Badge.Empty
                % Set a badge ONLY if one was not set earlier
                self.Badge = badge;
            end
            
            self.UserData = userData;
        end
        
        %------------------------------------------------------------------
        % Read Required - Check if read is required to create a thumbnail
        %------------------------------------------------------------------
        function TF = readRequired(self,requestedThumbnailSize)
            % Check if image was read and thumbnail already created at
            % or greater than the requested size (View entry will resize
            % larger thumnails down if needed)
            TF = isempty(self.Image) || ...
                all(size(self.Image, 1:2)<requestedThumbnailSize);
        end
        
        %------------------------------------------------------------------
        % Rotate Thumbnail
        %------------------------------------------------------------------
        function rotate(self, theta)
            self.Image = imrotate(self.Image, theta);
        end
        
        %------------------------------------------------------------------
        % Clear Thumbnail
        %------------------------------------------------------------------
        function clear(self)
            self.Image = [];
            self.Badge = images.internal.app.browser.data.Badge.Empty;
            self.Label = string.empty();
            self.UserData = struct();
        end
        
    end
    
    
    methods (Access = private)
        
        %--Create Thumbnail------------------------------------------------
        function createRGBThumbnail(self,img, tsize)
            img = images.internal.app.utilities.makeRGB(img);
            resizeRatio = size(img,1:2)./tsize;
            if resizeRatio(1) > resizeRatio(2)
                thumbnail = imresize(img,[tsize(1), NaN], 'bilinear');
            else
                thumbnail = imresize(img,[NaN, tsize(2)], 'bilinear');
            end
            self.Image = thumbnail;
        end
        
    end
end
