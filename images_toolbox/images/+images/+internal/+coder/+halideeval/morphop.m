function output = morphop(fcnName,input_image,minmax,stre)
%#codegen


%   Copyright 2021-2022 The MathWorks, Inc.
coder.internal.prefer_const(fcnName, stre);

s = size(input_image);
output = coder.nullcopy(zeros(s,'like',input_image));

a = coder.const(sum(stre(:)));
isFull = a>16 && numel(stre)==a;

hCfg = createHalideEvalConfig(fcnName, input_image, isFull);
output = coder.internal.halideEval(hCfg, fcnName, {input_image,minmax,stre}, output);
    
end

function halideEvalConfig = createHalideEvalConfig(fcnName,img,isFull)
%Set Halide Config
coder.extrinsic('matlabroot');
coder.extrinsic('fullfile');
coder.extrinsic('computer');

mlroot = coder.const(matlabroot);
compArch = coder.const(computer('arch'));

generatorDir = coder.const(fullfile(mlroot, 'toolbox', 'images', 'builtins','generators',compArch));


if(ismatrix(img))
    genPath = coder.const(fullfile(generatorDir,'morphop2_halide'));
end

if(ndims(img) == 3)
    if(isFull)
        genPath = coder.const(fullfile(generatorDir,'morphop3_full_halide'));
    else
        genPath = coder.const(fullfile(generatorDir,'morphop3_halide'));
    end
end

halideEvalConfig = coder.internal.halideEvalConfig;

halideEvalConfig.ApiPath = genPath;

%Input image data type mapping for generating appropriate halide implementation
imgType = class(img);
switch imgType
    case 'double'
        halideEvalConfig.GeneratorParameters = 'keyimForType.type=float64';
    case 'single'
        halideEvalConfig.GeneratorParameters = 'keyimForType.type=float32';
    case 'logical'
        halideEvalConfig.GeneratorParameters = 'keyimForType.type=uint8';
    otherwise
        halideEvalConfig.GeneratorParameters = ['keyimForType.type=', imgType];
end

%Function Name to report when error occurs using halideEval.
halideEvalConfig.FunctionName = string(fcnName);
end
