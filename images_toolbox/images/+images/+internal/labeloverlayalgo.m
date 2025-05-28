function B = labeloverlayalgo(A,L,colormap,alphaVal,includeLabelList)
% Overlay label matrix region on a 2D image.

% Copyright 2017-2020 The MathWorks, Inc.

if ismatrix(A)
    A = repmat(A,[1 1 3]); % Convert grayscale image to 3 identical planes
end

if isscalar(alphaVal)
    alphamap = zeros([1,size(colormap,1)],'single');
else
    alphamap = alphaVal;
end
    
if any(includeLabelList == 0)
    % includeLabelList contains label 0, add 1 for indexing
    alphamap(includeLabelList+1) = alphaVal;
else
    
    if isscalar(alphaVal)
        alphamap(includeLabelList) = alphaVal;
    end
    
    % Modify colormap to include room for the zero label
    colormap = [colormap(1,:);colormap];
    alphamap = [0,alphamap];
end
B = images.internal.builtins.labeloverlay(A,L,colormap,alphamap);
