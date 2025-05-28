function outputImage = remapAndResampleGeneric2d(inputImage,R_A,tform,outputRef,method,fillValues, SmoothEdges) %#codegen
%#ok<*EMCA>

% Copyright 2019-2024 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(R_A,tform,outputRef,method,fillValues,inputImage);
coder.internal.errorIf(~coder.internal.isConst(method),...
    'MATLAB:images:validate:codegenInputNotConst', 'METHOD');

tinv = inv(tform.T);
coder.internal.prefer_const(tinv);

% Output image size used for preallocating querypoint matrices.
outPutRes = outputRef.ImageSize;
nRows =(outPutRes(1));
nCols =(outPutRes(2));

coder.extrinsic('images.internal.coder.useOptimizedFunctions');

% Branch only when the transform is affine2d with nearest interpolation
% or OptimizedFunctions flag is turned off.
if isa(tform, 'projtform2d') || strcmp(method, 'cubic') || strcmp(method, 'linear') || ~coder.const(images.internal.coder.useOptimizedFunctions())

    srcXIntrinsic = coder.nullcopy(zeros(outPutRes));
    srcYIntrinsic = coder.nullcopy(zeros(outPutRes));
    
    % Form a plaid grid of output world co-ordinates. This portion contains
    % both meshgrid operation and intrinsic to world co-ordinate conversion as a
    % single operation.
    if coder.const(~coder.isRowMajor)
        parfor colIdx=1:nCols
            dstXWorld_val = outputRef.XWorldLimits(1) + (colIdx-0.5).* outputRef.PixelExtentInWorldX;
            for rowIdx=1:nRows
                dstYWorld_val = outputRef.YWorldLimits(1) + (rowIdx-0.5).* outputRef.PixelExtentInWorldY;
                % Use scalar var x instead of dstXWorld(rowIdx,colIdx)
                % This is sufficient for affine transformation. The projective
                % transformation needs some normalization.
                srcXWorld_val = tinv(1,1)*dstXWorld_val + tinv(2,1)*dstYWorld_val + tinv(3,1);
                srcYWorld_val = tinv(1,2)*dstXWorld_val + tinv(2,2)*dstYWorld_val + tinv(3,2);
                
                % Required only for projective transformation.
                if isa(tform,'projtform2d')
                    srczWorld_val =  tinv(1,3)*dstXWorld_val + tinv(2,3)*dstYWorld_val + tinv(3,3);
                    srcXWorld_val = srcXWorld_val./srczWorld_val;
                    srcYWorld_val = srcYWorld_val./srczWorld_val;
                end
                
                % Convert the query points to intrinsic co-ordinate system
                srcXIntrinsic(rowIdx, colIdx) = 0.5 + (srcXWorld_val-R_A.XWorldLimits(1)) / R_A.PixelExtentInWorldX;
                srcYIntrinsic(rowIdx, colIdx) = 0.5 + (srcYWorld_val-R_A.YWorldLimits(1)) / R_A.PixelExtentInWorldY;
            end
        end
    else % if row major
        parfor rowIdx=1:nRows
            dstYWorld_val = outputRef.YWorldLimits(1) + (rowIdx-0.5).* outputRef.PixelExtentInWorldY;
            for colIdx=1:nCols
                dstXWorld_val = outputRef.XWorldLimits(1) + (colIdx-0.5).* outputRef.PixelExtentInWorldX;
                % Use scalar var x instead of dstXWorld(rowIdx,colIdx)
                % This is sufficient for affine transformation. The projective
                % transformation needs some normalization.
                srcXWorld_val = tinv(1,1)*dstXWorld_val + tinv(2,1)*dstYWorld_val + tinv(3,1);
                srcYWorld_val = tinv(1,2)*dstXWorld_val + tinv(2,2)*dstYWorld_val + tinv(3,2);
                
                % Required only for projective transformation.
                if isa(tform,'projtform2d')
                    srczWorld_val =  tinv(1,3)*dstXWorld_val + tinv(2,3)*dstYWorld_val + tinv(3,3);
                    srcXWorld_val = srcXWorld_val./srczWorld_val;
                    srcYWorld_val = srcYWorld_val./srczWorld_val;
                end
                
                % Convert the query points to intrinsic co-ordinate system
                srcXIntrinsic(rowIdx, colIdx) = 0.5 + (srcXWorld_val-R_A.XWorldLimits(1)) / R_A.PixelExtentInWorldX;
                srcYIntrinsic(rowIdx, colIdx) = 0.5 + (srcYWorld_val-R_A.YWorldLimits(1)) / R_A.PixelExtentInWorldY;
            end
        end
    end
    
    % Mimics syntax of interp2. Has different edge behavior that uses 'fill'
    outputImage = images.internal.interp2d(inputImage,srcXIntrinsic,srcYIntrinsic,method,fillValues, SmoothEdges);
else
    % This branch affects the nearest neighbor interpolation method
    % for affine2d transforms only and uses optimizationFunctions flag
    
    % Allocating 2*numRows and 2*numCols sized arrays instead of a grid
    % because a grid has repeated values.
    srcXIntrinsic = coder.nullcopy(zeros(nCols, 2));
    srcYIntrinsic = coder.nullcopy(zeros(nRows, 2));

    for colIdx=1:nCols
        dstX = outputRef.XWorldLimits(1) + (colIdx - 0.5);
        srcXIntrinsic(colIdx, 1) = tinv(1,1) * dstX;
        srcXIntrinsic(colIdx, 2) = tinv(1,2) * dstX;
    end
    for rowIdx=1:nRows
        dstY = outputRef.YWorldLimits(1) + (rowIdx - 0.5);
        srcYIntrinsic(rowIdx, 1) = tinv(2,1) * dstY;
        srcYIntrinsic(rowIdx, 2) = tinv(2,2) * dstY;
    end

    inputClass = class(inputImage);

    if islogical(inputImage)
        inputImage_ = uint8(inputImage);
    else
        inputImage_ = inputImage;
    end
    
    % First cast to match the behavior of MATLAB
    % Second cast to make sure fillValues is the same type of inputImage
    fillValues_ = cast(fillValues, 'like', inputImage);
    fillValues = cast(fillValues_, 'like', inputImage_);

    if ((numel(size(inputImage_)) ~= 2) && isscalar(fillValues))
        % If we are doing plane at time behavior, make sure fillValues
        % always propagates through code as a matrix of size determine by
        % dimensions 3:end of inputImage.
        sizeInputImage = size(inputImage_);
        if (numel(size(inputImage_)) == 3)
            % This must be handled as a special case because repmat(X,N)
            % replicates a scalar X as a NxN matrix. We want a Nx1 vector.
            sizeVec = [sizeInputImage(3) 1];
        else
            sizeVec = sizeInputImage(3:end);
        end
        fill = repmat(fillValues,sizeVec);

    else
        fill = fillValues;
    end
    
    pad = 0;

    if(SmoothEdges)
        % padImageAffine fetches a pad value to be added for
        % coordinate computation below.
        [inputImagePadded, pad] = padImageAffine(inputImage_,fill);
    else
        inputImagePadded = inputImage_;
    end

    X_ = srcXIntrinsic;
    Y_ = srcYIntrinsic;

    if ~ismatrix(inputImagePadded)
        sizeInputVec = size(inputImagePadded);
        outputImage = zeros([size(Y_,1) size(X_,1) sizeInputVec(3:end)],'like',inputImagePadded);
    else
        outputImage = zeros([size(Y_,1) size(X_,1)],'like',inputImagePadded);
    end

    t_x = tinv(3, 1);
    t_y = tinv(3, 2);

    F_FILL = false;
    P = 0;
    fillImage = false;

    
    if ~isempty(fill)
        if any(fill ~= 0)
            F_FILL = true;
            P = size(inputImage_, 3);
            fillImage = zeros([size(Y_,1) size(X_,1)], 'logical');
        end
    end

    numCols = size(X_, 1);
    numRows = size(Y_, 1);

    parfor colIdx=1:numCols
        for rowIdx=1:numRows
            % For each pixel, do additions only instead of
            % multiplying recurring values.
            x_coord = X_(colIdx, 1) + Y_(rowIdx, 1) + pad + t_x;
            y_coord = X_(colIdx, 2) + Y_(rowIdx, 2) + pad + t_y;
            
            if (x_coord >= 1.0 && ...
                    x_coord <= size(inputImagePadded,2) && ...
                    y_coord >= 1.0 && ...
                    y_coord <= size(inputImagePadded, 1))
                
                ix = floor(x_coord);
                iy = floor(y_coord);
                
                if(x_coord - ix >= 0.5)
                    iix = ix + 1;
                else
                    iix = ix;
                end
                
                if(y_coord - iy >= 0.5)
                    iiy = iy + 1;
                else
                    iiy = iy;
                end
                outputImage(rowIdx, colIdx, :) = inputImagePadded(iiy, iix, :);
            elseif F_FILL
                % Needed to fill values in the outputImage.
                fillImage(rowIdx, colIdx) = true;
            
            end
        end
    end
    
    if F_FILL
        if (coder.isColumnMajor)
            parfor colIdx=1:numCols
                for rowIdx=1:numRows
                    if fillImage(rowIdx, colIdx)
                        for i = 1:P
                            outputImage(rowIdx, colIdx, i) = fill(i);
                        end
                    end
                end
            end
        else
            parfor rowIdx=1:numRows
                for colIdx=1:numCols
                    if fillImage(rowIdx, colIdx)
                        for i = 1:P
                            outputImage(rowIdx, colIdx, i) = fill(i);
                        end
                    end
                end
            end
        end
    end

    if (islogical(inputImage))
        outputImage = outputImage > 0.5;
    else
        outputImage = cast(outputImage, inputClass);
    end
end

function [paddedImage,pad] = padImageAffine(inputImage,fillValues)
% We achieve the 'fill' pad behavior from makeresampler by pre-padding our
% image with the fillValues and translating our X,Y locations to the
% corresponding locations in the padded image. We pad two elements in each
% dimension to account for the limiting case of bicubic interpolation,
% which has a interpolation kernel half-width of 2.

coder.inline('always');
coder.internal.prefer_const(inputImage,fillValues);

% This is the value which needs to be added to generated coordinates.
pad = 3;

if isscalar(fillValues) && (numel(size(inputImage)) == 2)
    % fillValues must be scalar and inputImage must be compile-time 2D
    paddedImage = padarray(inputImage,[pad pad],fillValues);
else
    sizeInputImage = size(inputImage);
    sizeOutputImage = sizeInputImage;
    sizeOutputImage(1) = sizeOutputImage(1) + 2*pad;
    sizeOutputImage(2) = sizeOutputImage(2) + 2*pad;
    paddedImage = zeros(sizeOutputImage,'like',inputImage);
    [~,~,numPlanes] = size(inputImage);
    for i = 1:numPlanes
        paddedImage(:,:,i) = padarray(inputImage(:,:,i),[pad pad],fillValues(i));
    end

end
