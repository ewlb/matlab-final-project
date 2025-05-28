function rgbToXYZConverter = proPhotoRGBToXYZConverter(wp)

%   Copyright 2022 The MathWorks Inc.

    d50WP = whitepoint("d50");
    if nargin < 1
        wp = d50WP;
    else
        wp = images.color.internal.checkWhitePoint(wp);
    end
    
    rgbToXYZConverter = getBasicConverter();
    
    if ~isequal(wp, d50WP)
        % Add a chromatic adaptation step
        f = @(in) images.color.adaptXYZ(in,d50WP,wp);
        d50chromAdaptConverter = images.color.ColorConverter(f);
        d50chromAdaptConverter.Description = getString(message('images:color:adaptXYZValues'));
        d50chromAdaptConverter.InputSpace = 'XYZ';
        d50chromAdaptConverter.OutputSpace = 'XYZ';
        d50chromAdaptConverter.NumInputComponents = 3;
        d50chromAdaptConverter.NumOutputComponents = 3;
        d50chromAdaptConverter.InputEncoder = images.color.XYZEncoder;
        d50chromAdaptConverter.OutputEncoder = images.color.XYZEncoder;
        
        fullConverter = images.color.ColorConverter({rgbToXYZConverter, d50chromAdaptConverter});
        % The properties of converter need to be setup to ensure the
        % suitable conversions are performed.
        fullConverter.InputSpace = rgbToXYZConverter.InputSpace;
        fullConverter.OutputSpace = d50chromAdaptConverter.OutputSpace;
        fullConverter.OutputType = d50chromAdaptConverter.OutputType;
        fullConverter.InputEncoder = rgbToXYZConverter.InputEncoder;
        fullConverter.OutputEncoder = d50chromAdaptConverter.OutputEncoder;
        fullConverter.Description = rgbToXYZConverter.Description;

        rgbToXYZConverter = fullConverter;
    end
end

function converter = getBasicConverter()
% Steps involved in performing the conversion from ProPhoto RGB to XYZ
% 1: Linearize data based on the Transfer function. This is done by the
%    ProPhotoRGBEncoder specified as the InputEncoder of the converter.
% 2: Apply transformation to XYZ

    % Function for converting linear RGB tristimulous values to XYZ
    % tristimulous values.
    M = images.color.internal.proPhotoRGBToXYZTransform();
    M = M';
    
    g = @(in) in * M;
    converter = images.color.ColorConverter(g);
    converter.Description = getString(message('images:color:convertProPhotoRGBToXYZ'));
    converter.InputSpace = 'RGB';
    converter.OutputSpace = 'XYZ';
    % Indicates output type is "double" for all non-single inputs and
    % "single" for single valued inputs
    converter.OutputType = 'float';

    % Convert the resulting XYZ values into the desired datatype.
    converter.OutputEncoder = images.color.XYZEncoder();

    % Linearize the input RGB values based on the transfer function.
    % This needs to handle RGB inputs in different datatypes.
    converter.InputEncoder = images.color.ProPhotoRGBEncoder();
end
