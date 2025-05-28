function outImg = medfilt2(inImg, mn, padopt, isHistogramSort)%#codegen
%#ok<*EMCA>
% Copyright 2019-2021 The MathWorks, Inc.
% This function is an optimized version of medfilt2.

% Histogram Sort: 
%                Valid datatypes : 'uint8','int8' 
%                Filter size     : M x N with M and N greater than 3
%                Uses Fast Two-Dimensional Median Filtering Algorithm by T.S Huang et. al
%
% Pixel sort : 
%                Filter sizes    : 3x3 all datatypes 
%                                  5x5 all datatypes excluding Histogram datatypes


% mn : filter dimensions [x y]

classType = class(inImg);
[rows,cols]=size(inImg);
outImg = coder.nullcopy(zeros(rows,cols,classType));

padSize = floor(mn/2);

coder.internal.prefer_const(mn,padopt,padSize,isHistogramSort);

if strcmp(padopt,'zeros') % median filter for ZERO padding
    inImg = padarray(inImg,padSize,0,'both');
    
elseif strcmp(padopt,'ones') % median filter for ONE padding
    inImg = padarray(inImg,padSize,1,'both');
else % median filter for SYMMETRIC padding
    inImg = padarray(inImg,padSize,'symmetric','both');
end

if ~isHistogramSort
    % Pixel Sort
    if mn(1) == 3 % filterSize==3x3
        if coder.const(coder.isColumnMajor)
            parfor j=1:cols
                for i=1:rows
                    region=zeros(3,3,classType);
                    region(:,:)=inImg(i:i+2,j:j+2);
                    outImg(i,j)=median9(region(:));
                end
            end
        else % is row major
            parfor i=1:rows
                for j=1:cols
                    region=zeros(3,3,classType);
                    region(:,:)=inImg(i:i+2,j:j+2);
                    outImg(i,j)=median9(region(:));
                end
            end
        end
    else % filterSize==5x5
        if coder.const(coder.isColumnMajor)
            parfor j=1:cols
                for i=1:rows
                    region=zeros(5,5,classType);
                    region(:,:)=inImg(i:i+4,j:j+4);
                    outImg(i,j)=median25(region(:));
                end
            end
        else % is row major
            parfor i=1:rows
                for j=1:cols
                    region=zeros(5,5,classType);
                    region(:,:)=inImg(i:i+4,j:j+4);
                    outImg(i,j)=median25(region(:));
                end
            end
        end
    end
else
    % Histogram Sort
    midSize = prod(mn)/2;
    filterSizeMinusX = mn(1)-1; 
    filterSizeMinusY = mn(2)-1; 
    histSize = coder.internal.indexInt(double(intmax(classType)) - double(intmin(classType))+1); % Size of Histogram
    bias = coder.internal.indexInt(-double(intmin(classType))); % Offset for mapping signed integers to histogram
    
    if logical(rem(prod(mn),2))
        % Odd-filter size
        parfor j = 1:cols
            histArray =  coder.internal.indexInt(zeros(histSize,1)); % Histogram to store pixel values
            region = inImg(1:filterSizeMinusX,j:j+filterSizeMinusY); % Region of image 
            slicePrevious = inImg(1, j:j+filterSizeMinusY); 
            leftMedian =  coder.internal.indexInt(zeros(1,1)); % Number of entries in Histogram less than median value
            localMedian = cast(-bias,'like',inImg); % local median of the region
            
            % Prepopulate the Histogram with first region
            for i = 1:numel(region)
                histArray(coder.internal.indexPlus(region(i),1)+bias) = ...
                    histArray(coder.internal.indexPlus(region(i),1)+bias) + 1;
            end
            for i = 1:numel(slicePrevious)
                histArray(coder.internal.indexPlus(slicePrevious(i),1)+bias) = ...
                    histArray(coder.internal.indexPlus(slicePrevious(i),1)+bias) + 1;
            end
            
            % Load slice and update histogram
            for i = 1:rows
                sliceNew = (inImg(i+filterSizeMinusX , j:j+filterSizeMinusY));
                [histArray,localMedian,leftMedian] = updateHistogramOdd(histArray,...
                    sliceNew,slicePrevious,localMedian,leftMedian,bias,midSize);
                slicePrevious = inImg(i, j:j+filterSizeMinusY);
                % Assign local median to output image
                outImg(i,j) = cast(localMedian,'like',inImg);
            end
        end
    else
        % Even-filter size
        offset = (rem(mn+1,2)); % For even sized filter dimension, 
                                % the center pixel is assumed to be at top-left to the center.
        
        coder.internal.treatAsParfor();
        coder.internal.parallelRelax();
        for j = 1+offset(2):cols+offset(2)
            
            histArray =  coder.internal.indexInt(zeros(histSize,1));  % Histogram to store pixel values
            region = inImg(1+offset(1):filterSizeMinusX+offset(1),j:j+filterSizeMinusY); % Region of image 
            slicePrevious = inImg(1+offset(1), j:j+filterSizeMinusY);
            leftMedian =  coder.internal.indexInt(zeros(1,1)); % Number of entries in Histogram less than median value
            localMedian = cast(-bias,'like',inImg); % local median of the region
            
            % Prepopulate the Histogram with first region
            for i = 1:numel(region)
                histArray(coder.internal.indexPlus(region(i),1)+bias) = ...
                    histArray(coder.internal.indexPlus(region(i),1)+bias) + 1;
            end
            for i = 1:numel(slicePrevious)
                histArray(coder.internal.indexPlus(slicePrevious(i),1)+bias) = ...
                    histArray(coder.internal.indexPlus(slicePrevious(i),1)+bias) + 1;
            end
            
            % Load slice and update histogram
            for i = 1+offset(1):rows+offset(1)
                sliceNew = (inImg(i+filterSizeMinusX , j:j+filterSizeMinusY));
                [histArray,localMedian,leftMedian,Rmedian] = updateHistogramEven(histArray,...
                    sliceNew,slicePrevious,localMedian,leftMedian,bias,midSize);
                slicePrevious = inImg(i, j:j+filterSizeMinusY);
                outImg(i-(offset(1)),j-(offset(2))) = Rmedian;
            end
        end
    end
end

function [histArray,localMedian,leftMedian,Rmedian] = updateHistogramEven(...
    histArray,sliceNew,slicePrevious,localMedian,leftMedian,Bias,midSize)

mn = numel(slicePrevious);

% Update Histogram
for i = 1:mn
    
    histArray(coder.internal.indexPlus(sliceNew(i),1)+Bias) = ...
        histArray(coder.internal.indexPlus(sliceNew(i),1)+Bias) + 1;
    histArray(coder.internal.indexPlus(slicePrevious(i),1)+Bias) = ...
        histArray(coder.internal.indexPlus(slicePrevious(i),1)+Bias) - 1;
    
    if slicePrevious(i) < localMedian
        leftMedian = leftMedian - 1;
    end
    if sliceNew(i) < localMedian
        leftMedian = leftMedian + 1;
    end
end

pixelCount = leftMedian + histArray(coder.internal.indexPlus(localMedian,1)+Bias);

% Even filter requires finding and averaging (mn/2)-th and (mn/2 + 1)-th pixels
% in Histogram. 
tempMedian = localMedian;  % (mn/2 +1)-th value.


% Iterate till median is found 
if leftMedian < round(midSize)
    
    % Case: New median greater than previous median
    % Iterate to right-side in Histogram.
    tempPixelCount = pixelCount;
    leftMedian = pixelCount;
    while (tempPixelCount < midSize+1)
        tempMedian = tempMedian + 1;
        tempPixelCount = tempPixelCount + histArray(coder.internal.indexPlus(tempMedian,1) + Bias);
        if leftMedian < round(midSize)
            localMedian = localMedian + 1;
            leftMedian = leftMedian + histArray(coder.internal.indexPlus(localMedian,1) + Bias);
        end
    end
    leftMedian = leftMedian - histArray(coder.internal.indexPlus(localMedian,1)+Bias);
    Rmedian = cast(((single(tempMedian)+single(localMedian))/2),'like',localMedian);
else

    % Iterate to left-side in Histogram.
    tempPixelCount = leftMedian;
    while leftMedian >= round(midSize)
        localMedian = localMedian - 1;
        leftMedian = leftMedian - histArray(coder.internal.indexPlus(localMedian,1)+Bias);
        if tempPixelCount > round(midSize)
            tempMedian = tempMedian - 1;
            tempPixelCount = tempPixelCount - histArray(coder.internal.indexPlus(tempMedian,1)+Bias);
        end
    end
    
    if leftMedian + histArray(coder.internal.indexPlus(localMedian,1)+Bias)>=  round(midSize)+1
        % Case: New median less than previous median; tempMedian ==
        % localMedian
        Rmedian = localMedian;
    elseif tempPixelCount + histArray(coder.internal.indexPlus(tempMedian,1)+Bias)>=  round(midSize)+1
        % Case: New median less than previous median; tempMedian ~=
        % localMedian
        Rmedian = cast(((single(tempMedian)+single(localMedian))/2),'like',localMedian);
    else
        % Case: localMedian less than previous median and tempMedian
        % greater than previous median
        while tempPixelCount < round(midSize) +1
            tempMedian = tempMedian + 1;
            tempPixelCount = tempPixelCount + histArray(coder.internal.indexPlus(tempMedian,1)+Bias);
        end
        Rmedian = cast(((single(tempMedian)+single(localMedian))/2),'like',localMedian);
    end
end

function [histArray,localMedian,leftMedian] = updateHistogramOdd...
    (histArray,sliceNew,slicePrevious,localMedian,leftMedian,Bias,midSize)
mn = numel(slicePrevious);

% Update Histogram
for i = 1:mn
    histArray(coder.internal.indexPlus(sliceNew(i),1)+Bias) = ...
        histArray(coder.internal.indexPlus(sliceNew(i),1)+Bias) + 1;
    histArray(coder.internal.indexPlus(slicePrevious(i),1)+Bias) = ...
        histArray(coder.internal.indexPlus(slicePrevious(i),1)+Bias) - 1;
    % Keeps track of elements less than local median
    if slicePrevious(i) < localMedian
        leftMedian = leftMedian - 1;
    end
    if sliceNew(i) < localMedian
        leftMedian = leftMedian + 1;
    end
end

pixelCount = leftMedian + histArray(coder.internal.indexPlus(localMedian,1)+Bias);

% Iterate till median is found 
if pixelCount < round(midSize)
    % Case: New median greater than previous median
    % Iterate to right-side in Histogram.
    leftMedian = pixelCount;
    while leftMedian < round(midSize)
        localMedian = localMedian + 1;
        leftMedian = leftMedian + histArray(coder.internal.indexPlus(localMedian,1)+Bias);
    end
    leftMedian = leftMedian - histArray(coder.internal.indexPlus(localMedian,1)+Bias);
elseif leftMedian > round(midSize) - 1
    % Case: New median less than previous median
    % Iterate to left-side in Histogram.
    while leftMedian > round(midSize) - 1
        localMedian = localMedian - 1;
        leftMedian = leftMedian - histArray(coder.internal.indexPlus(localMedian,1)+Bias);
    end
end


function out = median9(vec9)
% This function finds the median of a 9 elements vector using sorting networks.
vec9=pixelSort(vec9,2,3);
vec9=pixelSort(vec9,5,6);
vec9=pixelSort(vec9,8,9);
vec9=pixelSort(vec9,1,2);
vec9=pixelSort(vec9,4,5);
vec9=pixelSort(vec9,7,8);

vec9=pixelSort(vec9,2,3);
vec9=pixelSort(vec9,5,6);
vec9=pixelSort(vec9,8,9);
vec9=pixelSort(vec9,1,4);
vec9=pixelSort(vec9,6,9);
vec9=pixelSort(vec9,5,8);

vec9=pixelSort(vec9,4,7);
vec9=pixelSort(vec9,2,5);
vec9=pixelSort(vec9,3,6);
vec9=pixelSort(vec9,5,8);
vec9=pixelSort(vec9,5,3);
vec9=pixelSort(vec9,7,5);
vec9=pixelSort(vec9,5,3);

out=vec9(5);

function out = median25(vec)
% This function finds the median of a 25 elements vector using sorting networks.
vec=pixelSort(vec,1,2);vec=pixelSort(vec,4,5);vec=pixelSort(vec,3,5);
vec=pixelSort(vec,3,4);vec=pixelSort(vec,7,8);vec=pixelSort(vec,6,8);
vec=pixelSort(vec,6,7);vec=pixelSort(vec,10,11);vec=pixelSort(vec,9,11);

vec=pixelSort(vec,9,10);vec=pixelSort(vec,13,14);vec=pixelSort(vec,12,14);
vec=pixelSort(vec,12,13);vec=pixelSort(vec,16,17);vec=pixelSort(vec,15,17);
vec=pixelSort(vec,15,16);vec=pixelSort(vec,19,20);vec=pixelSort(vec,18,20);

vec=pixelSort(vec,18,19);vec=pixelSort(vec,22,23);vec=pixelSort(vec,21,23);
vec=pixelSort(vec,21,22);vec=pixelSort(vec,24,25);vec=pixelSort(vec,3,6);
vec=pixelSort(vec,4,7);vec=pixelSort(vec,1,7);vec=pixelSort(vec,1,4);

vec=pixelSort(vec,5,8);vec=pixelSort(vec,2,8);vec=pixelSort(vec,2,5);
vec=pixelSort(vec,12,15);vec=pixelSort(vec,9,15);vec=pixelSort(vec,9,12);
vec=pixelSort(vec,13,16);vec=pixelSort(vec,10,16);vec=pixelSort(vec,10,13);

vec=pixelSort(vec,14,17);vec=pixelSort(vec,11,17);vec=pixelSort(vec,11,14);
vec=pixelSort(vec,21,24);vec=pixelSort(vec,18,24);vec=pixelSort(vec,18,21);
vec=pixelSort(vec,22,25);vec=pixelSort(vec,19,25);vec=pixelSort(vec,19,22);

vec=pixelSort(vec,20,23);vec=pixelSort(vec,9,18);vec=pixelSort(vec,10,19);
vec=pixelSort(vec,1,19);vec=pixelSort(vec,1,10);vec=pixelSort(vec,11,20);
vec=pixelSort(vec,2,20);vec=pixelSort(vec,2,11);vec=pixelSort(vec,12,21);

vec=pixelSort(vec,3,21);vec=pixelSort(vec,3,12);vec=pixelSort(vec,13,22);
vec=pixelSort(vec,4,22);vec=pixelSort(vec,4,13);vec=pixelSort(vec,14,23);
vec=pixelSort(vec,5,23);vec=pixelSort(vec,5,14);vec=pixelSort(vec,15,24);

vec=pixelSort(vec,6,24);vec=pixelSort(vec,6,15);vec=pixelSort(vec,16,25);
vec=pixelSort(vec,7,25);vec=pixelSort(vec,7,16);vec=pixelSort(vec,8,17);
vec=pixelSort(vec,8,20);vec=pixelSort(vec,14,22);vec=pixelSort(vec,16,24);

vec=pixelSort(vec,8,14);vec=pixelSort(vec,8,16);vec=pixelSort(vec,2,10);
vec=pixelSort(vec,4,12);vec=pixelSort(vec,6,18);vec=pixelSort(vec,12,18);
vec=pixelSort(vec,10,18);vec=pixelSort(vec,5,11);vec=pixelSort(vec,7,13);

vec=pixelSort(vec,8,15);vec=pixelSort(vec,5,7);vec=pixelSort(vec,5,8);
vec=pixelSort(vec,13,15);vec=pixelSort(vec,11,15);vec=pixelSort(vec,7,8);
vec=pixelSort(vec,11,13);vec=pixelSort(vec,7,11);vec=pixelSort(vec,7,18);

vec=pixelSort(vec,13,18);vec=pixelSort(vec,8,18);vec=pixelSort(vec,8,11);
vec=pixelSort(vec,13,19);vec=pixelSort(vec,8,13);vec=pixelSort(vec,11,19);
vec=pixelSort(vec,13,21);vec=pixelSort(vec,11,21);vec=pixelSort(vec,11,13);

out= vec(13);

function vec = pixelSort(vec,i,j)
coder.inline('always');
if (vec(i)>vec(j))
    temp=vec(i); vec(i)=vec(j); vec(j)=temp;
end
