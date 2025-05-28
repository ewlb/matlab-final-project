function [BW, D] = imsegfmm(varargin)

narginchk(3,5);
matlab.images.internal.errorIfgpuArray(varargin{:});
[W, sourcePntIdx, thresh] = parse_inputs(varargin{:});

if isinteger(W)
    W = double(W);
end
if isempty(W)    
    BW = false(size(W));
    D = W;
    return;
end

sourcePntIdx = sourcePntIdx - 1; % For 0 based indexing. 

D = images.internal.builtins.fastmarching(W, sourcePntIdx);

% Normalize distance to range [0 1].
maxD = max(D(:));
if (maxD > 0) % minD is always 0.
    if isinf(maxD) 
        % If Inf is present only normalize the non-Inf elements.
        infIdx = ~isinf(D);
        maxD = max(D(infIdx));
        if isempty(maxD)
            maxD = 1;
        end
        D(infIdx) = D(infIdx)/maxD;
    else
        D = D/maxD;  
    end
end
BW = (D <= thresh);

end

function [W, sourcePntIdx, thresh] = parse_inputs(varargin)

% W = [];
% sourcePntIdx = [];
% thresh = [];

parser = inputParser;

parser.addRequired('W', @validateWeight);

switch(nargin)
    
    case 3 % BW = imsegfmm(W, MASK, THRESH)
        
        parser.addRequired('mask', @validateMask);
        parser.addRequired('thresh', @validateThreshold);
        
        parser.parse(varargin{:});
        res = parser.Results;
        
        W = res.W;
        mask = res.mask;
        thresh = double(res.thresh);
        
        if isequal(size(mask),size(W))
            sourcePntIdx = find(mask);        
        else
            error(message('images:validate:unequalSizeMatrices','W','MASK'));
        end
        
        
    case 4 % BW = imsegfmm(W, C, R, THRESH)
        
        parser.addRequired('C', @validateSeed);
        parser.addRequired('R', @validateSeed);
        parser.addRequired('thresh', @validateThreshold);
        
        parser.parse(varargin{:});
        res = parser.Results;
        
        W  =res.W;
        C = res.C;
        R = res.R;
        thresh = double(res.thresh);
        
        if ~isequal(numel(R),numel(C))
            error(message('images:validate:unequalNumberOfElements','C','R'));
        end
        
        if( ndims(W) > 2) %#ok<ISMAT>
           error(message('images:validate:tooManyDimensions', 'W', 2)) 
        end
        
        
        [nrows, ncols] = size(W);
        
        isRinValidRange = all((R >= 1) & (R <= nrows));
        isCinValidRange = all((C >= 1) & (C <= ncols)); 

        
        if ~isRinValidRange
            error(message('images:validate:SubscriptsOutsideRange','R'));
        end
        if ~isCinValidRange
            error(message('images:validate:SubscriptsOutsideRange','C'));
        end
        
         sourcePntIdx = sub2ind([nrows ncols],R,C);
        
        
    case 5 % BW = imsegfmm(W, C, R, P, THRESH)
        
        parser.addRequired('C', @validateSeed);
        parser.addRequired('R', @validateSeed);
        parser.addRequired('P', @validateSeed);
        parser.addRequired('thresh', @validateThreshold);
        
        parser.parse(varargin{:});
        res = parser.Results;
        
        W = res.W;
        C = res.C;
        R = res.R;
        P = res.P;
        thresh = double(res.thresh);
        
        if ~isequal(numel(R),numel(C), numel(P))
            error(message('images:validate:unequalNumberOfElements3', 'C', 'R', 'P'));
        end
        
        if( ndims(W) < 3) %#ok<ISMAT>
           error(message('images:validate:tooFewDimensions', 'W', 3)) 
        end
        
        
        [nrows, ncols, nplanes] = size(W);
        
        isRinValidRange = all((R >= 1) & (R <= nrows));
        isCinValidRange = all((C >= 1) & (C <= ncols));
        isPinValidRange = all((P >= 1) & (P <= nplanes));

        
        if ~isRinValidRange
            error(message('images:validate:SubscriptsOutsideRange','R'));
        end
        if ~isCinValidRange
            error(message('images:validate:SubscriptsOutsideRange','C'));
        end
        if ~isPinValidRange
            error(message('images:validate:SubscriptsOutsideRange','P'));
        end
        
        sourcePntIdx = sub2ind([nrows ncols nplanes],R,C,P);
        
    otherwise
        error(message('images:validate:invalidSyntax'));
        
end


end

function tf = validateWeight(W)
    validImageTypes = {'uint8','int8','uint16','int16','uint32','int32', ...
    'single','double'};
    validateattributes(W,validImageTypes,{'nonsparse','real','3d', ...
        'nonempty','nonnegative'}, mfilename,'W',1);
    tf = true;
end
        

function tf = validateMask(mask)
    validateattributes(mask,{'logical'},{'nonsparse','real','3d', ...
        'nonempty'}, mfilename,'Mask',2);
    tf = true;
end


function tf = validateThreshold(thresh)
    validateattributes(thresh,{'numeric'},{'nonsparse','real','scalar', ...
        'nonnan','>=',0,'<=',1},mfilename,'THRESH');
    tf = true;
end

function tf = validateSeed(seedPoints)
    validateattributes(seedPoints,{'numeric'},{'nonsparse','integer'}, ...
        mfilename);
    tf = true;
end   

%   Copyright 2014-2020 The MathWorks, Inc.

