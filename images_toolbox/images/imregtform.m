function tform = imregtform(varargin)

matlab.images.internal.errorIfgpuArray(varargin{:});
parsedInputs = parseInputs(varargin{:});

moving             = parsedInputs.MovingImage;
mref               = parsedInputs.MovingRef;
fixed              = parsedInputs.FixedImage; 
fref               = parsedInputs.FixedRef;
transformType      = parsedInputs.TransformType;
dispOptim          = parsedInputs.DisplayOptimization;
optimObj           = parsedInputs.OptimConfig;
metricConfig       = parsedInputs.MetricConfig;
pyramidLevels      = parsedInputs.PyramidLevels;
initialTrans       = parsedInputs.InitialTransformation;

% Add guards for translation transformation against flat moving or fixed
% images of MattesMutualInformation metric. See g2448730 for additional
% details.
if strcmp(transformType, 'translation') && ...
        isa(metricConfig, 'registration.metric.MattesMutualInformation')
    if isImageFlat(moving) || isImageFlat(fixed)
        warning( message( 'images:regmex:registrationFailedException', ...
                          'InitialTransformation' ) );
                      
        % Returning the initial transformation provided by the user.
        % If no initial transformation is provided, returning the identity.
        if isempty(initialTrans)
            if ismatrix(moving)
                initialTrans = affinetform2d();
            else
                initialTrans = affinetform3d();
            end
        end
        tform = initialTrans;
        return;
    end
end

% Obtain the default optimization parameters and the corresponding scales
[defaultLinearPortionOfTransform, defaultTranslationVector, defaultOptimScales] = ...
    computeDefaultRegmexSettings(transformType,...
    mref,...
    fref);

% Use the defaults transform parameters as initial conditions for the
% optimizer if required.
if (isempty(initialTrans))
    linearPortionOfTransformInit = defaultLinearPortionOfTransform;
    translationVectorInit = defaultTranslationVector; 
else
    [linearPortionOfTransformInit,translationVectorInit] = convertGeotransToRegmexMatrices(initialTrans, transformType);
end

% Set the optimizer scales.
optimObj.Scales = defaultOptimScales;

% Extract required spatial info


if(isa(mref,'imref3d'))
    mspacing = [mref.PixelExtentInWorldX mref.PixelExtentInWorldY mref.PixelExtentInWorldZ];
    [mfirstx, mfirsty, mfirstz] = mref.intrinsicToWorld(1,1,1);
    mfirst   = [mfirstx mfirsty mfirstz];

    fspacing = [fref.PixelExtentInWorldX fref.PixelExtentInWorldY fref.PixelExtentInWorldZ];
    [ffirstx, ffirsty, ffirstz] = fref.intrinsicToWorld(1,1,1);
    ffirst   = [ffirstx ffirsty ffirstz];
    
    moving = permute(moving,[2 1 3]);
    fixed  = permute(fixed,[2 1 3]);
    
else
% assume 2d

    mspacing = [mref.PixelExtentInWorldX mref.PixelExtentInWorldY];
    [mfirstx, mfirsty] = mref.intrinsicToWorld(1,1);
    mfirst   = [mfirstx mfirsty];

    fspacing = [fref.PixelExtentInWorldX fref.PixelExtentInWorldY];
    [ffirstx, ffirsty] = fref.intrinsicToWorld(1,1);
    ffirst   = [ffirstx ffirsty];
    
    moving = moving';
    fixed  = fixed';

end

if ispc
    % Making windows singlethreaded because of multi-threaded performance
    % regressions-g1595217
    numPhysicalCores = 1;
else
    numPhysicalCores = feature('numthreads');
end
    
    
% Cast images to double before handing to regmex.
[linearPortionOfTransform, translationVector] = ...
    images.internal.builtins.reg(...
    double(moving), ...
    mfirst,...
    mspacing,...
    double(fixed),...
    ffirst,...
    fspacing,...
    dispOptim,...
    transformType, ...
    double(linearPortionOfTransformInit), ...
    double(translationVectorInit),...
    optimObj, ...
    metricConfig,...
    pyramidLevels,...
    numPhysicalCores);

% Convert the mex registration parameters to a tform object
tform = convertRegmexMatricesToGeotrans(linearPortionOfTransform, translationVector, transformType);

% If 'InitialTransformation' specified using single precision
% transformation, return a single precision transformation.
if isa(linearPortionOfTransformInit,'single')
    tform.A = single(tform.A);
end

end


function validateSpatialReferencingAgreementWithImage(A,RA,inputName)

if ~sizesMatch(RA,A)
    error(message('images:imregtform:spatialRefAgreementWithImage','ImageSize',inputName,inputName));
end

if (isequal(ndims(A),3) && ~isa(RA,'imref3d'))
    error(message('images:imregtform:volumetricDataRequiresImref3d','RMOVING','RFIXED','imref3d'));
end

end

% Parse inputs
function parsedInputs = parseInputs(varargin)

% We pre-parse spatial referencing objects before we start input parsing so that
% we can separate spatially referenced syntax from other syntaxes. 
[R_moving,R_fixed,varargin] = preparseSpatialRefObjects(varargin{:});

parser = inputParser();

parser.addRequired('MovingImage',  @checkMovingImage);
parser.addRequired('FixedImage',   @checkFixedImage);
parser.addRequired('TransformType',@checkTransform);
parser.addRequired('OptimConfig',  @checkOptim);
parser.addRequired('MetricConfig', @checkMetric);

parser.addParamValue('DisplayOptimization', false, @checkDisplay);
parser.addParamValue('PyramidLevels',3,@checkPyramidLevels);
parser.addParamValue('InitialTransformation',affinetform2d.empty(),@checkInitialTransformation);

% Function scope for partial matching
parsedTransformString = '';

% Parse input, replacing partial name matches with the canonical form.
if (nargin > 5)
  varargin(6:end) = images.internal.remapPartialParamNames({'DisplayOptimization',...
                                                            'PyramidLevels',...
                                                            'InitialTransformation'}, ...
                                                            varargin{6:end});
end

parser.parse(varargin{:});

parsedInputs = parser.Results;

% Make sure that there are enough pixels in the fixed and moving images for
% the number of pyramid levels requested.
validatePyramidLevels(parsedInputs.FixedImage,parsedInputs.MovingImage, parsedInputs.PyramidLevels);

% Allows us to be consistent with rest of toolbox in allowing scalar
% numeric values to be used interchangeably with logicals.
parsedInputs.DisplayOptimization = logical(parsedInputs.DisplayOptimization);

% ensure that the number of dimensions match.
if(ndims(parsedInputs.FixedImage) ~= ndims(parsedInputs.MovingImage))
    error(message('images:imregtform:dimMismatch'));
end

isSpatiallyReferencedSyntax = ~isempty(R_moving);
if isSpatiallyReferencedSyntax
    validateSpatialReferencingAgreementWithImage(parsedInputs.MovingImage,R_moving,'moving');
    validateSpatialReferencingAgreementWithImage(parsedInputs.FixedImage,R_fixed,'fixed');
    parsedInputs.MovingRef = R_moving;
    parsedInputs.FixedRef = R_fixed;
else
    % Create default spatial reference objects
    if(ndims(parsedInputs.MovingImage)==3)
        parsedInputs.MovingRef = imref3d(size(parsedInputs.MovingImage));
        parsedInputs.FixedRef  = imref3d(size(parsedInputs.FixedImage));
    else
        % assume 2D
        parsedInputs.MovingRef = imref2d(size(parsedInputs.MovingImage));
        parsedInputs.FixedRef  = imref2d(size(parsedInputs.FixedImage));
    end
end

% Validate InitialTransformation
validateInitialTransformation(parsedInputs.InitialTransformation,...
                              parsedInputs.MovingImage,...
                              parsedInputs.TransformType)

parsedInputs.TransformType = parsedTransformString;


    function tf = checkPyramidLevels(levels)
        
        validateattributes(levels,{'numeric'},{'scalar','real','positive','nonnan'},'imregtform','PyramidLevels');
        
        tf = true;
        
    end

    function tf = checkOptim(optimConfig)
       
        validOptimizer = isa(optimConfig,'registration.optimizer.RegularStepGradientDescent') ||...
                         isa(optimConfig,'registration.optimizer.GradientDescent') ||...
                         isa(optimConfig,'registration.optimizer.OnePlusOneEvolutionary');
                     
        if ~validOptimizer
           error(message('images:imregtform:invalidOptimizerConfig'))
        end
        tf = true;
        
    end

    function tf = checkMetric(metricConfig)
       
        validMetric = isa(metricConfig,'registration.metric.MeanSquares') ||...
                      isa(metricConfig,'registration.metric.MutualInformation') ||...
                      isa(metricConfig,'registration.metric.MattesMutualInformation');
                  
        if ~validMetric
           error(message('images:imregtform:invalidMetricConfig'))
        end
        tf = true;
        
    end

    function tf = checkFixedImage(img)
        
        validateattributes(img,{'numeric'},...
            {'real','nonempty','nonsparse','finite','nonnan'},'imregtform','fixed',1);
                
        if(ndims(img)>3)
            error(message('images:imregtform:fixedImageNot2or3D'));
        end
        tf = true;
        
    end

    function tf = checkMovingImage(img)
        
        validateattributes(img,{'numeric'},...
            {'real','nonempty','nonsparse','finite','nonnan'},'imregtform','moving',2);

        if(ndims(img)>3)
            error(message('images:imregtform:movingImageNot2or3D'));
        end
        
        
        if (any(size(img)<4))
             error(message('images:imregtform:minMovingImageSize'));
        end
 
        tf = true;
        
    end

    function tf = checkTransform(tform)
        parsedTransformString = validatestring(lower(tform), {'affine','translation','rigid','similarity'}, ...
            'imregtform', 'TransformType');
        
        tf = true;
        
    end

    function tf = checkInitialTransformation(tform)
        % We only use the input parser to do simple type checking on the
        % transformation. We do additional validation on the
        % initialTransformation after the initial call to parse.

        if ~(isa(tform,'images.geotrans.internal.MatrixTransformation') || ...
                isa(tform,'affine2d') || isa(tform,'affine3d'))
            error(message('images:imregtform:invalidInitialTransformationType','affine2d','affine3d'));
        end

        tf = true;

    end
    
    function tf = checkDisplay(TF)
        
        validateattributes(TF,{'logical','numeric'},{'real','scalar'});
        
        tf = true;
        
    end

end


% Validate input pyramid levels against image sizes
function validatePyramidLevels(fixed,moving,numLevels)

requiredPixelsPerDim = 4.^(numLevels-1);

fixedTooSmallToPyramid  = any(size(fixed) < requiredPixelsPerDim);
movingTooSmallToPyramid = any(size(moving) < requiredPixelsPerDim);

if fixedTooSmallToPyramid || movingTooSmallToPyramid
    % Convert dims to strings, since they can be large enough to overflow
    % into a floating point type.
    error(message('images:imregtform:tooSmallToPyramid', ...
                  sprintf('%d', requiredPixelsPerDim), ...                  
                  numLevels));
end

end

function [linearPortionOfTransform,translationVector] = convertGeotransToRegmexMatrices(initialTrans, transformType)
% Convert affine2d/affine3d representation of geometric transformation to
% the form that regmex expects.

d = initialTrans.Dimensionality;

% regmex expects inverse mapping.
if strcmpi(transformType,'translation')
    % If execution reaches here, checks in validateInitialTransformation
    % have already ensured that the initial tform is a valid translation
    % transformation. Since that is the case, we can avoid the possible
    % floating-point roundoff that might occur in matrix inverse by
    % negating the translation component directly. 
    %
    % Use the T property because the initial transformation might be one of
    % the old transformation classes that use a post-multiply T matrix.
    initialTrans.T(d+1,1:d) = -initialTrans.T(d+1,1:d);
else

    initialTrans = invert(initialTrans);
end

% Unpack linear and additive portions of transformation separately.
%
% As explained just above, use the T property.
linearPortionOfTransform = initialTrans.T(1:d,1:d);
translationVector = initialTrans.T(d+1,1:d);

end

function tform = convertRegmexMatricesToGeotrans(linearPortionOfTransform, translationVector, transformType)
% Convert the regmex representation of the separate linear portion of the
% transform and an additive translation vector to a geometric
% transformation object.

% The incoming rotation and translation information aligns the *fixed* to
% the *moving*.

nDims = numel(translationVector);

A = [linearPortionOfTransform.' translationVector.' ; zeros(1,nDims) 1];

switch transformType
    case 'translation'
        if nDims == 2
            tform = transltform2d(A);
        else
            tform = transltform3d(A);
        end

    case 'similarity'
        if nDims == 2
            tform = simtform2d(A);
        else
            try
                tform = simtform3d(A);
            catch
                % In one case, the ITK library routine used by imregtform
                % has been found to return a 3D similarity transformation
                % consisting of a 3D rotation and a negative scale factor.
                % Because a negative scale factor in 3D forces an opposite
                % or reflective similarity in which object orientation is
                % reversed, and because simtform3d does not support that
                % type of similarity, simtform3d throws an error for that
                % case. When this occurs, give an error message indicating
                % that the registration process failed to converge on a
                % valid nonreflective similarity. MathWorks engineers: see
                % g3063313.
                error(message("images:imregtform:similarityConvergenceFailure"))
            end
        end

    case 'rigid'
        if nDims == 2
            tform = rigidtform2d(A);
        else
            tform = rigidtform3d(A);
        end

    case 'affine'
        if nDims == 2
            tform = affinetform2d(A);
        else
            tform = affinetform3d(A);
        end
end

% regmex returns an inverse transformation, so invert the result.
tform = invert(tform);

end

function [Aref,Bref,varargin] = preparseSpatialRefObjects(varargin)

spatialRefPositions   = cellfun(@(c) isa(c,'imref2d') || isa(c,'imref3d'), varargin);

Aref = [];
Bref = [];

if ~any(spatialRefPositions)
    return
end

if ~isequal(find(spatialRefPositions), [2 4])
    error(message('images:imregtform:spatialRefPositions'));
end

Aref = varargin{2};
Bref = varargin{4};
varargin([2 4]) = [];

end

function validateInitialTransformation(tform,movingImage,transformationType)

if isempty(tform)
    return
end

% 2-D InitialTransformation, 3-D problem.
if ( (tform.Dimensionality==2) && (ndims(movingImage)==3) )
    error(message('images:imregtform:invalidInitialTransformDimensionality',...
        'Dimensionality','InitialTransformation','3','MOVING','FIXED','3-D'))
end

% 3-D InitialTransformation, 2-D problem.
if ( (tform.Dimensionality==3) && ismatrix(movingImage) )
    error(message('images:imregtform:invalidInitialTransformDimensionality',...
        'Dimensionality','InitialTransformation','2','MOVING','FIXED','2-D'))
end

% Make sure InitialTransformation state agrees with TransformationType
switch (lower(transformationType))

    case 'translation'

        if ~tform.isTranslation()
            error(message('images:imregtform:invalidInitialTransformation',...
                  'isTranslation', 'InitialTransformation', 'TransformationType', '''translation'''));
        end

    case 'rigid'

        if ~tform.isRigid()
            error(message('images:imregtform:invalidInitialTransformation',...
                  'isRigid', 'InitialTransformation', 'TransformationType', '''rigid'''));
        end

    case 'similarity'

        if ~tform.isSimilarity()
            error(message('images:imregtform:invalidInitialTransformation',...
                  'isSimilarity', 'InitialTransformation', 'TransformationType', '''similarity'''));
        end

    case 'affine'
        % No additional validation needed.

    otherwise
        assert(false, 'Unexpected transformationType.');


end

end

function tf = isImageFlat(im)
% Helper to check if the input image is flat

    tf = all( im(:) == im(1) );
end

% Copyright 2011-2023 The MathWorks, Inc.
