%associatedImageDatastore Datastore for associating two image datastores.
%   ds = associatedImageDatastore(imdsFirst, imdsSecond) creates a datastore
%   for training deep learning networks based on data from two associated
%   datastores, dsFirst and dsSecond, which contain image data.
%
%   associatedImageDatastore Properties:
%
%      MiniBatchSize        - Number of images returned in each read.
%      NumObservations      - Total number of images in an epoch.
%
%   associatedImageDatastore Methods:
%
%      hasdata              - Returns true if there is more data in the datastore
%      partitionByIndex     - Partitions datastore given indices
%      preview              - Reads the first image from the datastore
%      read                 - Reads data from the datastore
%      readall              - Reads all observations from the datastore
%      readByIndex          - Random access read from datastore given indices
%      reset                - Resets datastore to the start of the data
%      shuffle              - Shuffles the observations in the datastore

% Copyright 2018-2019 The MathWorks, Inc.

classdef associatedImageDatastore < matlab.io.Datastore &...
        matlab.io.datastore.MiniBatchable &...
        matlab.io.datastore.PartitionableByIndex &...
        matlab.io.datastore.Partitionable &...
        matlab.io.datastore.Shuffleable &...
        matlab.io.datastore.BackgroundDispatchable
    
    
    properties (Access = private)
        dsFirst
        dsSecond
    end
    
    properties (Dependent)
        MiniBatchSize
    end
    
    properties (Dependent, SetAccess = 'protected')
        NumObservations
    end
    
    properties (SetAccess = 'private')
        DataAugmentation
        ColorPreprocessing
        OutputSize
        OutputSizeMode
    end
    
    methods
        
        function ds = associatedImageDatastore(dsFirst,dsSecond,varargin)
            iParseDatastoreInputs(dsFirst,dsSecond);
            ds.DispatchInBackground = false;
            ds.dsFirst = copy(dsFirst);
            ds.dsSecond = copy(dsSecond);
            ds.MiniBatchSize = 1;
        end
        
        function [data,info] = read(ds)
            [first,firstInfo] = read(ds.dsFirst);
            if ~iscell(first)
                first = {first};
            end
            [second,secondInfo] = read(ds.dsSecond);
            if ~iscell(second)
                second = {second};
            end
                        
            data = table(first,second);
            info.ImageFilenameFirst = firstInfo;
            info.ImageFilenameSecond = secondInfo;
        end
        
        function [data,info] = readByIndex(ds,idx)
            dsPartition = partitionByIndex(ds,idx);
            data = readall(dsPartition);
            info.ReadIndices = idx;
            info.ImageFilenameFirst = dsPartition.dsFirst.Files;
            info.ImageFilenameSecond = dsPartition.dsSecond.Files;
        end
        
        function dsnew = shuffle(ds)
            ord = randperm(maxpartitions(ds));
            dsnew = partitionByIndex(ord);
        end
        
        function dsnew = partitionByIndex(ds,idx)
            dsnew = copy(ds);
            dsnew.dsFirst = iPartitionByIndex(dsnew.dsFirst,idx);
            dsnew.dsSecond = iPartitionByIndex(dsnew.dsSecond,idx);
        end
        
        function reset(ds)
            reset(ds.dsFirst);
            reset(ds.dsSecond);
        end
        
        function TF = hasdata(ds)
            TF = hasdata(ds.dsFirst);
        end
        
        function dsnew = partition(ds,n,idx)
            dsnew = copy(ds);
            dsnew.dsFirst = partition(ds.dsFirst,n,idx);
            dsnew.dsSecond = partition(ds.dsSecond,n,idx);
        end
        
    end
    
    methods (Access = 'protected')
        
        function n = maxpartitions(ds)
            n = ds.dsFirst.numpartitions;
        end
        
    end
    
    methods % Accessors for properties
        
        function set.MiniBatchSize(ds,sz)
            [ds.dsFirst.ReadSize,ds.dsSecond.ReadSize] = deal(sz);
        end
        
        function sz = get.MiniBatchSize(ds)
            sz = ds.dsFirst.ReadSize;
        end
        
        function numObs = get.NumObservations(ds)
            numObs = numpartitions(ds);
        end
        
    end
    
    methods (Hidden)
        
        function frac = progress(ds)
            frac = progress(ds.dsFirst);
        end
        
        function S = saveobj(self)
            S = struct('imdsFirst',self.dsFirst,...
                       'imdsSecond',self.dsSecond,...
                       'MiniBatchSize',self.MiniBatchSize);
        end
        
    end
    
    methods(Static, Hidden = true)
        function self = loadobj(S)
            self = images.internal.datastore.associatedImageDatastore(S.imdsFirst,S.imdsSecond);
            self.MiniBatchSize = S.MiniBatchSize;
        end
    end
      
end

function dsnew = iPartitionByIndex(ds,idx)
% This function can be removed once imageDatastore and
% pixelLabelDatastore implement partitionByIndex

if isa(ds,'matlab.io.datastore.ImageDatastore') || ...
        isa(ds,'matlab.io.datastore.PixelLabelDatastore')
    dsnew = subset(ds,idx);
else
    assert(message('images:associatedImageDatastore:unexpectedInputType'));
end

end

function iParseDatastoreInputs(dsFirst,dsSecond)

numPartitionsFirst = dsFirst.numpartitions;
numPartitionsSecond = dsSecond.numpartitions;

if ~isequal(numPartitionsFirst,numPartitionsSecond)
    error(message('images:associatedImageDatastore:unequalNumPartitions'));
end

end