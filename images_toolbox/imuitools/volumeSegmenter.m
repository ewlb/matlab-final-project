function volumeSegmenter(varargin)
%volumeSegmenter Segment 3-D grayscale or RGB volumetric images.
%   volumeSegmenter opens a volume segmentation app. The app can be used to
%   create and refine a binary or semantic segmentation mask for a 3-D
%   grayscale or an RGB image using automated, semi-automated, and manual
%   techniques.
%
%   volumeSegmenter(V) loads the volume V into a volume segmentation app.
%
%   volumeSegmenter(V, L) loads the volume V and labeled volume L into a
%   volume segmentation app.
%
%   volumeSegmenter(____, Name, Value) loads the app using Name/Value
%   pairs.
%
%   Parameters include:
%
%   'Show3DDisplay'     Logical scalar value indicating if the 3-D volume
%                       visualization will be displayed in the app. The
%                       default value is true; however, this display is not
%                       supported for Linux platforms or Windows platforms
%                       using software versions of OpenGL. For cases where
%                       the 3-D display is not supported, the default value
%                       for this parameter is false.
%
%   Class Support
%   -------------
%   Volume V is a scalar valued MxNxP or MxNxPx3 image of class uint8,
%   uint16, uint32, int8, int16, int32, single, or double.
%
%   Labeled Volume L is a scalar valued MxNxP image of class logical,
%   categorical, uint8, uint16, uint32, int8, int16, int32, single, or
%   double.
%
%   See also imageSegmenter, volumeViewer

%   Copyright 2020 The MathWorks, Inc.

images.internal.app.segmenter.volume.VolumeSegmenter(varargin{:});

end