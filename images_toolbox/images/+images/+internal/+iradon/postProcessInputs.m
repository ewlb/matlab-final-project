function [pOut, thetaOut, useSingleForComp, isMixedInputs] = ...
                                    postProcessInputs(pIn, theta) %#codegen
% Helper function that determines if single-precision computation has to be
% enabled for computing the results.
% This helper function supports three targets: SIM, GPUARRAY, C/C++ Codegen

% Copyright 2022 The MathWorks, Inc.

    % This is needed to design the filter coefficient of the suitable class
    % for backwards compatibility.
    isMixedInputs = coder.const( ~strcmp( underlyingType(pIn), ...
                                          underlyingType(theta) ) );
    
    % The interp1 code path in Sim IRADON produces single precision outputs
    % if either projections or angles are single precision. Hence, casting
    % all inputs to single if any inputs are single, thereby doing
    % computations in single.
    useSingleForComp = coder.const( strcmp(underlyingType(pIn), 'single') || ...
                                    strcmp(underlyingType(theta), 'single') );

    if useSingleForComp
        pOut = single(pIn);
        thetaLocal = single(theta);
    else
        pOut = pIn;
        thetaLocal = theta;
    end
    
    thetaOut = postProcessTheta(thetaLocal, size(pIn, 2));
end

function thetaOut = postProcessTheta(thetaIn, numThetaInProj)
% Helper function that does some post processing on the theta input
% argument 


    % For empty theta, choose an intelligent default delta-theta
    if isempty(thetaIn)
        thetaLocal = cast(pi / numThetaInProj, underlyingType(thetaIn));
    else
        % Convert to radians
        thetaLocal = pi*thetaIn/180;
    end
    
    % If the user passed in delta-theta, build the vector of theta values
    if numel(thetaLocal)==1
        thetaOut = (0:(numThetaInProj-1))* thetaLocal;
    else
        thetaOut = thetaLocal;
    end
end
