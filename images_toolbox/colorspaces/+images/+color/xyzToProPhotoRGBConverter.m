function xyzToRGBConverter = xyzToProPhotoRGBConverter(wp)
% XYZTOPROPHOTORGB Color converter from CIE 1931 XYZ to ProPhoto RGB
%
%    See also images.color.ColorConverter

%    Copyright 2022 The MathWorks, Inc.

    d50WP = whitepoint("d50");
    if nargin < 1
        wp = d50WP;
    else
        wp = images.color.internal.checkWhitePoint(wp);
    end
    
    xyzToRGBConverter = getBasicConverter();

    if ~isequal(wp, d50WP)
        % Add a chromatic adaptation step
        f = @(in) images.color.adaptXYZ(in, wp, d50WP);
        d50chromAdaptConverter = images.color.ColorConverter(f);
        d50chromAdaptConverter.Description = getString(message('images:color:adaptXYZValues'));
        d50chromAdaptConverter.InputSpace = 'XYZ';
        d50chromAdaptConverter.OutputSpace = 'XYZ';
        d50chromAdaptConverter.NumInputComponents = 3;
        d50chromAdaptConverter.NumOutputComponents = 3;
        d50chromAdaptConverter.InputEncoder = images.color.XYZEncoder;
        d50chromAdaptConverter.OutputEncoder = images.color.XYZEncoder;
        
        fullConverter = images.color.ColorConverter({d50chromAdaptConverter, xyzToRGBConverter});

        % The properties of the converter need to be specified to ensure
        % the appropriate transformations are performed.
        fullConverter.InputSpace = d50chromAdaptConverter.InputSpace;
        fullConverter.OutputSpace = xyzToRGBConverter.OutputSpace;
        fullConverter.OutputType = xyzToRGBConverter.OutputType;
        fullConverter.InputEncoder = d50chromAdaptConverter.InputEncoder;
        fullConverter.OutputEncoder = xyzToRGBConverter.OutputEncoder;
        fullConverter.Description = xyzToRGBConverter.Description;

        xyzToRGBConverter = fullConverter;
    end
end

function converter = getBasicConverter()
% Steps involved in performing the conversion from XYZ to ProPhoto RGB.
% 1: Apply transformation to convert from XYZ to linear RGB
% 2: Apply transfer function on linear RGB values. This is done by the
%    ProPhotoRGBEncoder specified in the OutputEncoder

    % Function for converting XYZ tristimulous values to linear
    % RGB tristimulous values.
    M = images.color.internal.proPhotoRGBToXYZTransform();
    M = M';
    
    g = @(in) in / M;
    converter = images.color.ColorConverter(g);
    converter.Description = getString(message('images:color:convertXYZToProPhotoRGB'));
    converter.InputSpace = 'XYZ';
    converter.OutputSpace = 'RGB';
    converter.NumInputComponents = 3;
    converter.NumOutputComponents = 3;
    % Indicates that output type is double for all non-single inputs and
    % single for single-type inputs.
    converter.OutputType = 'float';
    converter.InputEncoder = images.color.XYZEncoder;
    converter.OutputEncoder = images.color.ProPhotoRGBEncoder;
end
