function converter = bt2100RGBToXYZConverter(varargin)
% bt2100RGBToXYZConverter Color converter from BT.2100 RGB to CIE 1931
% XYZ 
%
%    converter = images.color.bt2100RGBToXYZConverter
%    converter = images.color.bt2100RGBToXYZConverter(wp)
%
%    converter = images.color.bt2100RGBToXYZConverter returns a color
%    converter that converts BT.2100 RGB color values to CIE 1931 XYZ
%    color values. 

%    converter = images.color.bt2100RGBToXYZConverter(wp) returns a color
%    converter that adapts to the specified reference white point. 
%    
%    See also images.color.ColorConverter

%    Copyright 2020 The MathWorks, Inc.

    converter = images.color.internal.recRGBToXYZConverter('BT.2100', varargin{:});
end
