%mustBeConnectivity Validate connectivity argument
%   mustBeConnectivity(conn) validates a borders argument for
%   IMCLEARBORDER, IMKEEPBORDER, and possibly other toolbox functions that
%   accept a CONN argument. It is intended to be used in a function
%   arguments block.
%
%   A CONN argument must be either:
%
%   - a scalar that is 1, 4, 6, 8, 18, or 26
%   - a 3x3x ... x3 array of all 0s and 1s, such that the central element
%   is 1, and such that the array is symmetric with respect to its central
%   element.



function mustBeConnectivity(conn) %#codegen
arguments
    conn {mustBeNumericOrLogical}
end

if isscalar(conn)
    mustBeMember(conn, [1 4 6 8 18 26])
else
    % If not a scalar, conn must be 3x3x ... x3.
    coder.internal.errorIf(any(size(conn) ~= 3),...
        'images:validate:badConnectivitySize');
    mustBeMember(conn, [0 1]);

    % For a 3x3x ... x3 array, linear indexing with (end+1)/2 gives the
    % center element, which is required to be 1.

    coder.internal.errorIf(conn((end+1)/2) ~= 1,...
        'images:validate:badConnectivityCenter');

    coder.internal.errorIf(~isequal(conn(1:end), conn(end:-1:1)),...
        'images:validate:nonsymmetricConnectivity');
end

% Copyright 2023 The MathWorks, Inc.