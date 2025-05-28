function perm = permuteFormattedDims(input,dims) %#codegen
% The permutation applied to input based on the dims vector passed into it.
% input is an unformatted dlarray or a numeric array, and dims represents its
% data format. No input checking, this subfunction assumes that
% dlarray(input, dims) has already been called successfully.

dims = char(dims);

if isscalar(dims)
    % This is only possible if input is a vector, otherwise dlarray
    % constructor would have errored
    if iscolumn(input) 
        perm = [1 2];
    else
        % input has no labels, so ndims is the only non-singleton dimension
        % of input
        dim = ndims(input);
        % Permutation that makes input a column vector
        perm = [dim 1:dim-1];
    end
else
    % Index w.r.t the order of dimensions array for each dimension label
    [~, dimInd] = ismember(dims, 'SCBTU');
    
    % Sort by index
    [~, perm] = sort(dimInd);
end
