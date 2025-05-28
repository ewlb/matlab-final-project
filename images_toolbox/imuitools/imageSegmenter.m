function imageSegmenter(varargin)
%imageSegmenter Segment 2D grayscale or RGB image.
%   imageSegmenter opens an image segmentation app. The app can be used to
%   create and refine a segmentation mask to a 2D grayscale or RGB image
%   using techniques like thresholding, flood-filling, active contours,
%   graph cuts and morphological processing.
%
%   imageSegmenter(I) loads the grayscale or RGB image I into an image
%   segmentation app.
%
%   imageSegmenter CLOSE closes all open image segmentation apps.
%
%   Class Support
%   -------------
%   I is an image of class uint8, int16 (grayscale only), uint16, single,
%   or double.
%
%   See also imbinarize, activecontour, grayconnected, lazysnapping,
%   grabcut, imfindcircles.

%   Copyright 2014-2023 The MathWorks, Inc.

import matlab.internal.capability.Capability;

narginchk(0,1);

if nargin == 0
    % Create a new Image Segmentation app.

    images.internal.app.segmenter.image.web.ImageSegmentationTool();
    return;

else

    I = matlab.images.internal.stringToChar(varargin{1});
    if ischar(I)
        % Handle the 'close' request
        validatestring(I, {'close'}, mfilename);
        images.internal.app.segmenter.image.web.ImageSegmentationTool.deleteAllTools();
    else
        supportedImageClasses    = {'uint8','int16','uint16','single','double'};
        supportedImageAttributes = {'real','nonsparse','nonempty'};
        validateattributes(I,supportedImageClasses,supportedImageAttributes,mfilename,'I');

        % If image is RGB, issue warning and convert to grayscale.
        isRGB = ndims(I)==3 && size(I,3)==3;
        if ~isRGB && ~ismatrix(I)
            % If image is not 2D grayscale or RGB, error.
            error(message('images:imageSegmenter:expectedGray'));
        end

        if isa(I,'int16') && isRGB
            error(message('images:imageSegmenter:nonGrayErrorDlgMessage'));
        end

        images.internal.app.segmenter.image.web.ImageSegmentationTool(I,isRGB,inputname(1));

    end

end

end
