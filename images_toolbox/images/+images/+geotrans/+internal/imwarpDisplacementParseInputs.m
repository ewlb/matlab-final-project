function parsedOutputs = imwarpDisplacementParseInputs(varargin)
% Input parser for imwarp with displacement field as input.

% Copyright 2020 The MathWorks, Inc.

parser = inputParser();
parser.addRequired('InputImage',@validateInputImage);
parser.addRequired('DisplacementField',@validateDfield);
parser.addOptional('InterpolationMethod','linear',@validateInterpMethod);
parser.addParameter('FillValues',0,@validateFillValues);
parser.addParameter('SmoothEdges',false,@validateSmoothEdges);

varargin = remapPartialParamNamesImwarp(varargin{:});

parser.parse(varargin{:});

parsedOutputs = parser.Results;

method = postProcessMethodString(parsedOutputs.InterpolationMethod);

parsedOutputs.InterpolationMethod = method;

displacementFieldDataMismatch = ndims(parsedOutputs.DisplacementField) == 4 &&...
    ismatrix(parsedOutputs.InputImage);
if displacementFieldDataMismatch
    error(message('images:imwarp:displacementField3dData2d'));
end

end

function TF = validateInterpMethod(method)

validatestring(method,...
    {'nearest','linear','cubic','bilinear','bicubic'}, ...
    'imwarp', 'InterpolationMethod');

TF = true;

end

function TF = validateInputImage(img)

allowedTypes = {'logical','uint8', 'uint16', 'uint32', 'int8','int16','int32','single','double'};
validateattributes(img,allowedTypes,...
    {'nonempty','nonsparse','finite','nonnan'},'imwarp','A',1);

TF = true;

end

function TF = validateFillValues(fillVal)

validateattributes(fillVal,{'numeric'},...
    {'nonempty','nonsparse'},'imwarp','FillValues');

TF = true;

end

function TF = validateSmoothEdges(SmoothEdges)
validateattributes(SmoothEdges,{'logical'},...
    {'nonempty','scalar'},'imwarp','SmoothEdges');

TF = true;

end


function TF = validateDfield(t)

    allowedTypes = {'logical','uint8', 'uint16', 'uint32', 'int8','int16','int32','single','double'};
    validateattributes(t,allowedTypes,...
        {'nonempty','nonsparse','finite','nonnan'},'imwarp','D');

    sizetform = size(t);
    valid2DCase = (ndims(t) == 3) && (sizetform(3) == 2);
    valid3DCase = (ndims(t) == 4) && (sizetform(4) == 3);
    if ~(valid2DCase || valid3DCase)
        error(message('images:imwarp:invalidDSize'));
    end

    TF = true;

end

function methodOut = postProcessMethodString(methodIn)

methodIn = validatestring(methodIn,...
    {'nearest','linear','cubic','bilinear','bicubic'});
% We commonly use bilinear and bicubic in IPT, so both names should work
% for 2-D and 3-D input. This is consistent with interp2 and interp3 in
% MATLAB.

keys   = {'nearest','linear','cubic','bilinear','bicubic'};
values = {'nearest', 'linear','cubic','linear','cubic'};
methodMap = containers.Map(keys,values);
methodOut = methodMap(methodIn);

end

function varargin_out = remapPartialParamNamesImwarp(varargin)

varargin_out = varargin;
if (nargin > 2)
    % Parse input, replacing partial name matches with the canonical form.
    varargin_out(3:end) = images.internal.remapPartialParamNames({'OutputView','FillValues','SmoothEdges'}, ...
        varargin{3:end});
end

end