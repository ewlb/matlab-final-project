function converter = recRGBToXYZConverter(recType, wp)
%Helper function that creates the converter to convert RGB in BT.2020 or
%BT.2100 colorspace into XYZ

%   Copyright 2020, The MathWorks Inc.

    wp_d65 = whitepoint('d65');
    if nargin < 2
        wp = wp_d65;
    else
        wp = images.color.internal.checkWhitePoint(wp);
    end
    
    color_converter = getBasicConverter(recType);

    if ~isequal(wp, wp_d65)
        % Add a chromatic adaptation step
        f = @(in) images.color.adaptXYZ(in, wp_d65, wp);
        adapt_converter = images.color.ColorConverter(f);
        adapt_converter.Description = getString(message('images:color:adobeRGBToXYZConverterDescription'));
        adapt_converter.InputSpace = 'XYZ';
        adapt_converter.OutputSpace = 'XYZ';
        adapt_converter.NumInputComponents = 3;
        adapt_converter.NumOutputComponents = 3;
        adapt_converter.OutputType = color_converter.OutputType;
        adapt_converter.InputEncoder = images.color.XYZEncoder;
        adapt_converter.OutputEncoder = images.color.XYZEncoder;

        converter = images.color.ColorConverter({color_converter, adapt_converter});
        converter.InputSpace = color_converter.InputSpace;
        converter.OutputSpace = adapt_converter.OutputSpace;
        converter.OutputType = adapt_converter.OutputType;
        converter.InputEncoder = color_converter.InputEncoder;
        converter.OutputEncoder = adapt_converter.OutputEncoder;
        converter.Description = color_converter.Description;
    else
        converter = color_converter;
    end
end

function converter = getBasicConverter(recType)
% Steps involved in performing the conversion from RGB to XYZ
% 1: Remove black-level offset and scale data to the nominal range.
% 2: Linearize data. The transfer function coefficients vary based on the
%    bitDepth.
% 3: Apply transformation to XYZ

    % Function for computing linear RGB tristimulous values to XYZ
    % tristimulous values.
    % BT.2100 and BT.2020 make use of the same color primaries and
    % white-point. Hence the RGB -> XYZ transformation matrix will be the
    % same.
    M = images.color.internal.bt2020RGBToXYZTransform();
    M = M';

    g = @(in) in * M;
    converter = images.color.ColorConverter(g);
    converter.Description = getString(message('images:color:convertBT2100RGBToXYZ'));
    converter.InputSpace = 'RGB';
    converter.OutputSpace = 'XYZ';
    converter.NumInputComponents = 3;
    converter.NumOutputComponents = 3;
    if strcmpi(recType, 'BT.2020')
        converter.Description = getString(message('images:color:convertBT2020RGBToXYZ'));
        % InputEncoder performs Steps (1) and (2)
        converter.InputEncoder = images.color.BT2020RGBEncoder;
    elseif strcmpi(recType, 'BT.2100')
        converter.Description = getString(message('images:color:convertBT2100RGBToXYZ'));
        % InputEncoder performs Steps (1) and (2)
        converter.InputEncoder = images.color.BT2100RGBEncoder;
    else
        assert(false, 'Invalid Colorspace');
    end
    
    converter.OutputEncoder = images.color.XYZEncoder;
    converter.OutputType = 'double';
end