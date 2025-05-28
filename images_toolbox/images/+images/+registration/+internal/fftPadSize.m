% Recommended FFT pad size for fastest performance.
%
% The FFTW library used by MATLAB is highly optimized for FFT sizes that
% have prime factors 2, 3, 5, and 7. This function returns the smallest
% number that is even, greater than or equal to N, and has no prime factors
% greater than 7.
%
% See the local function findTransformLength in xcorr.m.

function Np = fftPadSize(N)
    arguments
        N (1,1) double {mustBeInteger, mustBeNonnegative, mustBeGreaterThan(N,0)}
    end

    % If the input is odd, increment by 1 to make it even.
    if mod(N,2) == 1
        N = N + 1;
    end

    while true
        r = N;

        % For each of the prime factors 2, 3, 5, and 7, repeatedly divide
        % by that factor until r has either been reduced to 1 or is not
        % divisible by that factor.
        for p = [2 3 5 7]
            while (r > 1) && (mod(r, p) == 0)
                r = r / p;
            end
        end

        % If r is 1, that means that N has no prime factors greater than 7,
        % so end the loop.
        if r == 1
            break;
        end

        % Increment to the next even number.
        N = N + 2;
    end

    Np = N;
end

% Copyright 2023 The MathWorks, Inc.