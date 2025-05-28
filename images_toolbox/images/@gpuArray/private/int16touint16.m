function J = int16touint16(I)
    %INT16TOUINT16 Converts int16 to uint16
    %   INT16TOUINT16 takes a gpuArray image I of underlying class int16, and
    %   returns a gpuArray image J of underlying class uint16. If I is uint16,
    %   then J is identical to it.  If I is not int16 then INT16TOUINT16
    %   errors.

    %   Copyright 2022 The MathWorks, Inc.

    narginchk(1,1);

    validateattributes(I,...
        {'int16'}, ...
        {'nonsparse'},mfilename,'I',1);

    if(~isreal(I))
        warning(message('images:int16touint16:ignoringImaginaryPartOfInput'));
        I = real(I);
    end

    % Convert int16 to uint16.
    J = arrayfun(@int16touint16fun,I);
end

function z = int16touint16fun(img)
    %INT16TOUINT16FUN converts int16 to uint16
    %   Z = UINT16TOINT16FUN(I) converts int16 data (range = -32768 to 32767). to uint16
    %   data (range = 0 to 65535)

    z = uint16(int32(img) + int32(32768));

end