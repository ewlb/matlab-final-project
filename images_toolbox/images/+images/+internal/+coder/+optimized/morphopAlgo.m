function B = morphopAlgo(A, nhood , height, op_type, B) %#codegen
% This function is an optimized version for imerode and imdilate and
% currently handles 2D images and 2D strels only.

% This version performs minimal random data accesses (read/write) by 
% ignoring irrelevant pixels in a neighborhood instead of reading
% relevant pixels in the neighborhood.
% Relevant pixels in a neighborhood are pixels in image neighborhood that
% correspond to 1s in strel. Thus,this version is optimal for strels that 
% have more number of 1s than that of 0s. For example, disk and octagon
% satisfy this condition.
 
%   Copyright 2014-2021 The MathWorks, Inc.

op_type = coder.const(op_type);

if(isempty(A))
    return;
end

if(isfloat(A))
    minVal = -inf('like',A);
    maxVal =  inf('like',A);
elseif(islogical(A))
    minVal = false;
    maxVal = true;
else % integer
    minVal = intmin(class(A));
    maxVal = intmax(class(A));
end

%% Edge case - handle empty nhoods
if(isempty(nhood))
    switch(op_type)
        case 'dilate'
            val = minVal;
        case 'erode'
            val = maxVal;
        otherwise
            assert(false,'Unknown operation');
    end
    for lind = 1:numel(A)
        B(lind) = val;
    end
    return;
end


%% Core implementation
switch (op_type)
    case 'dilate'
        initVal = double(minVal);
        
        % Reflect nhood
        if(ismatrix(A))
            % If ndims(nhood)>2, then trailing nhood dimension don't count.
            % Effectively, reflect only the first plane. (the rest get
            % flipped, but they are 'don't-cares').
            nhood  = flip(flip(nhood,1),2);
            height = flip(flip(height,1),2);
        else
            nhood(1:end)  = nhood(end:-1:1);
            height(1:end) = height(end:-1:1);
        end
                
        params.initVal = initVal;
        params.height  = height;
                
        if(all(height(:)==0))
            centerPixelSub = ceil((size(nhood)+1)./2); %neighborhood center is bottom right
        else
            centerPixelSub = floor((size(nhood)+1)./2); %neighborhood center is top left
        end        
        B = morphopNeighborhood(A,nhood,@dilateAlgo, B, params, centerPixelSub);              
        
    case 'erode'
        initVal = double(maxVal);
        
        params.initVal = initVal;
        params.height  = height;
                
        centerPixelSub = floor((size(nhood)+1)./2); %neighborhood center is top left
        B = morphopNeighborhood(A,nhood,@erodeAlgo, B, params, centerPixelSub); 

    otherwise
        assert(false,'Unknown operation');
end

end


function pixelout = dilateAlgo(imnh, nhConn, params)
% Find maximum in pixel neighborhood while ignoring
% irrelevant pixels by setting them to minimum possible value
    coder.inline('always');
    if(islogical(imnh))
        imnh(~nhConn) = params.initVal;
        pixelout = any(imnh(:));
    else
        % Fix to prevent implicit expansion: g2542855
        imnh = coder.sameSizeBinaryOp(@plus, double(imnh), params.height);
        imnh(~nhConn) = params.initVal; 
        pixelout = max([imnh(:); params.initVal]);
    end    
end
 
function pixelout = erodeAlgo(imnh, nhConn, params)
% Find minimum in pixel neighborhood while ignoring
% irrelevant pixels by setting them to maximum possible value
    coder.inline('always');    
    if(islogical(imnh))
        imnh(~nhConn) = params.initVal;
        pixelout = all(imnh(:));
    else
        % Fix to prevent implicit expansion: g2542855
        imnh = coder.sameSizeBinaryOp(@minus, double(imnh), params.height);
        imnh(~nhConn) = params.initVal; 
        pixelout = min([imnh(:); params.initVal]);
    end    
end

function B = morphopNeighborhood(A,nhConn, fhandle, B,params, centerPixelSub)
    coder.inline('always');
    coder.internal.prefer_const(params);
    coder.internal.prefer_const(centerPixelSub);
    
    connSize = size(nhConn);
    
    %Compute the number of columns and rows to be padded on all sides of
    %the image. Note that for even sized strels, number of columns/rows to 
    %be padded on each side (left vs right)/(top vs bottom) differs, as 
    %the chosen strel center is not the geometrically center of strel.  
    %That is, (leftPad ~= rightPad) or/and (topPad ~= bottomPad).
    leftPad = centerPixelSub(1)-1;     
    rightPad = connSize(1)-centerPixelSub(1);
    topPad = centerPixelSub(2)-1;
    bottomPad = connSize(2)-centerPixelSub(2);    
    
    if(mod(connSize(1),2)==0 || mod(connSize(2),2)==0) 
        %Even sized strels
        %This will cause two extra memcpys of the image, but this is
        %unavoidable due to limitation of padarray
        Apad = padarray(A,[leftPad, topPad],params.initVal, 'pre');
        Apad = padarray(Apad,[rightPad, bottomPad],params.initVal, 'post'); 
    else
        %Odd sized strels
        Apad = padarray(A,[leftPad, topPad],params.initVal, 'both');        
    end
      
    imageSize = size(A);
    
    switch numel(imageSize)
        case 2
            thirdIndRange = 1;
        case 3
            thirdIndRange = imageSize(3);
    end
    
    for thirdInd = 1: thirdIndRange
        imnhprev = coder.nullcopy(zeros(connSize, 'like', A));
        for secondInd = 1:imageSize(2)
            for firstInd = 1:imageSize(1) 
                if(firstInd~=1)
                    imnh = [imnhprev(2:end,:); Apad(firstInd+connSize(1)-1,secondInd+(0:connSize(2)-1),thirdInd)]; 
                else
                    imnh = Apad(firstInd+(0:connSize(1)-1),secondInd+(0:connSize(2)-1),thirdInd); 
                end
                imnhprev = imnh;
                B(firstInd, secondInd, thirdInd) = fhandle(imnh, nhConn, params);           
            end
        end
    end     
end