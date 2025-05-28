classdef (Abstract) Adapter < handle & matlab.mixin.Copyable
    % images.blocked.Adapter Adapter interface for blockedImage
    %
    % Adapter specifies the interface for block based reading and writing
    % of array data. Classes that inherit from this interface can be used
    % with blockedImage, enabling block based stream processing of array
    % data.
    %
    % To implement a read-only adapter, the following two methods have to
    % be implemented:
    %   openToRead             - open source for reading
    %   getInfo                - gather information about source
    %   getIOBlock             - get specified IO block
    %
    % To implement an adapter which can write, the following additional
    % methods have to be implemented:
    %   openToWrite            - create and open destination for writing
    %   setIOBlock             - set specified IO block
    %
    % Optionally, to enable an adapter to be used in parallel mode in
    % blockedImage/apply, the following additional method needs to be
    % implemented:
    %   openInParallelToAppend - open destination for parallel appends
    %
    % Optionally, to enable the "Resume" option in blockedImage/apply, the
    % following method needs to be implemented:
    %   alreadyWritten         - list of blocks already written out
    %
    % Optionally, adapters for single-file destinations can define an
    % "Extension" property specifying the file extension as a scalar string
    % (e.g. "jpg") to use when automatically creating a destination
    % location. For adapters which store the data in a folder, this
    % property must not exist or be set to empty.
    %
    % Use the close method in any of the above configurations to perform
    % required clean up tasks (e.g closing file handles).
    %
    % Adapter methods:
    %   openToRead             - open source for reading
    %   getInfo                - gather information about source
    %   openToWrite            - create and open destination for writing
    %   openInParallelToAppend - open destination for parallel appends
    %   alreadyWritten         - list of blocks already written out
    %   getIOBlock             - get specified IO block
    %   setIOBlock             - set specified IO block
    %   close                  - close adapter
    %
    % Note: IO Blocks refers to the smallest unit of data that can be read
    % from or written to the source/destination. blockedImage internals do
    % the appropriate reading, cropping, stitching and caching of the IO
    % blocks to satisfy the blockedImage's BlockSize property.
    %
    % The following in-built adapters are available. All adapters support
    % read and write operations.
    %   images.blocked.InMemory             Store blocks in an in-memory variable
    %   images.blocked.GenericImage         Store blocks in a single image file
    %   images.blocked.H5                   Store blocks in a single HDF5 file
    %   images.blocked.TIFF                 Store blocks in a single TIFF file
    %
    % Only the following can be used with the parallel mode of
    % blockedImage/apply:
    %   images.blocked.BINBlocks            Store each block as a binary
    %                                       blob file in a folder.
    %   images.blocked.GenericImageBlocks   Store each block as an image
    %                                       file in a folder
    %   images.blocked.JPEGBlocks           Store each block as JPEG file
    %                                       in a folder
    %   images.blocked.PNGBlocks            Store each block as a PNG file
    %                                       in a folder
    %   images.blocked.H5Blocks             Store each block as an HDF5
    %                                       file in a folder
    %   images.blocked.MATBlocks            Store each block as a MAT file
    %                                       in a folder
    %
    % See individual adapters for details on supported datatypes and data
    % dimensions.
    %
    % See also: blockedImage, images.blocked.InMemory,
    % images.blocked.BINBlocks, images.blocked.MATBlocks,
    % images.blocked.GenericImageBlocks, images.blocked.JPEGBlocks,
    % images.blocked.PNGBlocks, images.blocked.H5Blocks,
    % images.blocked.GenericImage, images.blocked.TIFF, images.blocked.H5
    
    %   Copyright 2020 The MathWorks, Inc.
    
    % Read API
    methods (Abstract)
        %openToRead - open source for reading
        %
        % openToRead(OBJ, SOURCE) opens the SOURCE, a scalar string, for
        % reading. If SOURCE is not support by the adapter, this method
        % should issue an error.
        %
        % Note: openToRead also gets called when a previously saved
        % blockedImage is loaded from a MAT file.
        %
        % See also: images.blocked.Adapter, blockedImage
        openToRead(obj, source)
        
        %getInfo - gather information about source
        %
        % info = getInfo(OBJ) gathers and returns a structure information
        % about the source. info must contain the following fields:
        %
        %  Note: L is the number of levels in SOURCE. For a single
        %  resolution level image L is 1. N is the number of dimensions in
        %  the image.
        %
        %  Size         A L-by-N integer valued array representing image
        %               size(s)
        %  IOBlockSize  A L-by-N integer valued array representing the
        %               smallest unit of data that can be read from the
        %               source.
        %  Datatype     A 1-by-L string array containing the MATLAB
        %               datatype for each level.
        %  InitialValue A scalar value of type specified by Datatype,
        %               indicating the initial data value for each level. A
        %               cell array if the types and values differ for a
        %               multiresolution array.
        %
        % Additional optional fields:
        %
        %  UserData     A scalar struct containing additional
        %               metadata about the source.
        %  WorldStart   A L-by-N numeric array specifying the starting edge
        %               location of the image in world coordinates.
        %  WorldEnd     A L-by-N numeric array specifying the ending edge
        %               location of the image in world coordinates.
        %
        % See also: images.blocked.Adapter, blockedImage
        info = getInfo(obj)
        
        % getIOBlock - read specified IO block
        %  BLOCK = getIOBlock(obj, IOBLOCKSUB, LEVEL) reads the block
        %  specified by the block subscript IOBLOCKSUB from the specified
        %  resolution level LEVEL. IOBLOCKSUB are block subscripts that
        %  span the grid made by Size./IOBlockSize. BLOCK is empty if there
        %  is no data for the corresponding block, blockedImage will use
        %  the InitialValue property to create a block for such block
        %  subscripts.
        %
        %  Note: For single-resolution level files, LEVEL is always 1.
        %
        % See also: images.blocked.Adapter, blockedImage
        data = getIOBlock(obj, ioBlockSub, level)
    end
    
    % Write API
    methods
        function openToWrite(obj, destination, info, level)%#ok<INUSD>
            %openToWrite - create and open destination for writing
            % openToWrite(OBJ, DESTINATION, INFO, CURRENTLEVEL)
            % opens the location DESTINATION, a scalar string, for writing.
            % INFO is a scalar structure with the following fields:
            %
            %   Note: L is the number of levels in image. For a single
            %   resolution level image L is 1. N is the number of dimensions in
            %   the image.
            %
            %   Size         A L-by-N integer valued array representing array
            %                size(s).
            %   IOBlockSize  A L-by-N integer valued array representing the
            %                block size of data passed to subsequent setBlock
            %                calls.
            %   Datatype     A 1-by-L string array containing the MATLAB
            %                datatype for each level.
            %   InitialValue A scalar value of type specified by Datatype,
            %                indicating the initial data value (same value is
            %                used for all levels).
            %   UserData     A scalar struct containing additional
            %                metadata about the image. This can be empty.
            %   WorldStart   A L-by-N numeric array specifying the starting
            %                edge location of the image in world coordinates.
            %   WorldEnd     A L-by-N numeric array specifying the ending edge
            %                location of the image in world coordinates.
            %
            % CURRENTLEVEL is an integer valued scalar indicating the current
            % level for which data will be written.
            %
            %  Use this to prepare the destination for writing.
            %      - Open file handle or create destination folder.
            %      - Write file header or meta data to destination.
            %
            % Note: When writing an L level multi-resolution (pyramid) images,
            % openToWrite will be called for each level before the
            % corresponding level's setIOBlock calls.
            %
            % See also: images.blocked.Adapter, blockedImage
            error(message('images:blockedImage:openToWriteIsNotImplemented'))
        end
        
        function openInParallelToAppend(obj, destination)%#ok<INUSD>
            %openInParallelToAppend - open destination on a parallel worker to append blocks.
            %
            % openInParallelToAppend(OBJ, DESTINATION) opens the destination on
            % a parallel worker in preparation for appending blocks. This
            % function is only invoked when the "UseParallel" parameter of
            % blockedImage/apply is set to true. openToWrite is guaranteed to
            % have been called once on a corresponding DESTINATION value
            % earlier on a separate instance of the adapter in the main MATLAB
            % session. A copy of the adapter is made for each parallel worker
            % and openInParallelToAppend is called once before subsequent
            % setIOBlock. A blockedImage's AlternateFileSystemRoots property
            % will be used to resolve DESTINATION on the worker.
            %
            % An adapter which implements this method must be able to support
            % multiple adapter instances (one on each parallel worker)
            % appending blocks to the same destination simultaneously. This is
            % usually handled by writing independent files for each block in a
            % single destination folder.
            %
            % See also: images.blocked.Adapter, blockedImage,
            % blockedImage/apply
            error(message('images:blockedImage:openInParallelNotImplemented'))
        end
        
        function setIOBlock(obj, ioBlockSub, level, data) %#ok<INUSD>
            %setIOBlock - write specified block
            % setIOBlock(OBJ, IOBLOCKSUB, LEVEL, BLOCK) writes the data,
            % BLOCK, to the specified block subscript, IOBLOCKSUB, at the
            % specified multi-resolution level, LEVEL.
            %
            % Note: For single-resolution level files, LEVEL is always 1.
            %
            % See also: images.blocked.Adapter, blockedImage
            error(message('images:blockedImage:setIOBlockNotImplemented'))
        end
        
        function ioBlockSubs = alreadyWritten(obj, level)%#ok<STOUT,INUSD>
            %alreadyWritten - list of blocks already written
            % IOBLOCKSUBS = ALREADYWRITTEN(OBJ, LEVEL) returns a list of block
            % subscripts that have data written to them. This list is used to
            % skip processing existing output in blockedImage/apply calls when
            % the parameter "Resume" is set to true.
            %
            % See also: images.blocked.Adapter, blockedImage,
            % blockedImage/apply
            error(message('images:blockedImage:alreadyWrittenNotImplemented'))
        end
        
    end
    
    % Common API
    methods
        function close(obj) %#ok<MANU>
            
            %close - close adapter
            % close(OBJ) closes and releases resources acquired during any one
            % of openToRead, openToWrite, openInParallelToAppend methods. Use
            % this method to flush data, close file handles and perform other
            % clean up actions.
            % Note: close may get called more than once.
            %
            % See also: images.blocked.Adapter, blockedImage
        end
    end
end
