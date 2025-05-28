function localizedValue = localizePN(byteStream, specificCharacterSet)
%

% Copyright 2015-2023 The MathWorks, Inc.

splitRawData = tokenizeRawData(byteStream, '\');

localizedValue = '';
for p = 1:numel(splitRawData)
    if (hasMultiplePNComponents(splitRawData{p}))
        unicodeString = convertMultipleComponentsToUnicode(splitRawData{p}, ...
            specificCharacterSet);
    else
        unicodeString = getUnicodeStringFromBytes(splitRawData{p}, ...
            specificCharacterSet{1});
    end
    
    unicodeString = images.internal.dicom.deblankAndStripNulls(unicodeString);
    localizedValue = [localizedValue unicodeString]; %#ok<AGROW>
end

end


function unicodeString = getUnicodeStringFromBytes(byteStream, originalCharacterSet)

icuCharacterSet = images.internal.dicom.getConverterString(originalCharacterSet);

% Remove a particular control code sequence ICU doesn't handle well.
byteStream = uint8(strrep(char(byteStream), char([27 36 41 67]), ''));
unicodeString = native2unicode(byteStream, icuCharacterSet);

end


function TF = hasMultiplePNComponents(rawData)

if (~isempty(rawData))
    TF = ~isempty(find(rawData == '=', 1));
else
    TF = false;
end
end


function unicodeString = convertMultipleComponentsToUnicode(rawData, specificCharacterSet)

unicodeString = '';

% Components are divided by equal signs ('='). Only the first of these is
% guaranteed to be an actual delimiter. The others could be an equivalent
% value in a multibyte character.
separatorIndices = find(rawData == uint8('='));

% First "alphabetic" component
start = 1;
stop = max(separatorIndices(1) - 1, 1);
substring = rawData(start:stop);
if ~isempty(substring)
    substring = getUnicodeStringFromBytes(substring, specificCharacterSet{1});
    unicodeString = [unicodeString '=' substring];
end

% Subsequent (possibly multi-byte) ideographic and phonetic components 
start = stop + 2;

substring = rawData(start:end);
substring = getUnicodeStringFromBytes(substring, specificCharacterSet{end});
unicodeString = [unicodeString '=' substring];
unicodeString(1) = '';  % Remove leading '='

end


function splitRawData = tokenizeRawData(rawData, delimiter)

if isempty(rawData)
    splitRawData = {};
    return
end

delimiterLocations = find(rawData == uint8(delimiter));

if isempty(delimiterLocations)
    splitRawData = {rawData};
    return
end

splitRawData = cell(1, numel(delimiterLocations) + 1);

start = 1;
for p = 1:numel(delimiterLocations)
    stop = delimiterLocations(p) - 1;
    if (stop >= start)
        splitRawData{p} = rawData(start:stop);
    end
    start = stop + 2;
end

splitRawData{end} = rawData(start:end);

end
