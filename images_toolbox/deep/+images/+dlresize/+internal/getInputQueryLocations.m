function [start,stride,stop] = getInputQueryLocations(geometricTransformMode,outputSize,scale)
%getInputQueryLocations Determine query points in input space for dlresize.

% Copyright 2020 The MathWorks, Inc.

switch (geometricTransformMode)
    
    case "half-pixel" % Same behavior as imresize in sampling
        
        % Output-space coordinates;
        x = cat(1,ones(1,length(outputSize)),outputSize)'; %[dim1Min,dim1Max; dim2Min,dim2Max;...];
        
        % Input-space coordinates. Calculate the inverse mapping such that 0.5
        % in output space maps to 0.5 in input space, and 0.5+scale in output
        % space maps to 1.5 in input space.
        u = x./scale(:) + 0.5 * (1 - 1./scale(:));
        
        start = u(:,1);
        stop = u(:,2);
        stride = 1./scale(:);
                
    case "asymmetric"
        
        start = zeros(length(outputSize),1);        
        start = start ./ scale(:) + 1;
        stride = 1 ./ scale(:);
        stop = start + (outputSize-1)'.*stride;

    otherwise
        assert(false,'Unexpected geometric transformation mode');
end

if isscalar(stride)
    stride = repmat(stride,[length(outputSize),1]);
end

end