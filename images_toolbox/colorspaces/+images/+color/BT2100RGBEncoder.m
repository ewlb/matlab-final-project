classdef BT2100RGBEncoder < images.color.ColorEncoder
    % BT2100RGBEncoder Codec or BT.2100 RGB values

    % Copyright 2020 The MathWorks, Inc.

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
        function outval = lin2rgbPQ(inval)
        % Function implements the PQ transfer function. The input and
        % output are both of double type. 
            outval = inval;

            thresh= 0.018;
            locs = inval < thresh;
            outval(locs) = inval(locs)*4.500;

            locs = inval >= thresh;
            outval(locs) = 1.099*(inval(locs).^(0.45)) - 0.099;
        end

        function outval = lin2rgbHLG(inval)
        % Function implements the HLG transfer function. The input and
        % output are both of double type. 
            outval = inval;

            a = 0.17883277;
            b = 1 - 4*a;
            c = 0.5 - a*log(4*a);
            thresh = 1/12;
            
            locs = inval <= thresh;
            outval(locs) = sqrt(3*inval(locs));

            locs = inval > thresh;
            outval(locs) = a*log(12*inval(locs) - b) + c;
        end 
        
        function outval = rgb2linPQ(inval)
        % Function implements the PQ inverse transfer function. The input
        % and output are both of double type.
            outval = inval;

            thresh = 0.0810;
            locs = inval < thresh;
            outval(locs) = inval(locs) / 4.500;

            locs = inval >= thresh;
            outval(locs) = exp( (1 / 0.45)*log( ( inval(locs) + 0.099 ) / 1.099 ) );
        end

        function outval = rgb2linHLG(inval)
        % Function implements the HLG inverse transfer function. The input
        % and output are both of double type.
            outval = inval;

            a = 0.17883277;
            b = 1 - 4*a;
            c = 0.5 - a*log(4*a);
            thresh = 1/2;
            
            locs = inval <= thresh;
            outval(locs) = (inval(locs).^2)/3;

            locs = inval > thresh;
            outval(locs) = (1/12)*( exp( (inval(locs) - c)/a ) + b );
        end
    end
end


function out = notImplemented(~) %#ok<STOUT>
    assert(false,'Encoder function is not implemented for BT.2100 RGB Encoder.')
end


function out = convertToUint16(in, bitDepth, tf)
% Function that accepts a linear input signal and converts it into the
% scaled and offset uint16 output. This input signal can be R, G, B color
% channels, Y and constant intensity I. The input has be of double type.    
    if strcmpi(tf, 'PQ')
        outlocal = images.color.BT2100RGBEncoder.lin2rgbPQ(in);
    elseif strcmpi(tf, 'HLG')
        outlocal = images.color.BT2100RGBEncoder.lin2rgbHLG(in);
    else
        assert(false, 'Unsupported Transfer function');
    end

    [blackLevel, nominalPeak] = getNominalDataRange(bitDepth);
    nominalRange = nominalPeak - blackLevel;

    outlocal = outlocal*nominalRange;
    
    out = uint16(outlocal + blackLevel);
end


function out = convertFromUint16(in, bitDepth, tf)
% Function that accepts a non-linear input signal and it converts it into a
% linear output after compensating for bias ans scale. This input signal
% can be R, G, B color channels, Y and constant intensity I. The input has
% be of uint16 type. 
    [blackLevel, nominalPeak] = getNominalDataRange(bitDepth);
    nominalRange = nominalPeak - blackLevel;
    inlocal = (double(in) - blackLevel) / nominalRange;
    
    if strcmpi(tf, 'PQ')
        out = images.color.BT2100RGBEncoder.rgb2linPQ(inlocal);
    elseif strcmpi(tf, 'HLG')
        out = images.color.BT2100RGBEncoder.rgb2linHLG(inlocal);
    else
        assert(false, 'Unsupported Transfer function');
    end
end

function [blackLevel, nominalPeak] = getNominalDataRange(bitDepth)    
    switch(bitDepth)
        case 10
            blackLevel = 64;
            nominalPeak = 940;
            
        case 12
            blackLevel = 256;
            nominalPeak = 3760;
            
        otherwise
            assert(false,"Unsupported bit depth");
    end
end

