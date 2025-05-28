function checkFillValues(fillValues,inputImage,dimensionality)
%

% Copyright 2019-2020 The MathWorks, Inc.

planeAtATimeProblem = ((dimensionality==2)  && ~ismatrix(inputImage));

scalarFillValuesRequired = ~planeAtATimeProblem;
if scalarFillValuesRequired && ~isscalar(fillValues)
    error(message('images:imwarp:scalarFillValueRequired','''FillValues'''));
end


if planeAtATimeProblem && ~isscalar(fillValues)
    sizeImage = size(inputImage);

    % MxNxP input image is treated as a special case. We allow [1xP] or
    % [Px1] fillValues vector in this case.
    validFillValues = isequal(sizeImage(3:end),size(fillValues)) ||...
        (isequal(ndims(inputImage),3) && isvector(fillValues)...
        && isequal(length(fillValues),sizeImage(3)));

    if ~validFillValues
        error(message('images:imwarp:fillValueDimMismatch','''FillValues''','''FillValues''','A'));
    end
end

end