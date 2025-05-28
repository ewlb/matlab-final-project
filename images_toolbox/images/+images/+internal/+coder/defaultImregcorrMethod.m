% Controls the default method, "gradcorr" or "phasecorr", used by
% IMREGCORR in simulation.
%
% For internal testing only.
%
% alg = defaultImregcorrMethod returns the current default method.
%
% defaultImregcorrMethod(method) updates the default method.
%
% old_method = defaultImregcorrMethod(new_method) updates the default
% method and returns the previous default.

function old_method = defaultImregcorrMethod(new_method)
    arguments
        new_method (1,1) string = defaultDefault
    end

    % Lock the function so that the state doesn't change in response to
    % "clear all".
    % mlock

    persistent DEFAULT_METHOD

    if isempty(DEFAULT_METHOD)
        DEFAULT_METHOD = defaultDefault;
    end

    old_default_out = DEFAULT_METHOD;

    if nargin > 0
        % New state was not passed in by the caller, so don't use it.
        DEFAULT_METHOD = new_method;
    end

    if (nargin == 0) || (nargout > 0)
        % Return the previous state as the output argument.
        old_method = old_default_out;
    end
end

function method = defaultDefault
    method = "gradcorr";
end

% Copyright 2023-2024 The MathWorks, Inc.