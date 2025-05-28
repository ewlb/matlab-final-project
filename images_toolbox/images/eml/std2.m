function s = std2(a) %#codegen
%STD2 Standard deviation of matrix elements.

%   Copyright 2023 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(a);

% validate that our input is valid for the IMHIST optimization
fastDataType = isa(a,'logical') || isa(a,'int8') || isa(a,'uint8') || ...
    isa(a,'uint16') || isa(a,'int16');

% only use IMHIST for images of sufficient size

if (isa(a,'logical') && numel(a) > 2e4) ||...
        ((isa(a,'int8') || isa(a,'uint8')) && numel(a) > 2e5) ||...
        (isa(a,'uint16') && numel(a) > 5e5) ||...
        (isa(a,'int16') && numel(a) > 4e5)
    bigEnough = true;
else
    bigEnough = false;
end

if fastDataType && ~issparse(a) && bigEnough == true

    % compute histogram
    if islogical(a)
        numBins = 2;
    else
        dataType = class(a);
        numBins = double(intmax(dataType)) - double(intmin(dataType)) + 1;
    end
    [binCountsTemp, binValues] = imhist(a, numBins);
    binCounts = binCountsTemp(:);

    % compute standard deviation

    totalPixels = numel(a);
    binPdt = binCounts .* binValues;
    sumPixels = sum(binPdt);
    meanPixel = sumPixels / totalPixels;

    binValueOffsets      = binValues - meanPixel;
    binValueOffsetsSqrd = binValueOffsets .^ 2;

    binCPdt = binCounts .* binValueOffsetsSqrd;
    offsetSummation = sum(binCPdt);
    s = sqrt(offsetSummation / totalPixels);

else

    % use simple implementation
    if ~isa(a,'single')
        aNewDataType = double(a);
    else
        aNewDataType = a;
    end
    s = std(aNewDataType(:));

end