classdef FullImageCache < handle
    
    % Copyright 2021 The MathWorks, Inc.
    
    % A simple cache to save images indexed by an imageNumber key.
    % Designed to be small ~<10 images.
    
    
    properties
        % Arbitrary default.
        CacheSize (1,1)  = 5        
    end
    
    properties (Transient, Access = private)
        % Cache of images
        Cache (1,:) cell
        % Key is the image number
        CacheKeys (:,1)
        % Next index to insert
        CacheInsertInd (1,1) = 1
    end
    
    methods
        function reset(obj)
            obj.Cache = {};
            obj.CacheKeys = [];
            obj.CacheInsertInd = 1;
        end
        
        function fullImage = getFullImage(obj, imageNum)
            if isempty(obj.CacheKeys)
                % Cache is empty ==> no hit
                cacheHitInd = 0;
            else
                % Cache is generally small, this find should not be too
                % expensive.
                cacheHitInd = find(obj.CacheKeys == imageNum);
            end
            
            if cacheHitInd
                fullImage = obj.Cache{cacheHitInd};
            else
                fullImage = [];
            end
        end
        
        function insertFullImage(obj, imageNum, fullImage)            
            obj.Cache{obj.CacheInsertInd} = fullImage;
            obj.CacheKeys(obj.CacheInsertInd) = imageNum;
            
            % Update to point to next insert location
            obj.CacheInsertInd = obj.CacheInsertInd+1;
            if obj.CacheInsertInd>obj.CacheSize
                % FIFO eviction
                obj.CacheInsertInd = 1; 
            end
        end
    end
end