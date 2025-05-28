function [varargout] = imsplit(I)%#codegen
%

% Copyright 2018-2020 The MathWorks, Inc.

validateattributes(I,{'numeric','logical'},{'3d','nonsparse','real','nonempty'},'imsplit','I',1);

numChannels = size(I,3);
nargoutchk(0, numChannels);

if coder.isColumnMajor()
    for i = 1:nargout
        varargout{i} = I(:,:,i);
    end
else
    
    [m,n] = size(I(:,:,1));
   
    for k = 1:nargout
        varargout{k} = coder.nullcopy(zeros(m,n,class(I)));
    end
    
    for i = 1:m
        for j = 1:n
            for k = 1:nargout
                varargout{k}(i,j) = I(i,j,k);
            end
        end
    end
end