classdef ExternalBlockCache < handle
    %

    % Copyright 2022 The MathWorks, Inc.

    properties
        % In GB. Arbitrary default.
        MaxCacheSizeinGB (1,1)  = 1
        % When working with a collection of images, specify the maximum
        % dimension possible in that collection
        MaxDimensions (1,1) = 4
    end

    properties (Dependent, SetAccess = private)
        CurrentCacheSizeinGB (1,1)
    end

    properties (Transient, Access = private)
        % Cache of IO Blocks
        Cache (1,:) cell
        % Key is the image number, level and blocksub
        CacheKeys (:,:)
    end

    methods
        function reset(obj)
            obj.Cache = {};
            obj.CacheKeys = [];
        end

        function block = getBlockViaCache(obj, bim, imageIndex, blockSub, level)
            % Extend if required (value assigned does not matter)
            assert(numel(blockSub)<=obj.MaxDimensions)
            blockSubForKey = blockSub;
            blockSubForKey(end+1:obj.MaxDimensions) = 0;
            cacheKey = [imageIndex, level, blockSubForKey];

            if obj.MaxCacheSizeinGB==0 || isempty(obj.CacheKeys)
                % Cache is disabled, or empty ==> no hit
                cacheHitInd = 0;
            else
                % Search cache
                cacheHitInd = find(all(obj.CacheKeys == cacheKey, 2), ...
                    1, 'first');
            end

            if cacheHitInd
                % Read from cache
                block = obj.Cache{cacheHitInd};

            else
                % Fetch from blockedImage
                block = bim.getBlock(blockSub, "Level", level);

                % Insert if cache is enabled
                if obj.MaxCacheSizeinGB>0
                    % Trim cache if required to ensure this block fits
                    blockInfo = whos('block');
                    finalCacheSizeinGB = obj.MaxCacheSizeinGB - blockInfo.bytes/1000/1000/1000;
                    obj.trimCache(finalCacheSizeinGB)

                    % Insert
                    obj.Cache{end+1} = block;
                    obj.CacheKeys(end+1, :) = cacheKey;
                end
            end

        end

        function trimCache(obj, targetSizeinGB)
            while obj.CurrentCacheSizeinGB>targetSizeinGB
                % LIFO!
                obj.Cache(end) = [];
                obj.CacheKeys(end,:) = [];
            end
        end

        function set.MaxCacheSizeinGB(obj, newCacheSizeinGB)
            obj.MaxCacheSizeinGB = newCacheSizeinGB;
            % Trim if needed to fit new size
            obj.trimCache(obj.MaxCacheSizeinGB);
        end

        function sizeinGB = get.CurrentCacheSizeinGB(obj)
            localCacheCopy = obj.Cache; %#ok<NASGU>
            cacheInfo = whos('localCacheCopy');
            sizeinGB = cacheInfo.bytes/1000/1000/1000;
        end

        function set.MaxDimensions(obj, newMaxDim)
            reset(obj);
            obj.MaxDimensions = newMaxDim;
        end

    end
end
