function [movingReg,Rreg] = imregister(varargin)

matlab.images.internal.errorIfgpuArray(varargin{:});
tform = imregtform(varargin{:});

 % Rely on imregtform to input parse and validate. If we were passed
 % spatially referenced input, use spatial referencing during resampling.
 % Otherwise, just use identity referencing objects for the fixed and
 % moving images.
 spatiallyReferencedInput = (isa(varargin{2},'imref2d') && isa(varargin{4},'imref2d')) ||...
     (isa(varargin{2},'imref3d') && isa(varargin{4},'imref3d'));
 if spatiallyReferencedInput
     moving  = varargin{1};
     Rmoving = varargin{2};
     Rfixed  = varargin{4};
 else
     moving = varargin{1};
     fixed = varargin{2};
     if (tform.Dimensionality == 2)
        Rmoving = imref2d(size(moving));
        Rfixed = imref2d(size(fixed));
     else
         Rmoving = imref3d(size(moving));
         Rfixed = imref3d(size(fixed));
     end
 end
 
 % Transform the moving image using the transform estimate from imregtform.
 % Use the 'OutputView' option to preserve the world limits and the
 % resolution of the fixed image when resampling the moving image.
 [movingReg,Rreg] = imwarp(moving,Rmoving,tform,'OutputView',Rfixed, 'SmoothEdges', true);


%   Copyright 2011-2022 The MathWorks, Inc.
