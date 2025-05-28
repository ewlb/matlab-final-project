function [L, numComponents] = bwlabel(varargin)%#codegen
%BWLABEL Label connected components in 2-D binary image.

%   Copyright 2014-2023 The MathWorks, Inc.

narginchk(1,2);

BW = varargin{1};
validateattributes(BW, {'logical' 'numeric'}, {'real', '2d', 'nonsparse'}, ...
    mfilename, 'BW', 1);

if (nargin < 2)
    mode = 8;
else
    mode = varargin{2};
    validateattributes(mode, {'double'}, {'real', 'scalar'}, mfilename, 'N', 2);

    coder.internal.errorIf(~eml_is_const(mode), ...
        'MATLAB:images:validate:codegenInputNotConst','N');
    coder.internal.errorIf(~((mode == 4) || (mode == 8)), ...
        'images:bwlabel:badConn');
end

% Initialize counter to keep track of number of connected components.
numComponents = 0;
[M,N] = size(BW);

if coder.gpu.internal.isGpuEnabled
    [L, numComponents] = bwlabel_gpu_impl(BW, mode); % MATLAB GPU implementation of KE CCL Algo.
    return;
end

% nThread ideally should be the number of cores that the target has,
% Due to limitation (g2220341), we currently don't have access to
% information on target cores, so we assume 4 cores, which most
% embedded devices would have.
nThread = 4;
if isempty(BW)
    L = zeros([M,N]);
    return;
end
[L, numComponents] = labelingWu_parallel(BW, mode, M, N, nThread);
end

function [L, k] = labelingWu_parallel(im, mode, M, N, nThread)
    % Placeholder for output label, no initialization needed as every pixel will be re-written.
    L = coder.nullcopy(zeros([M,N]));
    % chunksSizeAndLabels will store the ending column number of each parallel stripe
    % and the number of temporary labels detected in each paralle stripe
    chunksSizeAndLabels = coder.nullcopy(zeros([N+2*nThread,1], 'int32'));
    nParallelStripes = max(1,min(floor(N/4), nThread*2)); % number of parallel stripes
    stripeWidth = ceil(N/nParallelStripes); % width of each parallel stripe, the last stripe could have less width
    Plength = ceil(M*N/2)+1; % theoretical limit of number of labels, happens for chessboard pattern for 4-connectivity
    P = coder.nullcopy(zeros(Plength,1)); % P stores the label equivalence info as a tree
    P(1)=0; % first label correspond to the background: always 0

    if mode == 8
        % First scan Use Rosenfeld Mask (rotated 90 degree for column wise traversal)
        % +-+-+
        % |p|s|
        % +-+-+
        % |q|x|
        % +-+-+
        % |r|
        % +-+-+
        coder.internal.treatAsParfor();
        coder.internal.parallelRelax();
        for thread = 0:nParallelStripes-1
            c = thread*stripeWidth+1; % index of starting column
            chunksSizeAndLabels(c) = min((thread+1)*stripeWidth+1,N+1); % store index of ending column in chunksSizeAndLabels
            label = floor(c/2) * floor((M+1)/2) + 1; % calculate first label of current parallel stripe, the formula makes sure there is no overlaping label usage between parallel stripes
            firstLabel = label;
            startC = c;
            for c = thread*stripeWidth+1 : min((thread+1)*stripeWidth,N)
                for r = 1:M
                    if im(r,c)
                        if c>startC && im(r,c-1) % q=1, then x<-q
                            L(r,c) = L(r,c-1);
                        else % q=0
                            if r<M && c>startC && im(r+1,c-1) % r=1
                                if c>startC && r>1 && im(r-1,c-1) % r=1, p=1, then x<-merge(p,r)
                                    % Manually inline set_union due to reduction variable's limitation in parfor:
                                    % [P,L(r,c)] = set_union(P, L(r-1,c-1), L(r+1,c-1));
                                    L(r,c) = L(r-1,c-1);
                                    while P(L(r,c)+1)<L(r,c)
                                        L(r,c) = P(L(r,c)+1);
                                    end
                                    if L(r-1,c-1)~=L(r+1,c-1)
                                        rootj = L(r+1,c-1);
                                        while P(rootj+1)<rootj
                                            rootj = P(rootj+1);
                                        end
                                        if L(r,c)>rootj
                                            L(r,c) = rootj;
                                        end
                                        while P(L(r+1,c-1)+1)<L(r+1,c-1)
                                            j = P(L(r+1,c-1)+1);
                                            P(L(r+1,c-1)+1) = L(r,c);
                                            L(r+1,c-1) = j;
                                        end
                                        P(L(r+1,c-1)+1) = L(r,c);
                                    end
                                    while P(L(r-1,c-1)+1)<L(r-1,c-1)
                                        j = P(L(r-1,c-1)+1);
                                        P(L(r-1,c-1)+1) = L(r,c);
                                        L(r-1,c-1) = j;
                                    end
                                    P(L(r-1,c-1)+1) = L(r,c);
                                else % p = q = 0
                                    if r>1 && im(r-1,c) % r=1, s=1, p=q=0, then x<-merge(s,r)
                                        % Manually inline set_union due to reduction variable's limitation in parfor:
                                        % [P,L(r,c)] = set_union(P, L(r-1,c),  L(r+1,c-1));
                                        L(r,c) = L(r-1,c);
                                        while P(L(r,c)+1)<L(r,c)
                                            L(r,c) = P(L(r,c)+1);
                                        end
                                        if L(r-1,c)~=L(r+1,c-1)
                                            rootj = L(r+1,c-1);
                                            while P(rootj+1)<rootj
                                                rootj = P(rootj+1);
                                            end
                                            if L(r,c)>rootj
                                                L(r,c) = rootj;
                                            end
                                            while P(L(r+1,c-1)+1)<L(r+1,c-1)
                                                j = P(L(r+1,c-1)+1);
                                                P(L(r+1,c-1)+1) = L(r,c);
                                                L(r+1,c-1) = j;
                                            end
                                            P(L(r+1,c-1)+1) = L(r,c);
                                        end
                                        while P(L(r-1,c)+1)<L(r-1,c)
                                            j = P(L(r-1,c)+1);
                                            P(L(r-1,c)+1) = L(r,c);
                                            L(r-1,c) = j;
                                        end
                                        P(L(r-1,c)+1) = L(r,c);

                                    else % p = q = s = 0
                                        L(r,c) = L(r+1,c-1); % x<-r
                                    end
                                end
                            else % r = q = 0
                                if c>startC && r>1 && im(r-1,c-1) % r=q=0, p=1, then x<-p
                                    L(r,c) = L(r-1,c-1);
                                else % r = q = p = 0
                                    if r>1 && im(r-1,c)% r=q=p=0, s=1, then x<-s
                                        L(r,c) = L(r-1,c);
                                    else % r=p=q=s=0, then create new label for x
                                        L(r,c) = label;
                                        P(label+1) = label;
                                        label = label + 1;
                                    end
                                end
                            end
                        end
                    else % x=0, x is a background pixel
                        L(r,c) = 0;
                    end
                end
            end
            chunksSizeAndLabels(startC+1)=label-firstLabel;
        end

        % Merge label 8 connectivity, merge mask:
        % +-+
        % |p|
        % +-+-+
        % |q|x|
        % +-+-+
        % |r|
        % +-+
        c = chunksSizeAndLabels(1); % only need to merge on paralle stripe coundaries, boundary index stored in chunksSizeAndLabels
        while c<=N
            for r = 1:M
                if L(r,c)
                    if r>1 && L(r-1, c-1) %p=1, merge x and p
                        [P,L(r,c)] = set_union(P, L(r-1,c-1), L(r,c));
                    end
                    if r<M && L(r+1, c-1) %r=1, merge x and r
                        [P,L(r,c)] = set_union(P, L(r+1,c-1), L(r,c));
                    end
                    if L(r,c-1) %q=1, merge x and q
                        [P,L(r,c)] = set_union(P, L(r,c-1), L(r,c));
                    end
                end
            end
            c = chunksSizeAndLabels(c);
        end

        % Flatten label tree
        k = (1); % unique labels
        c = int32(1); % column number
        while c<=N
            stripeFirstLabel = floor((c-1)/2) * floor((M+1)/2) + 1;
            for i=stripeFirstLabel+1:stripeFirstLabel+chunksSizeAndLabels(c+1)
                if P(i)<i-1
                    P(i) = P(P(i)+1);
                else
                    P(i) = k;
                    k = k+1;
                end
            end
            c = chunksSizeAndLabels(c);
        end

    else % 4 connectivity
        % First scan with Rosenfeld Mask
        % +-+-+-+
        % |-|q|-|
        % +-+-+-+
        % |s|x|
        % +-+-+
        coder.internal.treatAsParfor();
        coder.internal.parallelRelax();
        for thread = 0:nParallelStripes-1
            c = thread*stripeWidth+1; % calculate starting column index
            chunksSizeAndLabels(c) = min((thread+1)*stripeWidth+1,N+1); % store index of ending column in chunksSizeAndLabels
            label = ceil((c-1)*M/2) + 1; % calculate first label of current parallel stripe, the formula makes sure there is no overlaping label usage between parallel stripes
            firstLabel = label;
            startC = c;
            for c = thread*stripeWidth+1 : min((thread+1)*stripeWidth,N)
                for r = 1:M
                    if im(r,c) % current pixel = 1
                        if r>1 && im(r-1,c) % q=1
                            if c>startC && im(r,c-1) % q=s=1, then x<-merge(s,q)
                                % Manually inline set_union due to reduction variable's limitation in parfor:
                                % [P,L(r,c)] = set_union(P, L(r,c-1), L(r-1,c));
                                L(r,c) = L(r,c-1);
                                while P(L(r,c)+1)<L(r,c)
                                    L(r,c) = P(L(r,c)+1);
                                end
                                if L(r,c-1)~=L(r-1,c)
                                    rootj = L(r-1,c);
                                    while P(rootj+1)<rootj
                                        rootj = P(rootj+1);
                                    end
                                    if L(r,c)>rootj
                                        L(r,c) = rootj;
                                    end
                                    while P(L(r-1,c)+1)<L(r-1,c)
                                        j = P(L(r-1,c)+1);
                                        P(L(r-1,c)+1) = L(r,c);
                                        L(r-1,c) = j;
                                    end
                                    P(L(r-1,c)+1) = L(r,c);
                                end
                                while P(L(r,c-1)+1)<L(r,c-1)
                                    j = P(L(r,c-1)+1);
                                    P(L(r,c-1)+1) = L(r,c);
                                    L(r,c-1) = j;
                                end
                                P(L(r,c-1)+1) = L(r,c);

                            else % q=1, s=0, then x<-q
                                L(r,c) = L(r-1,c);
                            end
                        else
                            if c>startC && im(r,c-1) % q=0, s=1, then x<-s
                                L(r,c) = L(r,c-1);
                            else % q=s=0, then create new label for x
                                L(r,c) = label;
                                P(label+1) = label;
                                label = label+1;
                            end
                        end
                    else % current pixel = 0, set for background
                        L(r,c) = 0;
                    end
                end
            end
            chunksSizeAndLabels(startC+1)=label-firstLabel;
        end

        % Merge label 4 connectivity, merge mask:
        % +-+
        % |-|
        % +-+-+
        % |q|x|
        % +-+-+
        % |-|
        % +-+
        c = chunksSizeAndLabels(1); % boundary pixels needs merging, boundary index stored in chunksSizeAndLabels
        while c<=N
            for r = 1:M
                if L(r,c) && L(r,c-1)
                    [P,L(r,c)] = set_union(P, L(r,c-1), L(r,c));
                end
            end
            c = chunksSizeAndLabels(c);
        end

        % Flatten label tree
        k = (1); % unique labels
        c = int32(1); % column number
        while c<=N
            stripeFirstLabel = floor(((c-1)*M)/2) + 1;
            for i=stripeFirstLabel+1:stripeFirstLabel+chunksSizeAndLabels(c+1)
                if P(i)<i-1
                    P(i) = P(P(i)+1);
                else
                    P(i) = k;
                    k = k+1;
                end
            end
            c = chunksSizeAndLabels(c);
        end
    end

    k = k-1;
    % Second scan: assign each label with its equivalent label of lower value
    coder.internal.treatAsParfor();
    for c=1:N
        for r=1:M
            L(r,c) = P(L(r,c)+1);
        end
    end
end

function [P,root] = set_union(P, i, j)
    % in the equivalence tree, P, union label i and j
    coder.inline('always');
    root = findRoot(P,i);
    if i~=j
        rootj = findRoot(P,j);
        if root>rootj
            root = rootj;
        end
        P = setRoot(P,j,root);
    end
    P = setRoot(P,i,root);
end

function root = findRoot(P, i)
    coder.inline('always');
    root = i;
    while P(root+1)<root
        root = P(root+1);
    end
end

function P = setRoot(P, i, root)
    coder.inline('always');
    while P(i+1)<i
        j = P(i+1);
        P(i+1) = root;
        i = j;
    end
    P(i+1) = root;
end
