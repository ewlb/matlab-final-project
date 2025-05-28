function [p,theta,filter,d,interp,N] = parseInputs(varargin) %#codegen
%  Input parsing helper for IRADON function
%
%  Inputs:   varargin -   Cell array containing all of the actual inputs
%
%  Outputs:  p        -   Projection data
%            theta    -   the angles at which the projections were taken
%            filter   -   string specifying filter or the actual filter
%            d        -   a scalar specifying normalized freq. at which to crop
%                         the frequency response of the filter
%            interp   -   the type of interpolation to use
%            N        -   The size of the reconstructed image
% This helper function supports three targets: SIM, GPUARRAY, C/C++ Codegen

% Copyright 2022 The MathWorks, Inc.

    coder.inline('always');
    coder.internal.prefer_const(varargin);

    p     = varargin{1};
    theta = varargin{2};
    
    validateattributes(p    ,{'single','double','logical'},{'real','2d','nonsparse'},'iradon','R'    ,1);
    validateattributes(theta,{'single', 'double'},{'real','nonsparse'}     ,'iradon','theta',2);
    
    % Default values
    N = 0;                 % Size of the reconstructed image
    d = 1;                 % Defaults to no cropping of filters frequency response

    % Using enums to ensure compile-time constness is handled in C/C++
    % codegen mode. 
    filter = images.internal.iradon.FilterNames.RamLak;    % The ramp filter is the default
    interp = images.internal.iradon.InterpModes.Linear;     % default interpolation is linear
    
    interp_strings = coder.const({'nearest', 'linear', 'spline', 'pchip', 'cubic', 'v5cubic'});
    filter_strings = coder.const({'ram-lak','shepp-logan','cosine','hamming', 'hann', 'none'});
    string_args    = coder.const({interp_strings{:} filter_strings{:}});
    
    % Parse the optional arguments supplied
    for i=coder.unroll(3:nargin)
        arg = convertStringsToChars(varargin{i});
        
        % Optional arguments can either be char row vectors or numeric
        % scalars.
        coder.internal.errorIf( ~ischar(arg)  && (numel(arg) ~= 1), ...
                                'images:iradon:invalidInputParameters' );
        if ischar(arg)
            str = validatestring(arg,string_args,'iradon','interpolation or filter');
            idx = find(strcmp(str,string_args),1,'first');
            if idx <= numel(interp_strings)
                % interpolation method
                interp = coder.const(images.internal.iradon.convertInterpModesToEnum(string_args{idx}));
            else %if (idx > numel(interp_strings)) && (idx <= numel(string_args))
                % filter type
                filter = coder.const(images.internal.iradon.convertFilterNamesToEnum(string_args{idx}));
            end
        else
            validateattributes(arg, {'numeric', 'logical'}, {}, 'iradon');
            if arg <=1
                % frequency scale
                validateattributes(arg,{'numeric','logical'},...
                    {'positive','real','nonsparse'},'iradon','frequency_scaling');
                d = arg;
            else
                % output size
                validateattributes(arg,{'numeric'},{'real','finite','nonsparse','integer'},...
                    'iradon','output_size');
                N = arg;
            end
        end
    end
    
    % If the user didn't specify the size of the reconstruction, so
    % deduce it from the length of projections
    if N==0
        N = 2*floor( size(p,1)/(2*sqrt(2)) );  % This doesn't always jive with RADON
    end
    
    numTheta = numel(theta);
    % NumTheta == 0 => compute a suitable delta-theta
    % NumTheta == 1 => User supplied delta-theta
    % These will be processed later.
    coder.internal.errorIf( ...
        ~ismember(numTheta, [0 1]) && numTheta ~= size(p,2), ...
        'images:iradon:thetaNotMatchingProjectionNumber' );
end
