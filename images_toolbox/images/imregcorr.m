function [tform, peak] = imregcorr(varargin)

narginchk(2,inf)
matlab.images.internal.errorIfgpuArray(varargin{:});
[moving,fixed,transformationType,windowing,method,Rmoving,Rfixed] = ...
    parseInputs(varargin{:});

% FFT2 is fastest for single inputs. Work in single unless double precision
% floating point data was specified.
if ~isa(moving,'double')
    moving = single(moving);
end

if ~isa(fixed,'double')
    fixed = single(fixed);
end

if ismember(transformationType,{'translation','rigid'})
    if ~samePixelWorldExtent(Rmoving,Rfixed)
        error(message("images:imregcorr:pixelReferenceSizeMismatch",transformationType))
    end
end

switch (transformationType)

    case 'translation'
        if method == "gradcorr"
            [tform,peak] = images.registration.internal.findTranslationNGC(moving,fixed);
        else
            [tform,peak] = findTranslation(moving,fixed,windowing);
        end
    case 'rigid'
        if method == "gradcorr"
            [tform,peak] = images.registration.internal.findRigidNGC(moving,fixed);
        else
            [tform,peak] = findRigid(moving,fixed,windowing);
        end
    case 'similarity'
        if method == "gradcorr"
            [tform,peak] = images.registration.internal.findSimilarityNGC(moving,fixed);
        else
            [tform,peak] = findSimilarity(moving,fixed,windowing);
        end
    otherwise
        assert(false, 'Unexpected transformationType.');

end

spatialReferencingSpecified = ~isempty(Rmoving);
if spatialReferencingSpecified
    tform = moveTransformationToWorldCoordinateSystem(tform,Rmoving,Rfixed);
end

end %end imregcorr

%-----------------------------------------------------------------------
function tf = samePixelWorldExtent(moving_ref,fixed_ref)
% Either spatial reference can be [] if the user didn't pass it in
% explicitly. If a spatial ref is [], use 1 as the extent, since that
% is the default for imref2d.
if isempty(moving_ref)
    moving_extent_x = 1;
    moving_extent_y = 1;
else
    moving_extent_x = moving_ref.PixelExtentInWorldX;
    moving_extent_y = moving_ref.PixelExtentInWorldY;
end

if isempty(fixed_ref)
    fixed_extent_x = 1;
    fixed_extent_y = 1;
else
    fixed_extent_x = fixed_ref.PixelExtentInWorldX;
    fixed_extent_y = fixed_ref.PixelExtentInWorldY;
end
tf = (moving_extent_x == fixed_extent_x) && ...
    (moving_extent_y == fixed_extent_y);
end

%-----------------------------------------------------------------------
function [M,F] = getFourierMellinSpectra(moving,fixed,windowing)

% Move Moving and Fixed into frequency domain
M_size = size(moving);
F_size = size(fixed);
outsize = M_size + F_size - 1;

% Apply windowing function to moving and fixed to reduce aliasing in
% frequency domain.
moving = manageWindowing(moving,windowing);
fixed  = manageWindowing(fixed,windowing);

% Obtain the spectra of moving and fixed: M and F.
M = fft2(moving,outsize(1),outsize(2));
F = fft2(fixed,outsize(1),outsize(2));

% Shift DC of fft to center
F = fftshift(F);
M = fftshift(M);

% Form Magnitude Spectra
F = abs(F);
M = abs(M);

% Apply High-Pass Emphasis filter to each image (Reddy, Chatterji)
H = createHighPassEmphasisFilter(outsize);

F = F .* H;
M = M .* H;

end


%----------------------------------------------------------------
function [tform,peak] = solveForTranslationGivenScaleAndRotation(moving,fixed,S,theta,windowing)
% There is a 180 degree ambiguity in theta solved in R,Theta space. This
% ambiguity stems from the conjugate symmetry of the Fourier spectrum for real
% valued input images.
%
% This function resolves the ambiguity by forming two resampled versions of moving
% rotated by theta, theta+180, phase correlating each version of the
% resampled image with fixed, and choose the S,Theta that has the highest
% final peak correlation during recovery of translation.
%
% We save 1 FFT2 operation at full scale with the following
% optimizations:
%
% 1) By directly performing the phase correlation here instead of calling
% phasecorr/findTranslationPhaseCorr directly, we save 1 FFT operation by
% not computing the spectra of fixed twice.

theta1 = theta;
theta2 = theta+pi;

tform1 = affinetform2d([S.*cos(theta1) -S.*sin(theta1) 0; S.*sin(theta1) S.*cos(theta1) 0; 0 0 1]');
tform2 = affinetform2d([S.*cos(theta2) -S.*sin(theta2) 0; S.*sin(theta2) S.*cos(theta2) 0; 0 0 1]');

[scaledRotatedMoving1,RrotatedScaled1] = imwarp(moving,tform1,'SmoothEdges', true);

scaledRotatedMoving1 = manageWindowing(scaledRotatedMoving1,windowing);

fixed = manageWindowing(fixed,windowing);

% This step is equivalent to:
%   [scaledRotatedMoving2,RrotatedScaled2] = imwarp(moving,tform2)
% We do this to gain efficiency in computing scaledRotatedMoving2,
scaledRotatedMoving2 = rot90(scaledRotatedMoving1,2);
RrotatedScaled2 = imref2d(size(scaledRotatedMoving1),...
    sort(-RrotatedScaled1.XWorldLimits),...
    sort(-RrotatedScaled1.YWorldLimits));

% Form 2-D spectra associated with scaledRotatedMoving1, scaledRotatedMoving2, and fixed.
size_moving  = size(scaledRotatedMoving1);
size_fixed  = size(fixed);
outSize = size_moving + size_fixed - 1;
M1 = fft2(scaledRotatedMoving1,outSize(1),outSize(2));
F  = fft2(fixed,outSize(1),outSize(2));
M2 = fft2(scaledRotatedMoving2,outSize(1),outSize(2));

% Form the phase correlation matrix d1 for M1 correlated with F.
ABConj = F .* conj(M1);
d1 = ifft2(ABConj ./ abs(eps+ABConj),'symmetric');

% Form the phase correlation matrix d2 for M2 correlated with F.
ABConj = F .* conj(M2);
d2 = ifft2(ABConj ./ abs(eps+ABConj),'symmetric');

% Find the translation vector that aligns scaledRotatedMoving1 with fixed and
% scaledRotatedMoving2 with fixed. Choose S,theta,translation estimate that has
% the highest peak correlation in the final translation recovery step.
[vec1,peak1] = findTranslationPhaseCorr(d1);
[vec2,peak2] = findTranslationPhaseCorr(d2);

if single(peak1) >= single(peak2)
    vec = vec1;
    tform = tform1;
    RrotatedScaled = RrotatedScaled1;
    peak = peak1;
else
    vec = vec2;
    tform = tform2;
    RrotatedScaled = RrotatedScaled2;
    peak = peak2;
end

% The scale/rotation operation performed prior to the final
% phase-correlation step results in a translation. The translation added
% during scaling/rotation is defined by RrotatedScaled. Form the final
% effective translation by summing the translation added during
% rotation/scale to the translation recovered in the final translation
% step.
finalXOffset  = vec(1) + (RrotatedScaled.XIntrinsicLimits(1)-RrotatedScaled.XWorldLimits(1));
finalYOffset  = vec(2) + (RrotatedScaled.YIntrinsicLimits(1)-RrotatedScaled.YWorldLimits(1));

tform.A(1:2,3) = [finalXOffset; finalYOffset];

end

%--------------------------------------------------------------
function [tform,peak] = findTranslation(moving,fixed,windowing)

moving = manageWindowing(moving,windowing);
fixed  = manageWindowing(fixed,windowing);

[vec,peak] = findTranslationPhaseCorr(moving,fixed);
tform = transltform2d([1, 0, 0; 0, 1, 0; vec(1), vec(2), 1]');

end

%------------------------------------------------------------------------
function [tform,peak] = findRigid(moving,fixed,windowing)

% A nice block diagram of the pure rigid algorithm appears in:
%   Y Keller, "Pseudo-polar based estimation of large translations rotations and
%   scalings in images", Application of Computer Vision, 2005. WACV/MOTIONS
%   2005 Volume 1.
%
% This follows directly from the derivation in Reddy, Chatterji.

% Move Moving and Fixed into frequency domain
[M,F] = getFourierMellinSpectra(moving,fixed,windowing);

thetaRange = [0 pi];
Fpolar = images.internal.Polar(F,thetaRange);
Mpolar = images.internal.Polar(M,thetaRange);

Fpolar.resampledImage = manageWindowing(Fpolar.resampledImage,windowing);
Mpolar.resampledImage = manageWindowing(Mpolar.resampledImage,windowing);

% Solve a 1-D phase correlation problem to resolve theta. We already know
% scale. Choose a 1-D profile in our Polar FFT grid parallel to the theta axis.
numSamplesRho = size(Fpolar.resampledImage,1);
rhoCenter = round(0.5+numSamplesRho/2);
vec = findTranslationPhaseCorr(Mpolar.resampledImage(rhoCenter,:),Fpolar.resampledImage(rhoCenter,:));

% Translation vector is zero based. We want to translate vector
% into one based intrinsic coordinates within the polar grid.
thetaIntrinsic = abs(vec(1))+1;
% We passed a vector to findTranslationPhaseCorr;
rhoIntrinsic   = 1;

% The translation vector implies intrinsic coordinates in the
% Fixed/Moving log-polar grid. We want to convert these intrinsic
% coordinate locations into world coordinates that tell us
% rho/theta.
[theta,~] = intrinsicToWorld(Fpolar,thetaIntrinsic,rhoIntrinsic);

% Use sign of correlation offset to figure out whether rotation
% is positive or negative.
theta = -sign(vec(1))*theta;

% By definition, Scale is 1 for a rigid transformation.
S = 1;

[tform,peak] = solveForTranslationGivenScaleAndRotation(moving,fixed,S,theta,windowing);
tform = rigidtform2d(tform);

end

%------------------------------------------------------------------------------
function [tform, peak] = findSimilarity(moving,fixed,windowing)

% Move Moving and Fixed into frequency domain
[M,F] = getFourierMellinSpectra(moving,fixed,windowing);

% (Reddy,Chatterji) recommends taking advantage of the conjugate
% symmetry of the Fourier-Mellin spectra. All of the unique
% spectral information is in the interval [0,pi].
thetaRange = [0 pi];
Fpolar = images.internal.LogPolar(F,thetaRange);
Mpolar = images.internal.LogPolar(M,thetaRange);

% Use phase-correlation to determine the translation within the
% log-polar resampled Fourier-Mellin spectra that aligns moving
% with fixed.
Fpolar.resampledImage = manageWindowing(Fpolar.resampledImage,windowing);
Mpolar.resampledImage = manageWindowing(Mpolar.resampledImage,windowing);

% Obtain full phase correlation matrix
d = phasecorr(Fpolar.resampledImage,Mpolar.resampledImage);

% Constrain our search in D to the range 1/4 < S < 4.
d = suppressCorrelationOutsideScale(d,Fpolar,4);

% Find the translation vector in log-polar space.
vec = findTranslationPhaseCorr(d);

% Translation vector is zero based. We want to translate vector
% into one based intrinsic coordinates within the log-polar grid.
thetaIntrinsic = abs(vec(1))+1;
rhoIntrinsic   = abs(vec(2))+1;

% The translation vector implies intrinsic coordinates in the
% Fixed/Moving log-polar grid. We want to convert these intrinsic
% coordinate locations into world coordinates that tell us
% rho/theta.
[theta,rho] = intrinsicToWorld(Fpolar,thetaIntrinsic,rhoIntrinsic);

% Use sign of correlation offset to figure out whether rotation
% is positive or negative.
theta = -sign(vec(1))*theta;

% Use sign of correlation offset to figure out whether or not to invert scale factor
S = rho .^ -sign(vec(2));

[tform,peak] = solveForTranslationGivenScaleAndRotation(moving,fixed,S,theta,windowing);
tform = simtform2d(tform);

end

%-----------------------------------------------------------
function d = suppressCorrelationOutsideScale(d,Fpolar,scale)
% This function takes a phase correlation matrix that relates the same
% sized log-polar grids Fpolar and Mpolar. We return a phase correlation
% matrix in which we set regions of the phase correlation matrix outside
% the symmetric range (1/scale, scale) to -Inf. This allows us to limit the
% search space of the phase correlation matrix during peak detection so
% that we will never find peaks that correspond to a scale value outside of
% the limits of scale.

[~,logRhoIndex] = worldToIntrinsic(Fpolar,0,scale);
logRhoIndex = floor(logRhoIndex);

% Create mask that is false where S is outside the range (1/scale,scale).
phaseCorrMask = false(size(d));
phaseCorrMask((logRhoIndex+1):(end-logRhoIndex+1),:) = true;

% Constrain our search in D to the range 1/scale < S < scale.
d(phaseCorrMask) = 0;

end

function tform = moveTransformationToWorldCoordinateSystem(tform,Rmoving,Rfixed)
% If spatial referencing is specified, we want to output the forward
% transformation that maps points in the world coordinate system of the
% fixed image to points in the world coordinate system of the moving
% image. To accomplish this, observe that the following sequence of
% operations can be used to map world points in moving to world points in
% fixed using a transformation defined in the intrinsic system:
%
% pointsMovingWorld -> tMovingWorldToIntrinsic ->
% tMovingIntrinsicToFixedIntrinsic -> tFixedIntrinsicToWorld
%
%  tMovingIntrinsicToFixedIntrinsic is the output of phase correlation in
% the intrinsic coordinate system.
%
% tMovingWorldToIntrinsic and tFixedIntrinsicToWorld are formed from
% the spatial referencing information in Rmoving,Rfixed.

% NOTE: Transformation matrix computations in this function are performed
% using the post-multiply convention. When the post-multiply matrix is
% assigned to the T property, the A property will be automatically set to
% the documented, pre-multiply form.

Sx = Rmoving.PixelExtentInWorldX;
Sy = Rmoving.PixelExtentInWorldY;
Tx = Rmoving.XWorldLimits(1)-Rmoving.PixelExtentInWorldX*(Rmoving.XIntrinsicLimits(1));
Ty = Rmoving.YWorldLimits(1)-Rmoving.PixelExtentInWorldY*(Rmoving.YIntrinsicLimits(1));
tMovingIntrinsicToWorld = [Sx 0 0; 0 Sy 0; Tx Ty 1];
tMovingWorldToIntrinsic = inv(tMovingIntrinsicToWorld);

Sx = Rfixed.PixelExtentInWorldX;
Sy = Rfixed.PixelExtentInWorldY;
Tx = Rfixed.XWorldLimits(1)-Rfixed.PixelExtentInWorldX*(Rfixed.XIntrinsicLimits(1));
Ty = Rfixed.YWorldLimits(1)-Rfixed.PixelExtentInWorldY*(Rfixed.YIntrinsicLimits(1));
tFixedIntrinsicToWorld = [Sx 0 0; 0 Sy 0; Tx Ty 1];

tMovingIntrinsicToFixedIntrinsic = tform.T;

tComposite = tMovingWorldToIntrinsic * tMovingIntrinsicToFixedIntrinsic * tFixedIntrinsicToWorld; %#ok<MINV>
% We only touch the affine elements of the matrix. Small amounts of
% numeric error can cause the third column to drift from being
% strictly [0;0;1].
tform.T(1:3,1:2) = tComposite(1:3,1:2);

end

%--------------------------------------------
function img = manageWindowing(img,windowing)

if windowing
    img = img .* createBlackmanWindow(size(img));
end

end

%--------------------------------------------
function h = createBlackmanWindow(windowSize)
% Define Blackman window to reduce finite image replication effects in
% frequency domain. Blackman window is recommended in (Stone, Tao,
% McGuire, Analysis of image registration noise due to rotationally
% dependent aliasing).

M = windowSize(1);
N = windowSize(2);




h1 = createBlackmanWindow1D(M);
h2 = createBlackmanWindow1D(N);
h = h1' * h2;

end

%---------------------------------------------
function h = createBlackmanWindow1D(N)
% Define Blackman window to reduce finite image replication effects in
% frequency domain. Blackman window is recommended in (Stone, Tao,
% McGuire, Analysis of image registration noise due to rotationally
% dependent aliasing).

if N == 1
    % Blackman window is NaN for N = 1. Return a value equivalent to no
    % windowing.
    h = 1;

elseif N == 2
    % For N == 2, the customary Blackman window is [0 0] (as computed by
    % the function blackman in Signal Processing Toolbox), or it is [0.0069
    % 0.0069] as computed by the variation of Blackman used here. A 2-point
    % window has no meaningful effect in theory, and in practice these low
    % window values can reduce the working precision, especially in single
    % precision. Instead, return [1 1].
    h = [1 1];

else
    a0 = 7938/18608;
    a1 = 9240/18608;
    a2 = 1430/18608;

    n = 0:(N-1);
    h = a0 - a1*cospi(2*n / (N-1)) + a2*cospi(4*n / (N-1));
end
end

%---------------------------------------------
function H = createHighPassEmphasisFilter(outsize)
% Defines High-Pass emphasis filter used in Reddy and Chatterji

numRows = outsize(1);
numCols = outsize(2);

x = linspace(-0.5,0.5,numCols);
y = linspace(-0.5,0.5,numRows);

[x,y] = meshgrid(x,y);

X = cos(pi*x).*cos(pi*y);

H = (1-X).*(2-X);

end

%----------------------------------------------------------------------
function [moving,fixed,transformType,windowing,method,Rmoving,Rfixed] = parseInputs(varargin)

parser = inputParser();
parser.addRequired('moving',@validateMoving);
parser.addRequired('fixed',@validateFixed);
parser.addOptional('transformType','similarity',@validateTransformType)
parser.addParameter('window',true,@validateWindowing)
parser.addParameter('method','gradcorr', @validateMethod)

supportedImageClasses = {'uint8','uint16','uint32','int8','int16','int32','single','double','logical'};
supportedImageAttributes = {'real','nonsparse','finite', 'nonempty'};

% Use function scope variable to cache specified transformType in
% case user provided partial name.
fullTransformType = '';
fullMethod = "";

[Rmoving,Rfixed,varargin] = preparseSpatialRefObjects(varargin{:});

parser.parse(varargin{:});

moving        = parser.Results.moving;
fixed         = parser.Results.fixed;
windowing     = parser.Results.window;

if ~isempty(fullTransformType)
    % The validation function for the optional argument is not run
    % unless a user actually specifes the transformType. We only
    % want/need to partial string complete in this case.
    transformType = fullTransformType;
else
    transformType = parser.Results.transformType;
end

if fullMethod ~= ""
    method = fullMethod;
else
    method = parser.Results.method;
end

if (method == "gradcorr")
    if isvector(moving) || isvector(fixed)
        error(message("images:imregcorr:gradcorrVectorsNotSupported"))
    end
end

% If we receive a dimensional image and the size of the third
% dimension is 3, we assume we have been given an RGB image. We
% rgb2gray convert so that we can provide a transformation estimate
% based on a grayscale interpretation of the image data.
isRGB = @(img) (ndims(img) == 3) && (size(img,3) == 3);
if isRGB(moving)
    moving = rgb2gray(moving);
end

if isRGB(fixed)
    fixed = rgb2gray(fixed);
end

% Make sure that input image dimensions agree with any specified spatial
% referencing objects.
if ~isempty(Rmoving)
    validateSpatialReferencingAgreementWithImage(moving,Rmoving,'moving');
    validateSpatialReferencingAgreementWithImage(fixed,Rfixed,'fixed');
end

%---------------------------------
    function TF = validateFixed(fixed)

        validateattributes(fixed,supportedImageClasses,supportedImageAttributes,...
            mfilename,'FIXED');

        if ~isImage(fixed)
            error(message('images:imregcorr:invalidImageSize','FIXED'));
        end

        TF = true;

    end

%---------------------------------
    function TF = validateMoving(moving)

        validateattributes(moving,supportedImageClasses,supportedImageAttributes,...
            mfilename,'MOVING');

        if ~isImage(moving)
            error(message('images:imregcorr:invalidImageSize','MOVING'));
        end

        TF = true;

    end

%---------------------------------------------
    function TF = validateTransformType(tformType)

        fullTransformType = validatestring(tformType,{'translation','rigid','similarity'},...
            mfilename,'TRANSFORMTYPE');

        TF = true;

    end

%---------------------------------------------
    function TF = validateMethod(method)

        fullMethod = validatestring(method,["phasecorr","gradcorr"],...
            mfilename,'METHOD');

        TF = true;

    end

%-----------------------------------------------
    function TF = validateWindowing(window)

        validateattributes(window,{'logical','numeric'},{'scalar','finite', 'real', 'nonsparse'},...
            mfilename,'Windowing');

        TF = true;

    end


%--------------------------------------------------------------------
    function validateSpatialReferencingAgreementWithImage(A,RA,inputName)

        if ~sizesMatch(RA,A)
            error(message('images:imregcorr:spatialRefAgreementWithImage','ImageSize',inputName,inputName));
        end

    end

%-----------------------------------------------------------------------
    function [Rmoving,Rfixed,varargin] = preparseSpatialRefObjects(varargin)

        spatialRefPositions   = cellfun(@(c) isa(c,'imref2d'), varargin);
        spatialRef3dPositions = cellfun(@(c) isa(c,'imref3d'), varargin);

        if any(spatialRef3dPositions)
            error(message('images:imregcorr:spatialRefMustBe2D'));
        end

        Rmoving = [];
        Rfixed  = [];

        if ~any(spatialRefPositions)
            return
        end

        if ~isequal(find(spatialRefPositions), [2 4])
            error(message('images:imregcorr:spatialRefPositions'));
        end

        Rmoving = varargin{2};
        Rfixed = varargin{4};
        varargin([2 4]) = [];

    end

    function tf = isImage(im)
        % this function is to check if the input is either RGB or Gray
        % image
        tf = ndims(im)<4 && (size(im,3)==1||size(im,3)==3);
    end

end

% Copyright 2013-2024 The MathWorks, Inc.
