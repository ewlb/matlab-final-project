%ActiveContourSpeedEdgeBased Speed function for the edge-based model.
%
%   See also ActiveContourEvolver, ActiveContourSpeed, ActiveContourSpeedChanVese

% Copyright 2023-2024 The MathWorks, Inc.

%#codegen

classdef ActiveContourSpeedEdgeBased < images.internal.coder.ActiveContourSpeed

    properties

        balloonC     % Balloon force constant
        advectionC   % Coefficient for the advection term (second term) in geodesic model
        smoothfactor % Coefficient for the curvature term

        % The next three parameters are for the edge potential function:
        % g(deltaI) = 1 ./ (1 + (deltaI/lambda).^edgeExponent)
        sigma        % Standard deviation of the Gaussian blur before gradient computation
        lambda       % Edge normalization factor
        edgeExponent % Exponent of the edge
    end

    properties(Access = 'private')

        gI         % g(deltaI) image
        grad_gI    % gradient of g(deltaI) image

    end

    methods

        function obj = ActiveContourSpeedEdgeBased(smoothfactor, balloonC, ...
                advectionC, sigma, lambda, edgeExponent,classVar)

            obj.smoothfactor = smoothfactor;
            obj.balloonC = balloonC;
            obj.advectionC = advectionC;
            obj.sigma = sigma;
            obj.lambda = lambda;
            obj.edgeExponent = edgeExponent;
            obj.grad_gI = zeros(coder.ignoreConst(0),coder.ignoreConst(0),coder.ignoreConst(0),'like',classVar);
            obj.gI = zeros(coder.ignoreConst(0),coder.ignoreConst(0),'like',classVar);

        end

        %==================================================================
        function obj = initalizeSpeed(obj,IOne, ~)

            if isinteger(IOne)
                ITwo = single(IOne);
            else
                ITwo  = IOne;
            end

            % Gaussian blurring filter
            filtRadius = ceil(obj.sigma*2); % 2 Standard deviations include >95% of the area.
            filtSize = 2*filtRadius + 1;

            coder.internal.errorIf(~ismatrix(ITwo),...
                'images:activecontour:edgeNotSupportedForColor');
            IThree = imgaussfilt(ITwo,coder.ignoreConst(obj.sigma),'Padding','replicate','FilterSize', filtSize);
            I = imgradient(IThree);
            giTmp = 1 ./ (1 + (I/obj.lambda).^obj.edgeExponent);
            obj.gI = giTmp;
            grad_gITmp = getImageDirectionalGradient(obj.gI);
            obj.grad_gI = grad_gITmp;

        end

        %==================================================================
        function F = calculateSpeed(obj, I, phi, pixIdx)

            if isempty(pixIdx)
                if isa(I,'single')
                    F = single(pixIdx);
                else
                    F = pixIdx;
                end
                return;
            end

            coder.internal.errorIf(~isequal(size(I,1),size(phi,1)) || ~isequal(size(I,2),size(phi,2)),...
                'images:activecontour:differentMatrixSize','I','PHI');

            numPix = numel(pixIdx);
            numDims = ndims(phi);

            edgePotential = obj.gI(pixIdx);
            [curvature, delPhiOne] = images.internal.coder.calculateCurvature(phi, pixIdx);
            if numel(size(phi)) == 3 && size(phi,3) == 1
                delPhi = delPhiOne(:,1:2);
            else
                delPhi = delPhiOne;
            end

            magDelPhi = sqrt(sum(delPhi.^2,2)); % !! Can the norm computation be done anyway else like using norm or hypot?
            idx2normalize = magDelPhi > 1e-12;
            if any(idx2normalize)
                delPhi(idx2normalize,:) = bsxfun(@rdivide,delPhi(idx2normalize,:), ...
                    magDelPhi(idx2normalize));
            end
            delPhi(~idx2normalize,:) = 0; % Zero out vectors with very small magnitude

            % Extract grad_gI locations
            delG = zeros(numPix, numDims);
            for jj = 1:numDims
                delG(:,jj) = obj.grad_gI(pixIdx+(jj-1)*numel(phi));
            end

            A = edgePotential.*bsxfun(@plus,obj.smoothfactor*curvature,obj.balloonC);
            B = bsxfun(@times,dot(delG,delPhi,2),obj.advectionC);

            F = A-B;

            F = F/max(abs(F)); % Normalization

        end

        % Set methods
        % =================================================================
        function obj = set.smoothfactor(obj,smoothfactorValue)
            validateattributes(smoothfactorValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.smoothfactor = double(smoothfactorValue);
        end

        %==================================================================
        function obj = set.advectionC(obj,advectionCValue)
            validateattributes(advectionCValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.advectionC = double(advectionCValue);
        end

        %==================================================================
        function obj = set.balloonC(obj,balloonCValue)
            validateattributes(balloonCValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'scalar','nonnan','finite'});
            obj.balloonC = double(balloonCValue);
        end

        function obj = set.lambda(obj,lambdaValue)
            validateattributes(lambdaValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.lambda = double(lambdaValue);
        end

        function obj = set.edgeExponent(obj,edgeExponentValue)
            validateattributes(edgeExponentValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.edgeExponent = double(edgeExponentValue);
        end

        function obj = set.sigma(obj,sigmaValue)
            validateattributes(sigmaValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.sigma = double(sigmaValue);
        end

    end % End of methods

end % End of class


%==========================================================================
function gI = getImageDirectionalGradient(I)
% Note that getImageDirectionalGradient should use exactly same gradient
% computation as what is used in calculateGradient(). calculateGradient()
% uses IntermediateDifference type computation which is also used by MATLAB
% function gradient(). We can use calculateGradient() here as well but
% since we are passing a whole image, gradient() is faster. The only
% difference is at the border pixels. In case of calculateGradient() the
% value at the output is probably half that give out by gradient().

if ndims(I) == 2  %#ok<ISMAT>
    [gX, gY] = gradient(I); % Not doing sobel because of speed.
    gI = cat(3,gX,gY);
elseif ndims(I) == 3
    [gX, gY, gZ] = gradient(I); % Not doing sobel because of speed.
    gI = cat(4,gX,gY,gZ);
end
P = ndims(I) == 2 || ndims(I) == 3; %#ok<ISMAT>
coder.internal.errorIf(~P,'images:activecontour:mustBe2D','A'); % Should never happen
end

