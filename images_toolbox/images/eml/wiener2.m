function [f,noise] = wiener2(varargin) %#codegen
%WIENER2 2-D adaptive noise-removal filtering.
%
%  Syntax
%  ------
%
%  J = wiener2(I,[M N], NOISE)
%
%  [J, NOISE] =  wiener2(I) or wiener2(I, [M N])
%
%  Input Specs
%  ------------
%
%  I:
%   uint8, uint16, int16, double, or single
%
%  M,N
%   positive integer
%
%  NOSIE
%   single or double
%
%  Output Specs
%  ------------
%
%  J:
%     Same as I

% Copyright 2021 The MathWorks, Inc.

%#ok<*EMCA>

[g, nhood, noiseOne] = ParseInputs(varargin{:});
classin = underlyingType(g);
classChanged = false;
if ~isUnderlyingType(g, 'double')
    classChanged = true;
    gOne = im2double(g);
else
    gOne = g;
end

% Estimate the local mean of f.
localMean = filter2(ones(nhood), gOne) / prod(nhood);

% Estimate of the local variance of f.
localVar = filter2(ones(nhood), gOne.^2) / prod(nhood) - localMean.^2;

% Estimate the noise power if necessary.
if (isempty(noiseOne))
    noise = mean2(localVar);
else
    noise = noiseOne;
end

% Compute result
% f = localMean + (max(0, localVar - noise) ./ ...
%           max(localVar, noise)) .* (g - localMean);
%
% Computation is split up to minimize use of memory
% for temp arrays.

fOne = gOne - localMean;
gOne = max(localVar - noise, 0);
localVar = max(localVar, noise);

fOne = (fOne ./ localVar).*gOne + localMean;
if classChanged
    f = images.internal.changeClass(classin, fOne);
else
    f = fOne;
end


%%%
%%% Subfunction ParseInputs
%%%
%%
function [g, nhood, noise] = ParseInputs(varargin)
coder.inline('always');
nhood = [3 3];
noise = [];

switch nargin
    case 0
        coder.internal.errorIf(true,...
            'images:wiener2:tooFewInputs');

    case 1
        % wiener2(I)

        g = varargin{1};

    case 2
        g = varargin{1};

        switch numel(varargin{2})
            case 1
                % wiener2(I,noise)

                noise = varargin{2};

            case 2
                % wiener2(I,[m n])

                nhood = varargin{2};

            otherwise
                coder.internal.errorIf(true,...
                    'images:validate:invalidSyntax');
        end

    case 3
        g = varargin{1};

        if (numel(varargin{3}) == 2)
            % wiener2(I,[m n],[mblock nblock]) REMOVED
            coder.internal.errorIf(true,...
                'images:removed:syntax','WIENER2(I,[m n],[mblock nblock])','WIENER2(I,[m n])');
        else
            % wiener2(I,[m n],noise)
            nhood = varargin{2};
            noise = varargin{3};
        end

    case 4
        coder.internal.errorIf(true,...
            'images:removed:syntax','WIENER2(I,[m n],[mblock nblock],noise)','WIENER2(I,[m n],noise)');
        g = varargin{1};
        nhood = varargin{2};
        noise = varargin{4};

    otherwise
        coder.internal.errorIf(true,...
            'images:wiener2:tooManyInputs');
end

% checking if input image is a truecolor image-not supported by WIENER2
coder.internal.errorIf(ndims(g) == 3,...
    'images:wiener2:wiener2DoesNotSupport3D');
