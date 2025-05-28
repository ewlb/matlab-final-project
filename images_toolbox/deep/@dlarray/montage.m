function varargout = montage(varargin)

    dl = varargin{1};

    im = validateAndExtractData(dl);

    if nargout == 1
        varargout{1} = montage(im, varargin{2:end});
    else
        montage(im, varargin{2:end});
    end
end

function im = validateAndExtractData(dl)
    if dims(dl) == ""
        % If dimensions are not labeled, treat the dlarray as a multiframe
        % image array.
        im = extractdata(dl);
        return;
    end

    numSpatialDims = numel(finddim(dl, "S"));
    if isempty(numSpatialDims) || (numSpatialDims ~= 2)
        error(message("deep:dlarray:ExactlyTwoSpatialDims"));
    end

    chanDimIdx = finddim(dl, "C");
    if ~isempty(chanDimIdx)
        numChannels = size(dl, chanDimIdx);
        if ~ismember(numChannels, [1 3])
            error(message("deep:dlarray:MustHave1or3Channels"));
        end
        % The 4th dimension must be either B, T or U
        batchableDimIdx = 4;
    else
        numChannels = 1;
        % The 3rd dimension must be B, T or U
        batchableDimIdx = 3;
    end

    checkBTU = [ ~isempty(finddim(dl, "B")) ~isempty(finddim(dl, "T")) ...
                 ~isempty(finddim(dl, "U")) ];

    if numel(find(checkBTU)) >= 2
        error(message("deep:dlarray:ExactlyOneBatchableDim"));
    end

    % DLARRAY's without "C" are implicitly assumed to have 1 channel. The
    % data array has dimensions M x N x F. This needs to be converted to
    % M x N x 1 x F.
    newDataDims = [size(dl, [1 2]) numChannels size(dl, batchableDimIdx)];

    % Gather data if present on the GPU before display
    im = reshape(gather(extractdata(dl)), newDataDims);

    % At this point, IM has the shape MxNxCxF (where F is the batchable
    % dimension that can be B, T or U).
    % If IM is MxNx3 at this point, the third dimension can only refer to
    % the number of channels. This is based on the parsing logic until this
    % point.
    % MONTAGE treats MxNx3 array as a stack of 3 grayscale images. However,
    % we want it to be treated as one RGB image.
    if (ndims(im) == 3) && size(im, 3) == 3
        im = {im};
    end
end

%   Copyright 2023-2024 The MathWorks, Inc.