function Rout = affineOutputView(sizeA,tform,varargin)

inputs = parseInputs(tform,sizeA,varargin{:});

% parseInputs returns the tform as either an affinetform2d or
% affinetform3d object.
tform = inputs.tform;

if tform.Dimensionality == 2
    RA = imref2d(inputs.sizeA);
elseif tform.Dimensionality == 3
    RA = imref3d(inputs.sizeA);
else
    assert(false,'Unexpected Dimensionality');
end

Rout = computeOutputViewPreservingPixelExtent(RA,tform,inputs.BoundsStyle);

end

function Rout = computeOutputViewPreservingPixelExtent(RA,tform,boundsStyle)

if boundsStyle == "SameAsInput"
    Rout = RA;
elseif boundsStyle == "FollowOutput"
    Rout = images.spatialref.internal.applyGeometricTransformToSpatialRef(RA,tform);
elseif boundsStyle == "CenterOutput"
    Rout = centerOutputStyle(RA.ImageSize,RA,getLinearPartOfTransform(tform));
else
    assert(false,'Unexpected Bounds style');
end

end

function Rout = determineOutputBounds(RA,tform)

if tform.Dimensionality == 2
   [XLimits,YLimits] = outputLimits(tform,RA.XWorldLimits,RA.YWorldLimits);
   Rout = imref2d(RA.ImageSize,XLimits,YLimits);
else
    [XLimits,YLimits,ZLimits] = outputLimits(tform,RA.XWorldLimits,RA.YWorldLimits,RA.ZWorldLimits);
    Rout = imref3d(RA.ImageSize,XLimits,YLimits,ZLimits);
end

end

function tformLinear = getLinearPartOfTransform(tform)

if(isa(tform,'affinetform2d')) || isa(tform,'simtform2d') || isa(tform,'rigidtform2d') || isa(tform,'transltform2d')
    tformLinear = tform;
    tformLinear.A(:,3) = [0 0 1]';
else
    tformLinear = tform;
    tformLinear.A(:,4) = [0 0 0 1]';
end

end

function Rout = centerOutputStyle(goalOutputSize,RA,tform)

    XWorldSpan = diff(RA.XWorldLimits);
    YWorldSpan = diff(RA.YWorldLimits);
    
    Rout = determineOutputBounds(RA,tform);
    
    outputCenterX = mean(Rout.XWorldLimits);
    outputCenterY = mean(Rout.YWorldLimits);
    
    if isa(RA,'imref2d')
        XLimits = outputCenterX + [-XWorldSpan/2,XWorldSpan/2];
        YLimits = outputCenterY + [-YWorldSpan/2,YWorldSpan/2];
        Rout = imref2d(goalOutputSize,XLimits,YLimits);
    else
        ZWorldSpan = diff(RA.ZWorldLimits);
        outputCenterZ = mean(Rout.ZWorldLimits);
        XLimits = outputCenterX + [-XWorldSpan/2,XWorldSpan/2];
        YLimits = outputCenterY + [-YWorldSpan/2,YWorldSpan/2];
        ZLimits = outputCenterZ + [-ZWorldSpan/2,ZWorldSpan/2];
        Rout = imref3d(goalOutputSize,XLimits,YLimits,ZLimits);
    end
end


function inputs = parseInputs(varargin)

boundsStyle = "CenterOutput";

parser = inputParser();
parser.addRequired('tform',@validateTform);
parser.addRequired('sizeA',@validateSize);
parser.addParameter('BoundsStyle','CenterOutput',@validateBoundsStyle);

parse(parser,varargin{:});
inputs = parser.Results;
inputs.sizeA = postValidateSize(inputs.tform,inputs.sizeA);

% Return the tform using one of the types introduced in R2022b.
if isa(inputs.tform,"affine2d")
    inputs.tform = affinetform2d(inputs.tform.T');
elseif isa(inputs.tform,"affine3d")
    inputs.tform = affinetform3d(inputs.tform.T');
end

inputs.BoundsStyle = boundsStyle;

    function TF = validateBoundsStyle(val)        
        boundsStyle = validatestring(val,["FollowOutput","SameAsInput","CenterOutput"],...
            'affineOutputView','BoundsStyle');
        
        TF = true;
    end

end

function sizeA = postValidateSize(tform,sizeA)
    
    % Support RGB/multi-channel output of size directly for 2-D images with
    % 2-D transformations.
    if (tform.Dimensionality == 2) && (length(sizeA) == 3)
        sizeA = sizeA(1:2);
    elseif (tform.Dimensionality == 3) && (length(sizeA) == 4)
        sizeA = sizeA(1:3);
    end
    
    if length(sizeA) ~= tform.Dimensionality
       error(message('images:affineOutputView:sizeAndTformDimsDisagree')); 
    end
end

function TF = validateTform(tform)
    
validateattributes(tform,{'affinetform2d','affinetform3d','affine2d','affine3d',...
    'simtform2d','simtform3d','rigidtform2d','rigidtform3d','transltform2d','transltform3d'},...
    {'scalar'},'affineOutputView','tform');

TF = true;

end

function TF = validateSize(sizeA)
    
validateattributes(sizeA,{'uint8','uint16','uint32','int8','int16','int32','single','double'},...
    {'vector','real','positive','nonsparse'},'affineOutputView','sizeA');

TF = true;

end

% Copyright 2019-2022, The MathWorks, Inc.

