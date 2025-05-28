% Controls where IMREGCORR uses the R2024b bug fixes for the phase
% correlation method.
%
% For internal testing only.
%
% state = usePhasecorrBugFixes returns the current state, true or false.
%
% usePhasecorrBugFixes(state) updates the state.
%
% old_state = usePhasecorrBugFixes(new_state) updates the state returns the
% previous state.

function old_state = usePhasecorrBugFixes(new_state)%#codegen
    arguments
        new_state (1,1) logical = defaultState
    end

    % Lock the function so that the state doesn't change in response to
    % "clear all".
    % mlock

    persistent PHASECORR_BUG_FIX_STATE

    if isempty(PHASECORR_BUG_FIX_STATE)
        PHASECORR_BUG_FIX_STATE = defaultState;
    end

    old_default_out = PHASECORR_BUG_FIX_STATE;

    if nargin > 0
        % New state was not passed in by the caller, so don't use it.
        PHASECORR_BUG_FIX_STATE = new_state;
    end

    if (nargin == 0) || (nargout > 0)
        % Return the previous state as the output argument.
        old_state = old_default_out;
    end
end

function state = defaultState
    state = true;
end

% Copyright 2023-2024 The MathWorks, Inc.