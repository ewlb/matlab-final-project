classdef BlockCache < handle
    
    %BLOCKCACHE A class to cache blocks.
    %  Notes: Usually each blockedImage instances has its own cache
    %  instance. A array construction in blockedImage, or an array passed
    %  into blockedImageDatastore will be modified to have a single shared
    %  cache object across the array. This is done to prevent each
    %  blockedImage (of potentially 1000's in the ds) from having its own
    %  cache which could take significant amount of memory.
    
    % Copyright 2020 The MathWorks, Inc.
    
    
    % NOTE: mustBeInteger checks for properties are skipped for performance
    % in this internal class.
    
    properties
        % Arbitrary default. Holds for blockSize upto <2x IOBlockSize.
        CacheSize (1,1)  = 4
        
        CurrentImageNumber (1,1) = 1
    end
        
    properties (Transient, Access = private)    
        % Cache of IO Blocks
        Cache (1,:) cell
        % Key is the image number, level and blocksub for the corresponding block
        CacheKeys (:,:)
        % Next index to insert
        CacheInsertInd (1,1) = 1
    end
    
    methods
        function reset(obj)
            obj.Cache = {};
            obj.CacheKeys = [];
            obj.CacheInsertInd = 1;
        end
        
        function block = getIOBlockViaCache(obj, adapter, level, blockSub)
            cacheKey = [obj.CurrentImageNumber, level, blockSub];
            
            if obj.CacheSize==0 || isempty(obj.CacheKeys)
                % Cache is disabled, or empty ==> no hit
                cacheHitInd = 0;
            else
                % Cache is generally small, this find should not be too
                % expensive.                
                cacheHitInd = find(all(obj.CacheKeys == cacheKey, 2), ...
                    1, 'first');
            end
            
            if cacheHitInd
                block = obj.Cache{cacheHitInd};
            else
                block = adapter.getIOBlock(blockSub, level);
                % Insert if cache is enabled
                if obj.CacheSize>0
                    obj.Cache{obj.CacheInsertInd} = block;
                    obj.CacheKeys(obj.CacheInsertInd, :) = cacheKey;
                    
                    % Update to point to next insert location
                    obj.CacheInsertInd = obj.CacheInsertInd+1;
                    if obj.CacheInsertInd>obj.CacheSize
                        obj.CacheInsertInd = 1; % FIFO eviction
                    end
                end
            end
        end
    end
end