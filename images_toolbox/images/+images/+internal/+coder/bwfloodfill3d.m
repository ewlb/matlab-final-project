function bw2 = bwfloodfill3d(bw1,conn,mode,varargin) %#codegen
% This function performs iterative flood-fill using stack.
%
% BW2 = BWFLOODFILL3D(BW1,CONN,"fillHole") performs flood-fill on 3D binary image BW1,
% starting from the top left corner of first channel.
%
% BW2 = BWFLOODFILL3D(BW1,CONN,"seedIndex",LOCATIONS) performs flood-fill on 3D binary
% image BW2, starting from the points specified in LOCATIONS.
% 
% BW2 = BWFLOODFILL3D(BW1,CONN,"seedImage",MARKER) performs flood-fill on 3D binary
% image MARKER starting from white pixels in MARKER, constrained by BW1.
%
% Input/Output notes
% ==================
% BW1          - logical, 3D image
% CONN         - connectivity specifier, must be 6, 18 or 26
% MODE         - compile-time constant string specifying flood-fill mode
%                For "seedIndex" mode, user need to pass in LOCATIONS as
%                additional input. 
%                For "seedImage" mode, user need to pass in MARKER as
%                additional input. 
%                For "fillHole" mode, no additional input is needed
% LOCATIONS    - can be either a P-by-1 double vector containing
%                valid linear indices into the input image, or a 
%                P-by-3 array.  In the second case, each row
%                of LOCATIONS must contain a set of valid array indices
%                into the input image.
% MARKER       - Image of the same size and data type as BW1, specifying 
%                seed locations 
% BW2          - logical, 3D result of flood-fill

% Copyright 2020 The MathWorks, Inc.

    coder.inline('always');
    coder.const(mode);
    
    [R, C, P] = size(bw1);
    if isequal(mode, "seedImage")
        marker = varargin{1};
        if conn == 6      % theoretically a pixel can appear at most 6 time in the stack
            stack = coder.nullcopy(zeros([3 6*R*C*P], 'int32'));
        elseif conn == 18 % theoretically a pixel can appear at most 18 times in the stack
            stack = coder.nullcopy(zeros([3 18*R*C*P], 'int32'));
        else  % conn == 26, theoretically a pixel can appear at most 26 times in the stack
            stack = coder.nullcopy(zeros([3 26*R*C*P], 'int32'));
        end
        stackTop = coder.internal.indexInt(0);
        for k=1:P
            for j=1:C
                for i=1:R
                    if marker(i,j,k)
                        stackTop = stackTop + 1;
                        stack(:,stackTop) = [i j k];
                        marker(i,j,k) = 0; % reset marker once recorded seed locations
                    end
                end
            end
        end
    else
        if isequal(mode, "seedIndex")
            locations = varargin{1};
            if size(locations,2) == 1 % convert linear indices to row-col indices
                [sr, sc, sp] = ind2sub(size(bw1),locations);
            else
                sr = locations(:,1);
                sc = locations(:,2);
                sp = locations(:,3);
            end
            initialStackSize = numel(sr);
        else % isequal(mode, "fillHole")
            bw2 = zeros([R C P],'logical');
            sr = int32(1); % seed row index
            sc = int32(1); % seed col index
            sp = int32(1); % seed page index
            initialStackSize = 0;
        end
        if conn == 6      % theoretically a pixel can appear at most 2 time in the stack
            stack = coder.nullcopy(zeros([3 2*R*C*P+initialStackSize], 'int32'));
        elseif conn == 18 % theoretically a pixel can appear at most 8 times in the stack
            stack = coder.nullcopy(zeros([3 8*R*C*P+initialStackSize], 'int32'));
        else  % conn == 26, theoretically a pixel can appear at most 12 times in the stack
            stack = coder.nullcopy(zeros([3 12*R*C*P+initialStackSize], 'int32'));
        end
        stackTop = coder.internal.indexInt(0);
        for i=1:numel(sr)
            stackTop = stackTop + 1;
            stack(:,stackTop) = [sr(i) sc(i) sp(i)];
        end
    end
    
    while stackTop > 0
        i = stack(1,stackTop);
        j = stack(2,stackTop);
        k = stack(3,stackTop);
        stackTop = stackTop-1;
        
        if bw1(i,j,k)
            if isequal(mode, "fillHole")
                bw2(i,j,k) = true;
            elseif isequal(mode, "seedImage")
                marker(i,j,k) = true;
            end
            bw1(i,j,k) = false;
            
            % add 6 faces of current pixel to the stack
            if (i+1 <= R && bw1(i+1,j,k))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i+1,j,k];
            end
            if (i-1 >= 1 && bw1(i-1,j,k))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i-1,j,k];
            end
            if (j+1 <= C && bw1(i,j+1,k))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i,j+1,k];
            end
            if (j-1 >= 1 && bw1(i,j-1,k))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i,j-1,k];
            end
            if (k+1 <= P && bw1(i,j,k+1))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i,j,k+1];
            end
            if (k-1 >= 1 && bw1(i,j,k-1))
                stackTop = stackTop+1;
                stack(:,stackTop) = [i,j,k-1];
            end

            if conn == 18 || conn == 26
                % add 12 edges of current pixel to the stack
                if (i-1 >= 1 && j-1 >= 1 && bw1(i-1,j-1,k))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i-1,j-1,k];
                end
                if (i+1 <= R && j-1 >= 1 && bw1(i+1,j-1,k))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i+1,j-1,k];
                end
                if (i-1 >= 1 && j+1 <= C && bw1(i-1,j+1,k))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i-1,j+1,k];
                end
                if (i+1 <= R && j+1 <= C && bw1(i+1,j+1,k))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i+1,j+1,k];
                end
                if (i-1 >= 1 && k-1 >= 1 && bw1(i-1,j,k-1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i-1,j,k-1];
                end
                if (i+1 <= R && k-1 >= 1 && bw1(i+1,j,k-1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i+1,j,k-1];
                end
                if (j-1 >= 1 && k-1 >= 1 && bw1(i,j-1,k-1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i,j-1,k-1];
                end
                if (j+1 <= C && k-1 >= 1 && bw1(i,j+1,k-1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i,j+1,k-1];
                end
                if (i-1 >= 1 && k+1 <= P && bw1(i-1,j,k+1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i-1,j,k+1];
                end
                if (i+1 <= R && k+1 <= P && bw1(i+1,j,k+1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i+1,j,k+1];
                end
                if (j-1 >= 1 && k+1 <= P && bw1(i,j-1,k+1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i,j-1,k+1];
                end
                if (j+1 <= C && k+1 <= P && bw1(i,j+1,k+1))
                    stackTop = stackTop+1;
                    stack(:,stackTop) = [i,j+1,k+1];
                end
                
                if conn == 26
                    % add 8 corners of current pixel to the stack
                    if (i-1 >= 1 && j-1 >= 1 && k-1 >= 1 && bw1(i-1,j-1,k-1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i-1,j-1,k-1];
                    end
                    if (i+1 <= R && j-1 >= 1 && k-1 >= 1 && bw1(i+1,j-1,k-1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i+1,j-1,k-1];
                    end
                    if (i-1 >= 1 && j+1 <= C && k-1 >= 1 && bw1(i-1,j+1,k-1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i-1,j+1,k-1];
                    end
                    if (i+1 <= R && j+1 <= C && k-1 >= 1 && bw1(i+1,j+1,k-1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i+1,j+1,k-1];
                    end
                    if (i-1 >= 1 && j-1 >= 1 && k+1 <= P && bw1(i-1,j-1,k+1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i-1,j-1,k+1];
                    end
                    if (i+1 <= R && j-1 >= 1 && k+1 <= P && bw1(i+1,j-1,k+1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i+1,j-1,k+1];
                    end
                    if (i-1 >= 1 && j+1 <= C && k+1 <= P && bw1(i-1,j+1,k+1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i-1,j+1,k+1];
                    end
                    if (i+1 <= R && j+1 <= C && k+1 <= P && bw1(i+1,j+1,k+1))
                        stackTop = stackTop+1;
                        stack(:,stackTop) = [i+1,j+1,k+1];
                    end
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
