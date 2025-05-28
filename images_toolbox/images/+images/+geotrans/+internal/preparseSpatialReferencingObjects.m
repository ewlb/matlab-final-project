function [R_A,varargin] = preparseSpatialReferencingObjects(varargin)
% Parse spatial referencing object.

% Copyright 2019-2020 The MathWorks, Inc.

if (nargin > 1) && (isa(varargin{2},'imref2d') || isa(varargin{2},'imref3d'))
    validateattributes(varargin{2},{'imref2d','imref3d'},{'scalar','nonempty'},'imwarp','RA');
    R_A = varargin{2};
    varargin(2) = [];
else
    % We don't want to actually assign the default spatial referencing
    % object until the rest of the input arguments have been validated.
    % Assign empty spatial referencing arguments as a flag that we need to
    % assign the identity spatial referencing object after input
    % parsing/validation has finished.
    tform = varargin{2};
    validateTform(tform);
    if (tform.Dimensionality == 2)
        R_A = imref2d.empty();
    else
        R_A = imref3d.empty();
    end

end

end

function TF = validateTform(t)

validateattributes(t,{'images.geotrans.internal.GeometricTransformation'},{'scalar','nonempty'},'imwarp','tform');

TF = true;

end