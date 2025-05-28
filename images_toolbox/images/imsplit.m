function varargout = imsplit(I)

validateattributes(I,{'numeric','logical'},{'3d','nonsparse','real'},'imsplit','I',1);

numChannels = size(I,3);
nargoutchk(0, numChannels);

for idx = 1:nargout
        varargout{idx} = I(:,:,idx); %#ok<AGROW>
end

%   Copyright 2018-2022 The MathWorks, Inc.
