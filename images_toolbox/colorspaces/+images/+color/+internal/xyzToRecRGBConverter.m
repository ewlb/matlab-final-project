function converter = xyzToRecRGBConverter(recType, wp)
%Helper function that creates the converter to convert XYZ into RGB in
%BT.2020 or BT.2100 colorspace 

%   Copyright 2020, The MathWorks Inc.

    wp_d65 = whitepoint('d65');
    if nargin < 2
        wp = wp_d65;
    else
        wp = images.color.internal.checkWhitePoint(wp);
    end

    xyz2recRGB_converter = getBasicConverter(recType);

    if ~isequal(wp, wp_d65)
        % Add a chromatic adaptation step
        f = @(in) images.color.adaptXYZ(in,wp,wp_d65);
        adapt_converter = images.color.ColorConverter(f);
        adapt_converter.Description = getString(message('images:color:adaptXYZValues'));
        adapt_converter.InputSpace = 'XYZ';
        adapt_converter.OutputSpace = 'XYZ';
        adapt_converter.NumInputComponents = 3;
        adapt_converter.NumOutputComponents = 3;
        adapt_converter.InputEncoder = images.color.XYZEncoder;
        adapt_converter.OutputEncoder = images.color.XYZEncoder;

        converter = images.color.ColorConverter({adapt_converter,xyz2recRGB_converter});
        converter.InputSpace = adapt_converter.InputSpace;
        converter.OutputSpace = xyz2recRGB_converter.OutputSpace;
        converter.OutputType = xyz2recRGB_converter.OutputType;
        converter.InputEncoder = adapt_converter.InputEncoder;
        converter.OutputEncoder = xyz2recRGB_converter.OutputEncoder;
        converter.Description = adapt_converter.Description;
    else
        converter = xyz2recRGB_converter;
    end
end


function converter = getBasicConverter(recType)
% Steps involved in performing the conversion from XYZ to RGB
% 1: Apply transformation to convert to linear RGB. 
% 2: Delinearize data. The transfer function coefficients vary based on the
%    bitDepth.
% 3: Add the black-level offset depending upon the bit-depth.

    % Function for converting XYZ tristimulous values to BT.2020 RGB
    % values. BT.2100 uses the same color primaries and white-point as
    % BT.2020. So the same matrix applies.
    M = images.color.internal.bt2020RGBToXYZTransform();
    M = M';
    M = M \ eye(3);

    g = @(in) in * M;    
    converter = images.color.ColorConverter(g);
    converter.Description = getString(message('images:color:convertXYZToBT2020RGB'));
    converter.InputSpace = 'XYZ';
    converter.OutputSpace = 'RGB';
    converter.NumInputComponents = 3;
    converter.NumOutputComponents = 3;
    converter.InputEncoder = images.color.XYZEncoder;
    if strcmpi(recType, 'BT.2020')
        converter.Description = getString(message('images:color:convertXYZToBT2020RGB'));
        % Output Encoder performs steps (2) and (3)
        converter.OutputEncoder = images.color.BT2020RGBEncoder;
    elseif strcmpi(recType, 'BT.2100')
        converter.Description = getString(message('images:color:convertXYZToBT2100RGB'));
        % Output Encoder performs steps (2) and (3)
        converter.OutputEncoder = images.color.BT2100RGBEncoder;
    else
        assert(false, 'Invalid Colorspace');
    end
    converter.OutputType = 'uint16';
end
