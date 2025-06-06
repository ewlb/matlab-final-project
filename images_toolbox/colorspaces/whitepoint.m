function xyz = whitepoint(wstr) %#codegen
%WHITEPOINT XYZ color values of standard illuminants.
%   XYZ = WHITEPOINT(STR) returns a three-element row vector of XYZ
%   values scaled so that Y = 1.  STR specifies the desired white point
%   and may be one of the strings or character vectors in this table:
%
%       STR          Illuminant
%       ---          ----------
%       'a'          CIE standard illuminant A
%       'c'          CIE standard illuminant C
%       'e'          Equal-energy radiator [1.000, 1.000, 1.000]
%       'd50'        CIE standard illuminant D50
%       'd55'        CIE standard illuminant D55
%       'd65'        CIE standard illuminant D65
%       'icc'        ICC standard profile connection space illuminant;
%                        a 16-bit fractional approximation of D50.
%
%   XYZ = WHITEPOINT is the same as XYZ = WHITEPOINT('icc').
%
%   Example
%   -------
%       xyz = whitepoint
%
%   See also APPLYCFORM, LAB2DOUBLE, LAB2UINT8, LAB2UINT16, MAKECFORM,
%            XYZ2DOUBLE, XYZ2UINT16.

%   Copyright 1993-2024 The MathWorks, Inc.

if (nargin == 0)
    wstr = 'icc';
else
    valid_strings = {'a','c','e','d50','d55','d65','icc'};
    wstr = validatestring(wstr,valid_strings,'whitepoint','WSTR',1);
end

switch wstr
    case 'd65'
        xyz = [ ...
            0.95047, ...
            1.0, ...
            1.08883 ...
            ];
    case 'icc'
        xyz = [ ...
            hex2dec('7b6b') / hex2dec('8000'), ...
            1.0, ...
            hex2dec('6996') / hex2dec('8000') ...
            ];
    case 'a'
        xyz = [ ...
            1.0985, ...
            1.0, ...
            0.3558 ...
            ];
    case 'c'
        xyz = [ ...
            0.9807, ...
            1.0, ...
            1.1823 ...
            ];
    case 'e'
        xyz = [ ...
            1.0, ...
            1.0, ...
            1.0 ...
            ];
    case 'd50'
        xyz = [ ...
            0.96419865576090, ...
            1.0, ...
            0.82511648322104 ...
            ];
    case 'd55'
        xyz = [ ...
            0.9568, ...
            1.0, ...
            0.9214 ...
            ];
    otherwise
        xyz = [ ...
            0.95047, ...
            1.0, ...
            1.08883 ...
            ];
end
