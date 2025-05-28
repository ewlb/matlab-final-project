function J = alginpaintCoherent(I,mask,radius,SmoothingFactor)
% main algorthm for coherent transport inpainting
%
%     'SmoothingFactor'        Positive scalar value specifying the
%                              standard deviation of the Gaussian filter.
%
%     'Radius'                 Positive scalar value specifying the radius
%                              of the circular neighbor region around the
%                              pixel to inpainted. 

%#codegen
isCodegen = ~coder.target('MATLAB');
% params
rho = 1.5*SmoothingFactor;

% Set kernels
kernelS = max(round(2*SmoothingFactor),1);
kernelR = max(round(2*rho),1);
lenKernel1 = 2*kernelS+1;
lenKernel2 = 2*kernelR+1;
kernel1 = zeros(1,lenKernel1);
kernel2 = zeros(1,lenKernel2);
for ind = 0:lenKernel1-1
    kernel1(ind+1) = exp((-1*(ind-kernelS)*(ind-kernelS))/(2*SmoothingFactor*SmoothingFactor));
end
for ind = 0:lenKernel2-1
    kernel2(ind+1) = exp((-1*(ind-kernelR)*(ind-kernelR))/(2*rho*rho));
end

% padding to inpaint boundary pixels
padval = max([radius,kernelR])+1;
classToUse = class(I);
I = double(I);
[image,mask] = padMatrix(I,mask,padval);
[rows,cols,channels] = size(image);


domain = ~mask;
pointsToInpaint = sum(mask(:));

% main processing 
% 1) order all pixels (to be inpainted) according to transport field (OrderByDistance)
% 2) Start inpainting with lowest to highest transport field pixels (InpaintByOrder)
if (pointsToInpaint ~= 0)
    index = find(mask==1);
    for ch = 1:channels
        image(index + ((ch-1)*rows*cols)) = 0;
    end
    
    [mImage,mDomain] = smoothImage(image,domain,kernel1);
    
    % initialize tField (transport field)
    [tField,flag] = initTfield(domain,padval);
    % store all band points. Band points are the boundary pixels of the
    % region to be inpainted.    
    flagInd = find(flag==4);
    flag(flagInd) = 5;
    [rowInd, colInd] = ind2sub(size(flag),flagInd);
    bandPts = [rowInd(:), colInd(:)];
    
    % OrderByDistance. Ordering the Inpainting Transport Field.
    if isCodegen
        coder.varsize('bandPts');
    end
    [orderedPoints,tField,flag] = orderByDistance(tField,flag,bandPts,pointsToInpaint);
    
    % InpaintByOrder. Inpaint lowest transport field pixel first.
    image = inpaintByOrder(image,mImage,mDomain,tField,flag,kernel1,kernel2,radius,orderedPoints);
end
% remove padding
imageOut = image(padval+1:rows-padval,padval+1:cols-padval,:);
J = cast(imageOut,classToUse);

%--------------------------------------------------------------------------
function [mImage,mDomain] = smoothImage(image,domain,kernel1)
% smooth image
kernel = kernel1'*kernel1;
channels = size(image,3);
mImage = zeros(size(image));
for ch = 1:channels
    mImage(:,:,ch) = imfilter(image(:,:,ch),kernel,'same');
end
mDomain = conv2(domain,kernel,'same');

%--------------------------------------------------------------------------
function [tField,flag] = initTfield(domain,padval)
% default initialization of transport field
% flag matrix is having values 2, 3, 4, 5
% 2 -- Inside painting region
% 3 -- Known region
% 4 -- Band region (boundary region)
% 5 -- Pixels to inpaint
% 6 -- Padding

[rows,cols] = size(domain);
tField = zeros(rows,cols);
flag = zeros(rows,cols,'uint8');
for i = 1:rows
    for j = 1:cols
        if(domain(i,j) == 0)
            flag(i,j)=4;
            tField(i,j)=0;
            if ((domain(i-1,j)==0) && (domain(i+1,j) == 0)...
                    && (domain(i,j-1) == 0) && (domain(i,j+1) == 0))
                % this condition is to find out boundary of mask
                flag(i,j)=2;
                tField(i,j)=Inf;
            end
        else
            flag(i,j)=3;
            tField(i,j)=-1;
        end
    end
end
flag(:,1:padval-1) = 6;
flag(:,cols-padval+2:cols)=6;
flag(1:padval-1,:) = 6;
flag(rows-padval+2:rows,:)=6;

%--------------------------------------------------------------------------
function tFieldUpdate = solveTransport(tField,i,j)
% solve transport equation
update = [0 0 0 0];

update(1) = tField(i-1,j);
update(2) = tField(i+1,j);
update(3) = tField(i,j-1);
update(4) = tField(i,j+1);

updateX = min(update(1),update(2));
updateY = min(update(3),update(4));
if(updateX == Inf && updateY == Inf)
    tFieldUpdate = Inf;
else
    update0 = min(updateX,updateY);
    update1 = max(updateX,updateY);
    diff = update1-update0;
    if (diff>= 1)
        tFieldUpdate = update0 + 1;
    else
        tFieldUpdate = (updateX+updateY+sqrt(2 - diff*diff))/2;
    end
end

%--------------------------------------------------------------------------
function [orderedPoints,tField,flag] = orderByDistance(tField,flag,bandPts,pointsToInpaint)
% OrderByDistance. Ordering the Inpainting Transport Field.
% Order all (to be inpainted) pixels according to their transport field
% pixels with lowest transport field, inpainted first

cnt = 1;
orderedPoints = zeros(pointsToInpaint,3);
% empty bandPts means all pixels are considered (or their transport
% filed estimated)
while ~isempty(bandPts)
    tfieldBand = zeros(size(bandPts,1),1);
    for k = 1:size(bandPts,1)
        tfieldBand(k) = tField(bandPts(k,1),bandPts(k,2));
    end
    % find pixels with lowest tField (transport field)
    [val,idx] = min(tfieldBand);
    actuali = bandPts(idx,1);
    actualj = bandPts(idx,2);
    actualT = val;
    orderedPoints(cnt,:) = [actuali actualj actualT]; % add to ordered points ist
    cnt = cnt + 1;
    
    bandPts(idx,:) = []; % remove pixel from band points list as it is considered or added to orderPoints
    flag(actuali,actualj) = 5; % change the status
    % check for all neighboring pixels of band points
    neighborsX = [actuali+1, actuali-1, actuali, actuali];
    neighborsY = [actualj, actualj, actualj+1, actualj-1];
    
    for p = 1:length(neighborsX)
        indiN = neighborsX(p);
        indjN = neighborsY(p);
        if (flag(indiN,indjN)==2)
            flag(indiN,indjN)=4; % add to band points list
            bandPts = [bandPts; indiN indjN]; %#ok<AGROW>
        end
        if(flag(indiN,indjN)==4)
            % caluclute transport field using neighboring pixels
            tField(indiN,indjN) = solveTransport(tField,indiN,indjN);
        end
    end
end

%--------------------------------------------------------------------------
function image = inpaintByOrder(image,mImage,mDomain,tField,flag,kernel1,kernel2,radius,orderedPoints)
% InpaintByOrder. Inpaint lowest transport field pixel first.

kernel = kernel1'*kernel1;
win = (length(kernel1)-1)/2;
kold = 1;
tFieldOld = orderedPoints(1,3);
channels = size(image,3);
for k = 1:size(orderedPoints,1)
    tFieldAct = orderedPoints(k,3);
    if (tFieldAct>tFieldOld)
        for kk = kold:k-1
            indi = orderedPoints(kk,1);
            indj = orderedPoints(kk,2);
            flag(indi,indj) = 3;
            % smooth update
            for ch = 1:channels
                mImage(indi-win:indi+win,indj-win:indj+win,ch) = mImage(indi-win:indi+win,indj-win:indj+win,ch) + (kernel.*image(indi,indj,ch));
            end
            mDomain(indi-win:indi+win,indj-win:indj+win) = mDomain(indi-win:indi+win,indj-win:indj+win) + kernel;
        end
        kold = k;
        tFieldOld = tFieldAct;
    end
    indi = orderedPoints(k,1);
    indj = orderedPoints(k,2);
    % inpaint points
    image(indi,indj,:) = inpaintPoint(image,mImage,mDomain,tField,flag,indi,indj,kernel2,radius);
end
%--------------------------------------------------------------------------
function imagepoint = inpaintPoint(image,mImage,mDomain,tField,flag,xi,xj,kernel2,radius)
% inpaint pixel with its neighbourhood. Neighborhood defined by radius.
channels = size(image,3);
W = 0;
fixVal = 6.25; % (kappa/epsilon = 25/4)
tempI = zeros(1,channels);
guidance = guidanceEstimation(mImage,mDomain,tField,xi,xj,kernel2);
for yi = xi-radius:xi+radius
    for yj = xj-radius:xj+radius        
        if flag(yi,yj)~=3
            continue;
        end
        if (tField(yi,yj)==tField(xi,xj))
            continue;
        end
        vi = yi-xi;
        vj = yj-xj;
        radiusTemp = sqrt(vi.^2 + vj.^2);
        if (radiusTemp>radius)
            continue;
        end
        zval = fixVal;
        zval = zval*zval;
        zval = zval*((guidance(1)*vi*vi)+(2*guidance(2)*vi*vj)+(guidance(3)*vj*vj));
        weight = exp(-0.5*zval)/radiusTemp;
        weight = 1+ (1.844674407370955e+19 * weight); % author suggested constant
        W = W + weight;
        for ch = 1:channels
            tempI(ch) = tempI(ch) + weight*image(yi,yj,ch);
        end
    end
end
imagepoint = tempI/W;

%--------------------------------------------------------------------------
function guidance = guidanceEstimation(MImage,MDomain,T,xi,xj,SKernel2)
% estimate inpainting direction or guidance
% guidance is estimated based on the structure tensor
guidance = zeros(1,3);
stTensor = modStructureTensor(MImage,MDomain,T,xi,xj,SKernel2);
quant = 1;
diff = stTensor(1)-stTensor(3);
cohMeas = diff*diff + (4*stTensor(2)*stTensor(2));
cohMeasSqrt = sqrt(cohMeas);

if (cohMeas == 0)
    confidence = 0;
else
    confidence = exp(-1*quant/cohMeas)/cohMeasSqrt;
end
guidance(1) = 0.5*confidence*(diff + cohMeasSqrt);
guidance(2) = confidence*stTensor(2);
guidance(3) = 0.5*confidence*(-1*diff + cohMeasSqrt);

%--------------------------------------------------------------------------
function stTensor = modStructureTensor(mImage,mDomain,tField,xi,xj,kernel2)
% estimate structure tensor around a pixel
channels = size(mImage,3);

lenKernel2 = length(kernel2);
r = (lenKernel2-1)/2;

stTensor = [0 0 0];

for ch = 1:channels
    vs = [0 0 0];
    w = 0;
    for i=1:lenKernel2
        ri = xi+r-(i-1);
        vsh = [0 0 0];
        wh = 0;
        for j = 1:lenKernel2
            rj = xj+r-(j-1);
            if(tField(ri,rj) >= tField(xi,xj))
                continue;
            end
            
            u0 = mImage(ri-1,rj,ch)/mDomain(ri-1,rj);
            u1 = mImage(ri+1,rj,ch)/mDomain(ri+1,rj);
            dx = (u1 - u0)/2;
            
            u0 = mImage(ri,rj-1,ch)./mDomain(ri,rj-1);
            u1 = mImage(ri,rj+1,ch)/mDomain(ri,rj+1);
            dy = (u1-u0)/2;
            
            vsh(1) = vsh(1) + (kernel2(j)*dx*dx);
            vsh(2) = vsh(2) + (kernel2(j)*dx*dy);
            vsh(3) = vsh(3) + (kernel2(j)*dy*dy);
            wh = wh + kernel2(j);
        end
        vs(1) = vs(1) + (kernel2(i)*vsh(1));
        vs(2) = vs(2) + (kernel2(i)*vsh(2));
        vs(3) = vs(3) + (kernel2(i)*vsh(3));
        w = w + (kernel2(i)*wh);
    end
    stTensor(1) = stTensor(1) + (vs(1)/w);
    stTensor(2) = stTensor(2) + (vs(2)/w);
    stTensor(3) = stTensor(3) + (vs(3)/w);
end
stTensor(1) = stTensor(1)/3;
stTensor(2) = stTensor(2)/3;
stTensor(3) = stTensor(3)/3;

%--------------------------------------------------------------------------
function [image,mask] = padMatrix(I,mask,padval)
[rows,cols,channels] = size(I);
maskBorder = [mask(1,:) mask(rows,:) mask(:,1)' mask(:,cols)'];
ind = find((maskBorder==1));
imageBorder = zeros(size(I,3),numel(maskBorder));
for ch = 1:size(I,3)
    imageBorder(ch,:) = [I(1,:,ch) I(rows,:,ch) I(:,1,ch)' I(:,cols,ch)'];
end
imageBorder(:,ind) = NaN;
indLength = 1:numel(maskBorder);
if numel(ind) < 2*(rows+cols)-1
    for ch = 1:channels
        tempBorder = imageBorder(ch,:);
        tempBorder(isnan(tempBorder)) = interp1(indLength(~isnan(tempBorder)),...
            tempBorder(~isnan(tempBorder)),indLength(isnan(tempBorder)),...
            'nearest','extrap');
        imageBorder(ch,:) = tempBorder;
    end
end
for ch = 1:channels
    I(1,:,ch) = imageBorder(ch,1:cols);
    I(rows,:,ch) = imageBorder(ch,cols+1:2*cols);
    I(:,1,ch) = imageBorder(ch,2*cols+1:end-rows)';
    I(:,cols,ch) = imageBorder(ch,end-rows+1:end)';
end
image = double(padarray(I,[padval,padval],'replicate'));
mask = padarray(mask,[padval,padval]);
