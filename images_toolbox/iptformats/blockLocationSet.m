classdef blockLocationSet < handle

    properties (SetAccess=private)
        ImageNumber

        BlockOrigin

        BlockSize

        Levels
    end

    properties (Dependent, Hidden)        
        TotalNumBlocks
    end

    methods
        function obj = blockLocationSet(imageNumber,blockOrigin,blockSize,levels)
            arguments
                imageNumber(:,1) double {mustBeInteger, mustBePositive, mustBeNonsparse, mustBeNumeric}
                blockOrigin(:,:) double {mustBeReal, mustBeNonsparse, mustBeNumeric}
                blockSize (1,:) double {mustBeReal, mustBePositive, mustBeNonsparse, mustBeNumeric, mustMatch(blockSize, blockOrigin)}
                levels double {mustBeVector, mustBeInteger, mustBeNonempty, mustBePositive, mustBeNumeric, mustBeNonsparse} = 1
            end

            if isempty(imageNumber)
                % Consistent empty size
                imageNumber = [];
            end

            if size(imageNumber,1) ~= size(blockOrigin,1)
                error(message('images:blockLocationSet:invalidBlockOriginImageNumberColSize'));
            end

            obj.ImageNumber = imageNumber;
            obj.BlockOrigin = blockOrigin;
            obj.BlockSize = blockSize;

            if isscalar(levels)
                if isempty(imageNumber)
                    levels = 1; % For backwards compatibility
                else
                    levels = repmat(levels, 1, max(imageNumber));
                end
            else
                if numel(levels)<max(imageNumber)
                    % Every imagenumber should have a corresponding level
                    validateattributes(levels, {'double'},...
                                       {'numel', max(imageNumber)}, mfilename, 'Levels');
                end
            end
            obj.Levels = levels;
        end

        function s = saveobj(obj)
            s.ImageNumber = obj.ImageNumber;
            s.BlockOrigin = obj.BlockOrigin;
            s.BlockSize = obj.BlockSize;
            s.Levels = obj.Levels;
        end

        function nb = get.TotalNumBlocks(obj)
            nb = numel(obj.ImageNumber);
        end

        function [mbls, mbimArray] = mergeBlockLocationSets(obj, bimArray, bls2, bimArray2)
            arguments
                obj (1,1) blockLocationSet
                bimArray (1,:) blockedImage
                bls2 (1,1) blockLocationSet
                bimArray2 (1,:) blockedImage
            end

            if ~isequal(obj.BlockSize, bls2.BlockSize)
                error(message('images:blockLocationSet:blockSizesMustBeSame'))
            end
            
            if isequal(bimArray, bimArray2) && isequal(obj.Levels, bls2.Levels)
                % Both refer to the same array  AND the image numbers map
                % to the same levels in that array, no need to merge the
                % bim arrays. 
                mbimArray = bimArray;
                mbls = blockLocationSet([obj.ImageNumber; bls2.ImageNumber],...
                    [obj.BlockOrigin; bls2.BlockOrigin],...
                    obj.BlockSize, obj.Levels);                

            else                
                mbimArray = [bimArray, bimArray2];
                % Add offset to second set of ImageNumbers to correctly
                % index into mbimArray:
                imageNumbers = [obj.ImageNumber; bls2.ImageNumber+numel(bimArray)];
                mbls = blockLocationSet(imageNumbers,...
                    [obj.BlockOrigin; bls2.BlockOrigin],...
                    obj.BlockSize, [obj.Levels, bls2.Levels]);
            end
        end
    end

    methods (Static)
        function obj = loadobj(s)
            obj = blockLocationSet(s.ImageNumber,s.BlockOrigin,s.BlockSize,s.Levels);
        end
    end
end

function mustMatch(blockSize, blockOrigin)
    if ~isempty(blockOrigin) && numel(blockSize) ~= size(blockOrigin,2)
        error(message('images:blockLocationSet:dimensionsDonotMatch'));
    end
end

%   Copyright 2019-2022 The MathWorks, Inc.
