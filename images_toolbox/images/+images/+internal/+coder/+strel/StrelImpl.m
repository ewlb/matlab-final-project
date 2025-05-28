classdef StrelImpl %#codegen
    %

    % Copyright 2020 The MathWorks, Inc.
    % StrelImpl create scalar morphological structuring element.
    
    properties
        TypeEnum
        nhood
        height
        Flat
    end
    
    methods(Static, Hidden)
        function obj = makeempty()
            se = images.internal.coder.strel.StrelImpl;
            obj = repmat(se, 0, 0);
        end
    end
    
    methods
        %==================================================================
        % Constructor
        %==================================================================
        function se = StrelImpl(varargin)
            [typeEnum, nhood, height, isFlat] = ...
                parseInputs(varargin{:});
            
            se.TypeEnum = typeEnum;
            se.nhood = nhood;
            se.height = height;
            se.Flat = isFlat;
        end
        
        %==================================================================
        % reflect
        %==================================================================
        function se2 = reflect(se1)
            nhood_local = flip(flip(flip(se1.nhood,3),2),1);
            height_local = flip(flip(flip(se1.height,3),2),1);
            
            size_nhood = size(nhood_local);
            new_size = size_nhood + (rem(size_nhood,2) ~= 1);
            if any(new_size > size_nhood)
                nhood_local = padarray(nhood_local, new_size - size_nhood,0,'post');
                height_local = padarray(height_local, new_size - size_nhood,0,'post');
            end
            
            se2 = images.internal.coder.strel.StrelImpl(se1.TypeEnum, logical(nhood_local), height_local);
        end
        
        %==================================================================
        % translate
        %==================================================================
        function se2 = translate(se1, displacement)
            nhood_local = se1.nhood;
            nhood_dims = coder.internal.ndims(nhood_local);
            displacement_dims = length(displacement);
            
            if (nhood_dims > displacement_dims)
                displacement_ = [displacement, zeros(1,nhood_dims - displacement_dims)];
                num_dims = nhood_dims;
                size_nhood = size(nhood_local);
                
            else
                num_dims = displacement_dims;
                size_nhood = [size(nhood_local), ones(1,displacement_dims - nhood_dims)];
                displacement_ = displacement;
            end
            
            height_local = se1.height;
            idx = find(nhood_local);
            idx = idx(:);
            sub = cell(1,num_dims);
            [sub{:}] = ind2sub(size_nhood, idx);
            center = floor((size_nhood + 1)/2);
            subs = [sub{:}];
            subs = bsxfun(@minus, subs, center);
            subs = bsxfun(@plus, subs, displacement_);
            max_abs_subs = max(abs(subs),[],1);
            new_size = 2*abs(max_abs_subs) + 1;
            new_center = floor((new_size + 1)/2);
            subs = bsxfun(@plus, subs, new_center);
            for k = 1:num_dims
                sub{k} = subs(:,k);
            end
            new_idx = sub2ind(new_size, sub{:});
            new_nhood = zeros(new_size);
            new_height = zeros(new_size);
            new_nhood(new_idx) = 1;
            new_nhood = logical(new_nhood);
            new_height(new_idx) = height_local(idx);
            
            se2 = images.internal.coder.strel.StrelImpl(se1.TypeEnum, new_nhood, new_height);
            
        end
    end
    
end

%--------------------------------------------------------------------------
function [typeEnum, nhood, height, isFlat] = parseInputs(varargin)
narginchk(0,3)
nhood = zeros(coder.ignoreConst(0), ...
    coder.ignoreConst(0), coder.ignoreConst(0), 'logical');
height = zeros(coder.ignoreConst(0), ...
    coder.ignoreConst(0), coder.ignoreConst(0), 'double');

switch nargin
    case 0 % default is arbitrary, nhood = [], height = []
        typeEnum = ARBITRARY;
        nhood = logical([]);
        height = [];
        isFlat = ~any(height(:));
        
    case 1
        typeEnum = ARBITRARY;
        nhood = convertNhoodToLogical(varargin{1});
        height = zeros(size(nhood));
        isFlat = ~any(height(:));
        
    case 2
        typeEnum = varargin{1};
        nhood    = convertNhoodToLogical(varargin{2});
        height   = zeros(size(nhood));
        isFlat   = ~any(height(:));
        
    case 3
        typeEnum = varargin{1};
        nhood    = convertNhoodToLogical(varargin{2});
        height   = varargin{3};
        isFlat   = ~any(height(:));
        
    otherwise %It should be unreachable
        assert(false, 'Incorrect Input Arguments');
        
end
end

%--------------------------------------------------------------------------
function logicalNhood = convertNhoodToLogical(nhood)
coder.inline('always');
if islogical(nhood)
    logicalNhood = nhood;
else
    logicalNhood = cast(nhood, 'logical');
end
end

%--------------------------------------------------------------------------
function strelTypeFlag = ARBITRARY()
coder.inline('always');
strelTypeFlag = int8(2);
end