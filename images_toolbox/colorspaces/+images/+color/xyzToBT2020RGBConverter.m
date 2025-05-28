function converter = xyzToBT2020RGBConverter(varargin)
%xyzToBT2020RGBConverter Color converter from CIE 1931 XYZ to BT.2020 RGB
%
%   converter = images.color.xyzToBT2020RGBConverter
%
%   converter = images.color.xyzToBT2020RGBConverter returns a color
%   converter that converts CIE 1931 XYZ color values to BT.2020 RGB color
%   value.
%
%   converter = images.color.xyzToLinearRGBConverter(wp) returns
%   a color converter that adapts to the specified reference white point.
%
%   See also images.color.ColorConverter

%   Copyright 2020 The MathWorks, Inc.

    converter = images.color.internal.xyzToRecRGBConverter('BT.2020', varargin{:});
end
