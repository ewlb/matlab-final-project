function out = mkconstarray(proto, value, size)
%MKCONSTARRAY creates a constant valued array
%   A = MKCONSTARRAY(PROTO, VALUE, SIZE) creates a constant array of
%   value VALUE and of size SIZE, with type, storage, etc. matching PROTO.

%   Copyright 1993-2023 The MathWorks, Inc.

% Trap the 0 and 1 case explicitly so that we avoid combining with the pad
% value (can cause change in output type, e.g. from logical to double).
if value == 0
    out = zeros(size, "like", proto);
elseif value == 1 || islogical(proto) % Any non-zero value is treated as 1 for logicals
    out = ones(size, "like", proto);
else
    out = ones(size, "like", proto) .* value;
end

