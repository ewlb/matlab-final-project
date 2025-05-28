classdef ProPhotoRGBEncoder < images.color.ColorEncoder
    % ProPhotoRGBEncoder Codec for ProPhoto RGB values

    % Copyright 2022 The MathWorks, Inc.

    properties (Constant)
        % Functions that apply the transfer function to convert linear RGB
        % values corrected RGB values.
        EncoderFunctionTable = struct( ...
            'uint8', @(x) images.color.ProPhotoRGBEncoder.lin2rgb(x, intmax("uint8")), ...
            'uint16', @(x) images.color.ProPhotoRGBEncoder.lin2rgb(x, intmax("uint16")), ...
            'single', @(x) images.color.ProPhotoRGBEncoder.lin2rgb(x, single(1)), ...
            'double', @(x) images.color.ProPhotoRGBEncoder.lin2rgb(x, 1) )

        % Functions that linearize the input RGB values
        DecoderFunctionTable = struct( ...
            'uint8', @(x) images.color.ProPhotoRGBEncoder.rgb2lin(double(x) / double(intmax("uint8")), 1/512), ...
            'uint16', @(x) images.color.ProPhotoRGBEncoder.rgb2lin(double(x) / double(intmax("uint16")), 1/512), ...
            'single', @(x) images.color.ProPhotoRGBEncoder.rgb2lin(x, single(1/512)), ...
            'double', @(x) images.color.ProPhotoRGBEncoder.rgb2lin(x, 1/512) )
    end
    
    methods(Access=public, Static)
        function outval = lin2rgb(inval, outValRange)
            % Function that applies transfer function to convert linear RGB
            % values into corrected ProPhoto RGB values.
            % The transfer function equation can be found at:
            % https://en.wikipedia.org/wiki/ProPhoto_RGB_color_space#Encoding_function

            inClass = class(inval);
            outClass = class(outValRange);
            Et = cast(1/512, inClass);
            outValRange = cast(outValRange, inClass);

            outval = inval;

            % The Transfer function in the spec clips the values outside
            % the range (0, 1). However, this code is not going to do so to
            % ensure that users can work with out-of-gamut colors.
            idx = find(inval<Et);
            outval(idx) = inval(idx)*16;

            idx = find(Et<=inval);
            outval(idx) = inval(idx).^(1/1.8);

            outval = cast(outval*outValRange, outClass);
        end

        function outval = rgb2lin(inval, Et)
            % Function that linearizes the ProPhoto RGB values by undoing
            % the impact of the applied Transfer Function.
            % The transfer function equation can be found at:
            % https://en.wikipedia.org/wiki/ProPhoto_RGB_color_space#Encoding_function

            kneePoint = 16*Et;

            outval = inval;

            % The Transfer function in the spec clips the values outside
            % the range (0, 1). However, this code is not going to do so to
            % ensure that users can work with out-of-gamut colors.
            idx = find(inval <= kneePoint);
            outval(idx) = inval(idx) / 16;

            idx = find(kneePoint <= inval);
            outval(idx) = inval(idx).^1.8;
        end
    end
end
