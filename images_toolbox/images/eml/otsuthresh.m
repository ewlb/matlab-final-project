function [t,em] = otsuthresh(counts) %#codegen
%OTSUTHRESH Global histogram threshold using Otsu's method - M-to-C codegen.

%   Copyright 2015-2021 The MathWorks, Inc.

%   Syntax
%   ------
%
%       [t,em] = otsuthresh(counts)
%
%   Input Specs
%   -----------
%
%      counts:
%        numeric
%        vector
%        real
%        finite
%        non-sparse
%        non-negative
%
%   Output Specs
%   ------------
%
%     t:
%       scalar
%       double
%       in [0,1]
%
%     em:
%       scalar
%       double
%       in [0,1]
%

% Validate counts
validateattributes(counts,{'numeric'}, ...
    {'vector','real','finite','nonsparse','nonnegative'},mfilename,'COUNTS');

if coder.gpu.internal.isGpuEnabled
    % GPU specific implementation
    if nargout > 1
        [t, em] = images.internal.coder.gpu.otsuthreshImpl(counts);
    else
        t = images.internal.coder.gpu.otsuthreshImpl(counts);
    end
else
    % Number of bins
    num_bins = numel(counts);
    
    % Number of elements
    num_elems = 0;
    for k = 1:num_bins
        num_elems = num_elems + double(counts(k));
    end
    
    % CDF of the histogram
    omega = coder.nullcopy(zeros(num_bins,1));
    omega(1) = double(counts(1))/num_elems;
    
    mu = coder.nullcopy(zeros(num_bins,1));
    mu(1) = omega(1);
    
    for k = 2:num_bins
        % PDF
        p = double(counts(k))/num_elems;
        % CDF
        omega(k) = omega(k-1) + p;
        % "weighted" CDF
        mu(k) = mu(k-1) + p*k;
    end
    
    mu_t = mu(end);
    
    % Equation 18 in the paper
    maxval = -coder.internal.inf;
    
    % Find the location of the maximum value of sigma_b_squared.
    % If maxval is NaN, meaning that sigma_b_squared
    % is all NaN, then return 0.
    
    idx = double(0);
    num_maxval = double(0);
    for k = 1:num_bins-1
        sigma_b_squared = (mu_t*omega(k) - mu(k))^2 / (omega(k)*(1-omega(k)));
        if sigma_b_squared > maxval
            maxval = sigma_b_squared;
            idx = k;
            num_maxval = 1;
        elseif sigma_b_squared == maxval
            idx = idx + k;
            num_maxval = num_maxval + 1;
        end
    end
    
    isfinite_maxval = isfinite(maxval);
    if isfinite_maxval
        idx = idx/num_maxval;
        t = (idx - 1) / (num_bins - 1);
    else
        t = 0;
    end
    
    % Compute the effectiveness metric
    if nargout > 1
        if isfinite_maxval
            d = 0;
            for k = 1:num_bins
                d = d + double(counts(k))/num_elems * k^2;
            end
            em = maxval/(d - mu_t^2);
        else
            em = 0;
        end
    end
end
