function bw2 = bwfloodfill2d(bw1,conn,mode,varargin) %#codegen
% This function performs iterative flood-fill using stack.
%
% BW2 = BWFLOODFILL2D(BW1,CONN,"fillHole") performs flood-fill on 2D binary image BW1,
% starting from the top left corner.
%
% BW2 = BWFLOODFILL2D(BW1,CONN,"seedIndex",LOCATIONS) performs flood-fill on 2D binary
% image BW2, starting from the points specified in LOCATIONS.
% 
% BW2 = BWFLOODFILL2D(BW1,CONN,"seedImage",MARKER) performs flood-fill on 2D binary
% image MARKER starting from white pixels in MARKER, constrained by BW1.
%
% Input/Output notes
% ==================
% BW1          - logical, 2D image
% CONN         - connectivity specifier, must be 4 or 8
% MODE         - compile-time constant string specifying flood-fill mode
%                For "seedIndex" mode, user need to pass in LOCATIONS as
%                additional input. 
%                For "seedImage" mode, user need to pass in MARKER as
%                additional input. 
%                For "fillHole" mode, no additional input is needed
% LOCATIONS    - can be either a P-by-1 double vector containing
%                valid linear indices into the input image, or a 
%                P-by-2 array.  In the second case, each row
%                of LOCATIONS must contain a set of valid array indices
%                into the input image.
% MARKER       - Image of the same size and data type as BW1, specifying 
%                seed locations 
% BW2          - logical, 2D result of flood-fill

% Copyright 2020 The MathWorks, Inc.

    coder.inline('always');
    coder.const(mode);
    
    [R, C] = size(bw1);
    if isequal(mode, "seedImage")
        marker = varargin{1};
        if conn == 4    % theoretically a pixel can appear at most 4 time in the stack
            stack = coder.nullcopy(zeros([2 4*R*C], 'int32'));
        else % conn == 8, theoretically a pixel can appear at most 8 times in the stack
            stack = coder.nullcopy(zeros([2 8*R*C], 'int32'));
        end
        stackTop = coder.internal.indexInt(0);
        for j=1:C
            for i=1:R
                if marker(i,j)
                    stackTop = stackTop + 1;
                    stack(:,stackTop) = [i j];
                    marker(i,j) = 0; % reset marker once recorded seed locations
                end
            end
        end
    else
        if isequal(mode, "seedIndex")
            locations = varargin{1};
            if size(locations,2) == 1 % convert linear indices to row-col indices
                [sr, sc] = ind2sub(size(bw1),locations);
            else
                sr = locations(:,1);
                sc = locations(:,2);
            end
            initialStackSize = numel(sr); % any number of seed location is allowed, so stack need to account for that
        else % isequal(mode, "fillHole")
            bw2 = zeros([R C],'logical');
            sr = int32(1);
            sc = int32(1);
            initialStackSize = 0;
        end
        if conn == 4    % theoretically a pixel can appear at most 1 time in the stack
            stack = coder.nullcopy(zeros([2 R*C+initialStackSize], 'int32'));
        else % conn == 8, theoretically a pixel can appear at most 3 times in the stack
            stack = coder.nullcopy(zeros([2 3*R*C+initialStackSize], 'int32'));
        end
        stackTop = coder.internal.indexInt(0);
        for i=1:numel(sr)
            stackTop = stackTop + 1;
            stack(:,stackTop) = [sr(i) sc(i)];
        end
    end
    
    while stackTop > 0
        i = stack(1,stackTop);
        j = stack(2,stackTop);
        stackTop = stackTop-1;
        
        if bw1(i,j)
            if isequal(mode, "fillHole")
                bw2(i,j) = true;
            elseif isequal(mode, "seedImage")
                marker(i,j) = true;
            end
            bw1(i,j) = false;
            if (i+1 <= R && bw1(i+1,j))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i+1,j];
            end
            if (i-1 >= 1 && bw1(i-1,j))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i-1,j];
            end
            if (j+1 <= C && bw1(i,j+1))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i,j+1];
            end
            if (j-1 >= 1 && bw1(i,j-1))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i,j-1];
            end

            if conn == 8
                if (i-1 >= 1 && j+1 <= C && bw1(i-1,j+1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i-1,j+1];
                end
                if (i+1 <= R && j+1 <= C && bw1(i+1,j+1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i+1,j+1];
                end
                if (i-1 >= 1 && j-1 >= 1 && bw1(i-1,j-1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i-1,j-1];
                end
                if (i+1 <= R && j-1 >= 1 && bw1(i+1,j-1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i+1,j-1];
                end
            end
        end
    end
    if isequal(mode, "seedIndex")
        bw2 = bw1;
    elseif isequal(mode, "seedImage")
        bw2 = marker;
    end
end
