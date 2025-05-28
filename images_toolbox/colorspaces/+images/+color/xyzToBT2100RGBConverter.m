function converter = xyzToBT2100RGBConverter(varargin)
%xyzToBT2100RGBConverter Color converter from CIE 1931 XYZ to BT.2100 RGB
%
%   converter = images.color.xyzToBT2100RGBConverter
%
%   converter = images.color.xyzToBT2100RGBConverter returns a color
%   converter that converts CIE 1931 XYZ color values to BT.2100 RGB color
%   value.
%
%   converter = images.color.xyzToBT2100RGBConverter(wp) returns
%   a color converter that adapts to the specified reference white point.
%
%   See also images.color.ColorConverter

%   Copyright 2020 The MathWorks, Inc.

    converter = images.color.internal.xyzToRecRGBConverter('BT.2100', varargin{:});
end
