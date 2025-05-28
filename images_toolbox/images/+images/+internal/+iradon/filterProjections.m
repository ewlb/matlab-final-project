function [pOut,H] = filterProjections(pIn, filter, d, useSingleForComp, isMixedInputs) %#codegen
% Helper function that filters the projections.
% This helper function supports three targets: SIM, GPUARRAY, C/C++ Codegen

% Copyright 2022 The MathWorks, Inc.
    
    % Design the filter. Filter coefficients must be single only if both
    % projections and angles are single. This is to preserve backward
    % compatibility.
    if coder.const(useSingleForComp && ~isMixedInputs)
        filtType = coder.const('single');
    else
        filtType = coder.const('double');
    end
    
    len = size(pIn, 1);
    H = designFilter(filter, len, d, filtType);
    
    if coder.const(filter == images.internal.iradon.FilterNames.None)
        pOut = pIn;
        return;
    end
    
    % Zero pad projections
    pPad = zeros(length(H), size(pIn,2), 'like', pIn);
    pPad(1:size(pIn,1),:) = pIn;

    % In the code below, I continuously reuse the array p so as to
    % save memory.  This makes it harder to read, but the comments
    % explain what is going on.
    
    pPad = fft(pPad);         % pPad holds fft of projections
    
    pPad = bsxfun(@times, pPad, H); % faster than for-loop
    
    if coder.target('MATLAB')
        pOut = ifft(pPad,'symmetric');  % p is the filtered projections

        % Truncate the filtered projections
        if isa(pPad, "gpuArray")
             % MCOS overload issue so directly form subsref
            pOut = subsref(pOut,substruct('()', {1:len ':'}));
        else
            pOut(len+1:end,:) = [];
        end
    else
        pOut = coder.nullcopy(zeros(size(pIn), 'like', pIn));

        % symmetric option for ifft is not supported for codegen, using
        % nonsymmetric instead.
        pPad = real(ifft(pPad,'nonsymmetric'));

        % Truncate the filtered projections
        pOut(:,:) = pPad(1:size(pIn,1),:);
    end
end

function filt = designFilter(filter, len, d, filtType)
% Returns the Fourier Transform of the filter which will be
% used to filter the projections
%
% INPUT ARGS:   filter - Enumeration specifying name of the filter
%               len    - the length of the projections
%               d      - the fraction of frequencies below the nyquist
%                        which we want to pass
%               filtType - specify if filter coefficients are in single or
%                          double precision
%
% OUTPUT ARGS:  filt   - the filter to use on the projections

    order = max(64,2^nextpow2(2*len));
    
    if coder.const(filter == images.internal.iradon.FilterNames.None)
        filt = ones(1, order, coder.const(filtType));
        return;
    end
    
    % First create a bandlimited ramp filter (Eqn. 61 Chapter 3, Kak and
    % Slaney) - go up to the next highest power of 2.
    
    % 'order' is always even. 
    n = cast(0:(order/2), filtType);

    % 'filtImpResp' is the bandlimited ramp's impulse response (values for
    % even n are 0) 
    filtImpResp = zeros(1,(order/2)+1, coder.const(filtType));

    % Set the DC term 
    filtImpResp(1) = 1/4;

    % Set the values for odd n
    filtImpResp(2:2:end) = -1./((pi*n(2:2:end)).^2);
    filtImpResp = [filtImpResp filtImpResp(end-1:-1:2)];
    filt = 2*real(fft(filtImpResp));
    filt = filt(1:(order/2)+1);
    
    % frequency axis up to Nyquist
    w = 2*pi*(0:size(filt,2)-1)/order;
    
    switch coder.const(filter)
        case images.internal.iradon.FilterNames.RamLak
            % Do nothing
        case images.internal.iradon.FilterNames.SheppLogan
            % be careful not to divide by 0:
            filt(2:end) = filt(2:end) .* (sin(w(2:end)/(2*d))./(w(2:end)/(2*d)));
        case images.internal.iradon.FilterNames.Cosine
            filt(2:end) = filt(2:end) .* cos(w(2:end)/(2*d));
        case images.internal.iradon.FilterNames.Hamming
            filt(2:end) = filt(2:end) .* (.54 + .46 * cos(w(2:end)/d));
        case images.internal.iradon.FilterNames.Hann
            filt(2:end) = filt(2:end) .*(1+cos(w(2:end)./d)) / 2;
        otherwise
            % Should not reach this. 
            % Using an assert is sufficient as filter name is a compile
            % time constant and has already been validated
            assert(false, 'Unsupported filter name');
    end
    
    % Crop the frequency response
    filt(w>pi*d) = 0;

    % Symmetry of the filter
    filt = [filt' ; filt(end-1:-1:2)'];
end
