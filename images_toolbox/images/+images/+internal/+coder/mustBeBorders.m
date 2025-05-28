%mustBeBorders Validate borders argument
%   mustBeBorders(borders) validates a borders argument for the
%   IMCLEARBORDER and IMKEEPBORDER functions. It is intended to be used
%   in a function arguments block.
%
%   A borders argument must be either:
%
%   - a string vector containing a subset of "left", "right", "top",
%     "bottom"
%   - a Px2 numeric or logical matrix, P >= 2
%

% Copyright 2023 The MathWorks, Inc.

%#ok<*EMCA>

function mustBeBorders(borders) %#codegen

if isstring(borders) %single string
    mustBeVector(borders);
    mustBeMember(borders,{"left" "right" "top" "bottom"});

elseif iscell(borders) % cell array
    mustBeVector(borders);
    for i = 1:coder.internal.indexInt(numel(borders))
        mustBeMember(borders{i},{"left" "right" "top" "bottom"});
    end

else
    mustBeNumericOrLogical(borders);
    coder.internal.errorIf(~ismatrix(borders) ||...
        (size(borders,2) ~= 2) || (size(borders,1) < 2),...
        'images:validate:badBordersForm');
    mustBeMember(borders,[0 1]);
end
end