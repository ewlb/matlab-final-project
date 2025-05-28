function [D, labels] = ddist(BW, conn, weights, computeFT, D, labels) %#codegen
% ddist - Distance and feature transform algorithm for chessboard, cityblock and quasi-euclidean

% Copyright 2017-2018 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(conn, weights, computeFT);

np = images.internal.coder.NeighborhoodProcessor(size(BW), conn,...
    'NeighborhoodCenter', images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT,...
    'Padding',1,'ProcessBorder',false);
np.updateInternalProperties();

numPixels = coder.internal.indexInt(numel(BW));

% Initialize the distance and labels arrays.  The initial distance
% corresponding to any one-valued element of BW is 0; the initial distance
% for all other locations is Inf.  The initial label corresponding to any
% one-valued element of BW is the linear index of that element.  The
% initial label for all other elements is 0.
if numel(size(BW)) == 2
    for j = 1:size(BW,2)
        for i = 1:size(BW,1)
            if BW(i,j)
                D(i,j) = single(0);
                if (computeFT)
                    labels(i,j) = sub2ind(size(BW),i,j);
                end
            else
                D(i,j) = coder.internal.inf('single');
                if (computeFT)
                    labels(i,j) = 0;
                end
            end
        end
    end
elseif numel(size(BW)) == 3 %3-D
    for k = 1:size(BW,3)
        for j = 1:size(BW,2)
            for i = 1:size(BW,1)
                if BW(i,j,k)
                    D(i,j,k) = single(0);
                    if (computeFT)
                        labels(i,j,k) = sub2ind(size(BW),i,j,k);
                    end
                else
                    D(i,j,k) = coder.internal.inf('single');
                    if (computeFT)
                        labels(i,j,k) = 0;
                    end
                end
            end
        end
    end
else %N-D
    for k = 1:numel(BW)
        if BW(k)
            D(k) = single(0);
            if (computeFT)
                labels(k) = sub2ind(size(BW),k);
            end
        else
            D(k) = coder.internal.inf('single');
            if (computeFT)
                labels(k) = 0;
            end
        end
    end
end

% First pass, scan from the top left to bottom right
for pInd = 1:numPixels
    minValue = coder.internal.inf('single');
    [imnhInds, nhInds] = np.getNeighborIndices(pInd);
    
    if (computeFT)
        currentLabel = labels(pInd);
    end
    
    % Assign only the trailing neighbor indices
    trailingImInds = coder.nullcopy(imnhInds);
    trailingNhInds = coder.nullcopy(nhInds);
    trailIdx = 0;
    for nIdx = 1:numel(imnhInds)
        if imnhInds(nIdx) <= pInd
            trailIdx = trailIdx + 1;
            trailingImInds(trailIdx) = imnhInds(nIdx);
            trailingNhInds(trailIdx) = nhInds(nIdx);
        end
    end
    
    % trailIdx has the count of number of trailing neighbors
    for nIdx = 1:trailIdx
        % Find the minimum of distance[q] + weights[q] for all q in the
        % trailing neighborhood. The label stored in the location that
        % minimizes distance[q] + weights[q] is the label that we will
        % propagate to location p.
        newValue = D(trailingImInds(nIdx)) + single(weights(trailingNhInds(nIdx)));
        if (newValue < minValue)
            minValue = newValue;
            if (computeFT)
                currentLabel = labels(trailingImInds(nIdx));
            end
        end
    end
    
    D(pInd) = minValue;
    if (computeFT)
        labels(pInd) = currentLabel;
    end
end

% Second pass, scan from lower right to upper left along columns.
for pInd = numPixels:-1:1
    
    minValue = D(pInd);
    [imnhInds, nhInds] = np.getNeighborIndices(pInd);
    
    if (computeFT)
        currentLabel = labels(pInd);
    end
    
    % Assign only the trailing neighbor indices
    leadingImInds = coder.nullcopy(imnhInds);
    leadingNhInds = coder.nullcopy(nhInds);
    leadIdx = 0;
    for nIdx = 1:numel(imnhInds)
        if imnhInds(nIdx) >= pInd
            leadIdx = leadIdx + 1;
            leadingImInds(leadIdx) = imnhInds(nIdx);
            leadingNhInds(leadIdx) = nhInds(nIdx);
        end
    end
    
    % leadIdx has the count of number of leading neighbors
    for nIdx = 1:leadIdx
        % Find the minimum of distance[q] + weights[q] for all q in the
        % leading neighborhood. The label stored in the location that
        % minimizes distance[q] + weights[q] is the label that we will
        % propagate to location p.
        newValue = D(leadingImInds(nIdx)) + single(weights(leadingNhInds(nIdx)));
        if (newValue < minValue)
            minValue = newValue;
            if (computeFT)
                currentLabel = labels(leadingImInds(nIdx));
            end
        end
    end
    
    D(pInd) = minValue;
    if (computeFT)
        labels(pInd) = currentLabel;
    end
end
