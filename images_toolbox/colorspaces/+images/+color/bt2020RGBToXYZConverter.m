function converter = bt2020RGBToXYZConverter(varargin)
% bt2020RGBToXYZConverter Color converter from BT.2020 RGB to CIE 1931
% XYZ 
%
%    converter = images.color.bt2020RGBToXYZConverter
%    converter = images.color.bt2020RGBToXYZConverter(wp)
%
%    converter = images.color.bt2020RGBToXYZConverter returns a color
%    converter that converts BT.2020 RGB color values to CIE 1931 XYZ
%    color values. 

%    converter = images.color.bt2020RGBToXYZConverter(wp) returns a color
%    converter that adapts to the specified reference white point. 
%    
%    See also images.color.ColorConverter

%    Copyright 2020 The MathWorks, Inc.

    converter = images.color.internal.recRGBToXYZConverter('BT.2020', varargin{:});
end
