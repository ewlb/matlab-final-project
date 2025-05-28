classdef BT2020RGBEncoder < images.color.ColorEncoder
    % BT2020RGBEncoder Codec or BT.2020 RGB values

    % Copyright 2020 The MathWorks, Inc,

    properties (Constant)
        EncoderFunctionTable = struct( ...
            'uint8', @notImplemented, ...
            'uint16', @convertToUint16, ...
            'single', @notImplemented, ...
            'double', @notImplemented)

        DecoderFunctionTable = struct( ...
            'uint8', @notimplemented, ...
            'uint16', @convertFromUint16, ...
            'single', @notimplemented, ...
            'double', @notimplemented)
    end
    
    methods(Access=public, Static)
        function outval = lin2rgb(inval, bitDepth)
        % Function implements the transfer function. The input and output
        % are both of double type. 
            [alpha, beta] = getParamsForBitDepth(bitDepth);
            
            outval = inval;
    
            locs = inval < beta;
            outval(locs) = 4.5*inval(locs);

            locs = inval >= beta;
            outval(locs) = alpha*exp( 0.45*log(inval(locs)) ) - (alpha - 1);
        end
        
        function outval = rgb2lin(inval, bitDepth)
        % Function implements the inverse transfer function. The input and
        % output are both of double type.
            [alpha, beta] = getParamsForBitDepth(bitDepth);
            
            outval = inval;
            locs = inval < 4.5*beta;
            outval(locs) = (1/4.5)*inval(locs);

            locs = inval >= 4.5*beta;
            outval(locs) = exp( (1/0.45)*log( (1/alpha)*(inval(locs)-1) + 1 ) );
        end
    end
end


function out = notImplemented(~) %#ok<STOUT>
    assert(false,'Encoder function is not implemented for BT.2020 RGB Encoder.')
end


function out = convertToUint16(in, bitDepth)
% Function that accepts a linear input signal and converts it into the
% scaled and offset uint16 output. This input signal can be R, G, B color
% channels, Y and constant luminance Yc. The input has be of double type.
    outlocal = images.color.BT2020RGBEncoder.lin2rgb(in, bitDepth);
    
    [~, ~, blackLevel, nominalPeak] = getParamsForBitDepth(bitDepth);
    nominalRange = nominalPeak - blackLevel;
    
    outlocal = outlocal*nominalRange;
    
    out = uint16(outlocal + blackLevel);
end


function out = convertFromUint16(in, bitDepth)
% Function that accepts a non-linear input signal and it converts it into a
% linear output after compensating for bias ans scale. This input signal
% can be R, G, B color channels, Y and constant luminance Yc. The input has
% be of uint16 type. 
    [~, ~, blackLevel, nominalPeak] = getParamsForBitDepth(bitDepth);
    
    nominalRange = nominalPeak - blackLevel;
    inlocal = (double(in) - blackLevel) / nominalRange;
    
    out = images.color.BT2020RGBEncoder.rgb2lin(inlocal, bitDepth);
end

function [alpha, beta, blackLevel, nominalPeak] = getParamsForBitDepth(bitDepth)    
    switch(bitDepth)
        case 10
            blackLevel = 64;
            nominalPeak = 940;
            alpha = 1.099; beta = 0.018;
        case 12
            blackLevel = 256;
            nominalPeak = 3760;
            alpha = 1.0993; beta = 0.0181;
        otherwise
            assert(false, "Unsupported bit depth");
    end
end

