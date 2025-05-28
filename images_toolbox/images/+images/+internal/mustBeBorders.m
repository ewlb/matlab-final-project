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

function mustBeBorders(borders)

    if isstring(borders)
        mustBeVector(borders);
        mustBeMember(borders,["left" "right" "top" "bottom"]);
    elseif iscell(borders)
        mustBeVector(borders);
        mustBeMember(borders,{'left' 'right' 'top' 'bottom'});
    else
        mustBeNumericOrLogical(borders);

        if ~ismatrix(borders) || (size(borders,2) ~= 2) || (size(borders,1) < 2)
            error(message("images:validate:badBordersForm"))
        end

        mustBeMember(borders,[0 1]);
    end
end

% Copyright 2023 The MathWorks, Inc.