classdef BoundaryFinderObjectHoles < images.internal.coder.BoundaryFinder %#codegen
    
% Modifies the boundary tracing algorithm in such a way that the boundary 
% tracing of the object and hole regions can be done in a single scan of 
% the image.The idea is to construct a combined label image for the object
% and holes regions and use that label image for tracing the objects and 
% holes boundaries in a single scan of the image. 

%   Copyright 2021 The MathWorks, Inc.

    properties (Access = protected)

        % Lookup tables and other variables used by the tracing algorithm
        % for tracing holes boundaries

        ConnectivityHoles           % Holes connectivity
        neighborOffsetsHoles        % array of obj.ConnectivityHoles indices
        validationOffsetsHoles      % array of obj.ConnectivityHoles indices
        nextDirectionLutHoles       % array of int
        nextSearchDirectionLutHoles % array of int
        startMarkerHoles            % int
        boundaryMarkerHoles         % int
    end

    methods
        function obj = BoundaryFinderObjectHoles(labelMatrix,conn)
            % Constructor
            % Base class constructor call
            obj@images.internal.coder.BoundaryFinder(labelMatrix,conn)
            % Avoid topological errors. If objects are 8 connected, then
            % holes must be 4 connected and vice versa.
            if (conn == 4)
                obj.ConnectivityHoles = 8;
            else
                obj.ConnectivityHoles = 4;
            end
        end

        function B = findBoundaries(obj, cutoffL, holesN)
            % Find boundaries in a combined label image which consists of
            % object and holes.

            M = obj.numRows;
            N = obj.numCols;

            % Create output cell array
            numRegions = cutoffL + holesN;
            % If there is no connected component in the image,
            % B will be a 0-by-1 empty cell array.
            % Note that bwboundariesmex returns a 0-by-0 empty cell array.
            B = coder.nullcopy(cell(numRegions,1));
            regionHasBeenTraced = false(numRegions,1);

            if (numRegions > 0)
                % Prepare lookup tables used for tracing boundaries
                obj.initTraceLUTs('double','clockwise')
                obj.setNextSearchDirection([],0,0,'clockwise')
                obj.initTraceLUTsHoles('double','clockwise')

                for c = 2:N-1
                    for r = 2:M-1
                        linearIdx = M*(c-1) + r;
                        label     = coder.internal.indexInt(obj.paddedLabelMatrix(linearIdx));
                        previousLabel = obj.paddedLabelMatrix(linearIdx-1);

                        if (label > 0 && label <= cutoffL) && ...               % if we are in a region
                                (previousLabel ==0 || previousLabel > cutoffL) && ...   % if this is the first pixel of the region
                                ~regionHasBeenTraced(label) % we haven't traced that region before

                            % We have found the start of a new object boundary
                            boundary = obj.traceBoundary(linearIdx, obj.conn, label, 1);
                            B{label} = boundary;
                            regionHasBeenTraced(label) = true;
                        end

                        if label > cutoffL && ...               % if we are in a region
                                (previousLabel > 0 && previousLabel <= cutoffL) && ...   % if this is the first pixel of the region
                                ~regionHasBeenTraced(label) % we haven't traced that region before

                            % We have found the start of a new hole boundary
                            boundary = obj.traceBoundary(linearIdx, obj.ConnectivityHoles, label, 0);
                            B{label} = boundary;
                            regionHasBeenTraced(label) = true;
                        end
                    end
                end
            end
        end
    end

    methods (Access = protected)

        function initTraceLUTsHoles(obj, class, direction)
            % Initialize the lookup tables and other initial values used by
            % the boundary tracing methods. direction is either 'clockwise'
            % or 'counterclockwise'.

            if strcmp(class,'logical')
                obj.startMarkerHoles    = START_UINT8;
                obj.boundaryMarkerHoles = BOUNDARY_UINT8;
            else
                % double
                obj.startMarkerHoles    = START_DOUBLE;
                obj.boundaryMarkerHoles = BOUNDARY_DOUBLE;
            end

            % Store the linear indexing offsets to go from a pixel to one
            % of its neighbors in neighborOffsets.
            % Store the linear indexing offsets used to validate whether a
            % pixel is on the boundary of an object in validationOffsets.
            M = obj.numRows;
            if (obj.ConnectivityHoles == 8)
                % N, NE, E, SE, S, SW, W, NW
                obj.neighborOffsetsHoles = coder.internal.indexInt([-1,M-1,M,M+1,1,-M+1,-M,-M-1]);
                obj.validationOffsetsHoles = coder.internal.indexInt([-1,M,1,-M, 0,0,0,0]);
                % We're adding 0's to make it length 8 in all cases because
                % Coder doesn't support varsize for class members.
            else
                % N, E, S, W
                obj.neighborOffsetsHoles = coder.internal.indexInt([-1,M,1,-M, 0,0,0,0]);
                obj.validationOffsetsHoles = coder.internal.indexInt([-1,M-1,M,M+1,1,-M+1,-M,-M-1]);
            end

            ndl8c  = coder.internal.indexInt([1,2,3,4,5,6,7,0]);
            nsdl8c = coder.internal.indexInt([7,7,1,1,3,3,5,5]);

            ndl4c  = coder.internal.indexInt([1,2,3,0, 0,0,0,0]);
            nsdl4c = coder.internal.indexInt([3,0,1,2, 0,0,0,0]);

            ndl8cc  = coder.internal.indexInt([7,0,1,2,3,4,5,6]);
            nsdl8cc = coder.internal.indexInt([1,3,3,5,5,7,7,1]);

            ndl4cc  = coder.internal.indexInt([3,0,1,2, 0,0,0,0]);
            nsdl4cc = coder.internal.indexInt([1,2,3,0, 0,0,0,0]);

            % nextDirectionLut defines which neighbor we should look at
            % after having looked at a previous neighbor in a given
            % direction.

            % nextSearchDirectionLut defines the direction we should start
            % looking in when examining the neighborhood of pixel k+1 given
            % the direction pixel k to pixel k+1.

            if strcmp(direction,'clockwise')
                if (obj.ConnectivityHoles == 8)
                    obj.nextDirectionLutHoles = ndl8c;
                    obj.nextSearchDirectionLutHoles = nsdl8c;
                else
                    obj.nextDirectionLutHoles = ndl4c;
                    obj.nextSearchDirectionLutHoles = nsdl4c;
                end
            else
                if (obj.ConnectivityHoles == 8)
                    obj.nextDirectionLutHoles = ndl8cc;
                    obj.nextSearchDirectionLutHoles = nsdl8cc;
                else
                    obj.nextDirectionLutHoles = ndl4cc;
                    obj.nextSearchDirectionLutHoles = nsdl4cc;
                end
            end
        end

        function boundary = traceBoundary(obj, idx, conn, label, traceObject)
            % Trace the boundary of a single region from a label matrix and
            % the linear index of the initial border pixel. The output is a
            % Q-by-2 array of Q row-column coordinate pairs for the pixels
            % belonging to the boundary.

            % Initialize loop variables
            coder.varsize('scratch');
            scratch = coder.nullcopy(coder.internal.indexInt(zeros(INITIAL_SCRATCH_LENGTH,1)));
            scratchLength    = INITIAL_SCRATCH_LENGTH;
            scratch(1)       = idx;
            obj.paddedLabelMatrix(idx) = obj.startMarker;
            isDone           = false;
            numPixels        = coder.internal.indexInt(1);
            currentPixel     = idx;
            nextSearchDir    = obj.nextSearchDir; % % same for object and holes
            initDepartureDir = coder.internal.indexInt(-1);

            while ~isDone
                % Find the next boundary pixel
                direction = nextSearchDir;
                foundNextPixel = false;

                for k = 1:conn
                    % Try to locate the next pixel in the chain
                    if (traceObject)
                        neighbor = coder.internal.indexPlus(currentPixel, obj.neighborOffsets(direction+1));
                    else
                        neighbor = coder.internal.indexPlus(currentPixel, obj.neighborOffsetsHoles(direction+1));
                    end

                    if (obj.paddedLabelMatrix(neighbor) == label || obj.paddedLabelMatrix(neighbor) == obj.startMarker)

                        % Found the next boundary pixel
                        if obj.paddedLabelMatrix(currentPixel) == obj.startMarker && ...
                                initDepartureDir == coder.internal.indexInt(-1)
                            % We are making the initial departure from the
                            % starting pixel
                            initDepartureDir = direction;
                        elseif obj.paddedLabelMatrix(currentPixel) == obj.startMarker && ...
                                initDepartureDir == direction
                            % We are about to retrace our path: we're done
                            isDone = true;
                            foundNextPixel = true;
                            obj.paddedLabelMatrix(currentPixel) = label;
                            break
                        end

                        % Take the next step along the boundary
                        if(traceObject)
                            nextSearchDir = obj.nextSearchDirectionLut(direction+1);
                        else
                            nextSearchDir = obj.nextSearchDirectionLutHoles(direction+1);
                        end
                        foundNextPixel = true;

                        if (scratchLength <= numPixels+1)
                            [scratch,scratchLength] = expandScratchSpace(scratch,scratchLength);
                        end

                        % Use numPixels as an index into scratch array
                        scratch(numPixels+1) = neighbor;
                        numPixels = numPixels + 1;

                        if (numPixels == MAX_NUM_PIXELS)
                            isDone = true;
                            break
                        end

                        currentPixel = neighbor;
                        break
                    end
                    if(traceObject)
                        direction = obj.nextDirectionLut(direction+1);
                    else
                        direction = obj.nextDirectionLutHoles(direction+1);
                    end
                end

                if ~foundNextPixel
                    % If there is no next neighbor, the region must have a
                    % single pixel
                    numPixels = coder.internal .indexInt(2);
                    scratch(2) = scratch(1);
                    isDone = true;
                end
            end

            % Copy coordinates to output matrix
            boundary = obj.copyCoordsToBuf(numPixels,scratch);
        end

    end
end

%--------------------------------------------------------------------------
% Constants
function out = INITIAL_SCRATCH_LENGTH
out = coder.internal.indexInt(200);
end

function out = START_DOUBLE
out = -2;
end

function out = BOUNDARY_DOUBLE
out = -3;
end

function out = START_UINT8
out = 2;
end

function out = BOUNDARY_UINT8
out = 3;
end

function out = MAX_NUM_PIXELS
out = intmax('int32'); % arbitrary
end


%--------------------------------------------------------------------------
% Utils
function [scratch,scratchLength] = expandScratchSpace(scratchIn,scratchLengthIn)
% Expand scratch space for holding region boundaries
scratchLength = 2*scratchLengthIn;
scratch = coder.nullcopy(coder.internal.indexInt(zeros(scratchLength,1)));
for k = 1:scratchLengthIn
    scratch(k) = scratchIn(k);
end
end

% LocalWords:  ConnectivityHoles bwboundariesmex varsize nextDirectionLut nextSearchDirectionLut
