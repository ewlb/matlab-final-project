function S = qtdecomp(varargin)
%QTDECOMP Quadtree decomposition.
%   QTDECOMP divides a square image into four equal-sized square blocks, and
%   then tests each block to see if meets some criterion of homogeneity. If a
%   block meets the criterion, it is not divided any further. If it does not
%   meet the criterion, it is subdivided again into four blocks, and the test
%   criterion is applied to those blocks. This process is repeated iteratively
%   until each block meets the criterion. The result may have blocks of
%   several different sizes.
%
%   S = QTDECOMP(I) performs a quadtree decomposition on the intensity image
%   I, and returns the quadtree structure in the sparse matrix S. If S(k,m) is
%   nonzero, then (k,m) is the upper-left corner of a block in the
%   decomposition, and the size of the block is given by S(k,m). By default,
%   QTDECOMP splits a block unless all elements in the block are equal.
%
%   S = QTDECOMP(I,THRESHOLD) splits a block if the maximum value of the block
%   elements minus the minimum value of the block elements is greater than
%   THRESHOLD. THRESHOLD is specified as a value between 0 and 1, even if I is
%   uint8, uint16, or int16. If I is uint8, the threshold value you supply is
%   multiplied by 255 to determine the actual threshold to use; if I is
%   uint16, the threshold value you supply is multiplied by 65535. If I is
%   int16, it is converted to uint16 before the decomposition.
%
%   S = QTDECOMP(I,THRESHOLD,MINDIM) will not produce blocks smaller than
%   MINDIM, even if the resulting blocks do not meet the threshold condition.
%
%   S = QTDECOMP(I,THRESHOLD,[MINDIM MAXDIM]) will not produce blocks smaller
%   than MINDIM or larger than MAXDIM. Blocks larger than MAXDIM are split
%   even if they meet the threshold condition. MAXDIM/MINDIM must be a power
%   of 2.
%
%   S = QTDECOMP(I,FUN) uses the function FUN to determine whether to split a
%   block. QTDECOMP calls FUN with all the current blocks of size M-by-M
%   stacked into M-by-M-by-K array, where K is the number of M-by-M
%   blocks. FUN should return a logical K-element vector whose values are 1 if
%   the corresponding block should be split, and 0 otherwise.  FUN must be a
%   FUNCTION_HANDLE.
%
%   Class Support
%   -------------
%   For the syntaxes that do not include a function, the input image can be
%   logical, uint8, uint16, int16, single, or double. For the syntaxes that
%   include a function, the input image can be any class supported by the
%   function. The output matrix is always sparse.
%
%   Example 1:
%   ----------
%  % View the quadtree decomposition of a matrix.
%
%       I = uint8([1 1 1 1 2 3 6 6;...
%            1 1 2 1 4 5 6 8;...
%            1 1 1 1 7 7 7 7;...
%            1 1 1 1 6 6 5 5;...
%            20 22 20 22 1 2 3 4;...
%            20 22 22 20 5 4 7 8;...
%            20 22 20 20 9 12 40 12;...
%            20 22 20 20 13 14 15 16]);
%       S = qtdecomp(I,.05);
%       disp(full(S));
%
%   Example 2:
%   ----------
%   % View the block representation of quadtree decomposition.
%
%   I = imread('liftingbody.png');
%   S = qtdecomp(I,.27);
%   blocks = repmat(uint8(0),size(S));
%   for dim = [512 256 128 64 32 16 8 4 2 1]
%       numblocks = length(find(S==dim));
%       if (numblocks > 0)
%           values = repmat(uint8(1),[dim dim numblocks]);
%           values(2:dim,2:dim,:) = 0;
%           blocks = qtsetblk(blocks,S,dim,values);
%       end
%   end
%   blocks(end,1:end) =1;
%   blocks(1:end,end) = 1;
%   montage({I,blocks})
%
%   See also FUNCTION_HANDLE, QTSETBLK, QTGETBLK.

%   Copyright 1993-2020 The MathWorks, Inc.

% Obsolete syntax:
%   S = QTDECOMP(I,FUN,P1,P2,...) passes P1,P2,..., as additional arguments to
%   FUN.

matlab.images.internal.errorIfgpuArray(varargin{:});
varargin = matlab.images.internal.stringToChar(varargin);
[A, func, params, minDim, maxDim] = ParseInputs(varargin{:});

[M,N] = size(A);
S = zeros(M,N);

% Initialize blocks
S(1:maxDim:M, 1:maxDim:N) = maxDim;

dim = maxDim;
while (dim > minDim)
    % Find all the blocks at the current size.
    [blockValues, Sind] = qtgetblk(A, S, dim);
    if (isempty(Sind))
        % Done!
        break;
    end
    doSplit = feval(func, blockValues, params{:});

    % Record results in output matrix.
    dim = dim/2;
    Sind = Sind(doSplit);
    Sind = [Sind ; Sind+dim ; (Sind+M*dim) ; (Sind+(M+1)*dim)]; %#ok<AGROW>
    S(Sind) = dim;
end

S = sparse(S);

%%%
%%% Subfunction QTDECOMP_Split - the default split tester
%%%
function dosplit = QTDECOMP_Split(A, threshold, dims)

maxVals = max(max(A,[],1),[],2);
minVals = min(min(A,[],1),[],2);
dosplit = (double(maxVals) - double(minVals)) > threshold;

dosplit = (dosplit & (size(A,1) > dims(1))) | (size(A,2) > dims(2));

%%%
%%% Subfunction ParseInputs
%%%
function [A, func, params, minDim, maxDim] = ParseInputs(varargin)

if (nargin == 0)
    error(message('images:qtdecomp:tooFewInputs'))
end

A = varargin{1};
if (ndims(A) > 2)
    error(message('images:qtdecomp:expectedTwoD'))
end
minDim = 1;
maxDim = min(size(A));

if (nargin == 1)
    % qtdecomp(A)

    func = 'QTDECOMP_Split';
    threshold = 0;
    minDim = 1;
    maxDim = min(size(A));
    params = {threshold [minDim maxDim]};

else
    params = varargin(3:end);
    [func,fcnchk_msg] = fcnchk(varargin{2}, length(params));
    if isempty(fcnchk_msg)
        % qtdecomp(A,fun,...)
        % nothing more to do

    else
        if (nargin == 2)
            % qtdecomp(A,threshold)

            func = 'QTDECOMP_Split';
            threshold = varargin{2};
            minDim = 1;
            maxDim = min(size(A));
            params = {threshold [minDim maxDim]};

        elseif (nargin == 3)
            if (length(varargin{3}) == 1)
                % qtdecomp(A,threshold,mindim)

                func = 'QTDECOMP_Split';
                threshold = varargin{2};
                minDim = varargin{3};
                maxDim = min(size(A));
                params = {threshold [minDim maxDim]};

            else
                % qtdecomp(A,threshold,[mindim maxdim])

                func = 'QTDECOMP_Split';
                threshold = varargin{2};
                minDim = min(varargin{3});
                maxDim = max(varargin{3});
                params = {threshold [minDim maxDim]};
            end

        else
            error(message('images:qtdecomp:tooManyInputs'))
        end
    end
end

if (isequal(func, 'QTDECOMP_Split'))
    % Do some error checking on the parameters

    if (threshold < 0)
        error(message('images:qtdecomp:expectedNonnegative'))
    end

    if (any(fix(size(A)./minDim) ~= (size(A)./minDim)))
        error(message('images:qtdecomp:invalidSizeofA', 'minimum'))
    end

    if (any(fix(size(A)./maxDim) ~= (size(A)./maxDim)))
        error(message('images:qtdecomp:invalidSizeofA', 'maximum'))
    end

    % need this syntax of log2.
    [f,~] = log2(maxDim / minDim);
    if (f ~= 0.5)
        error(message('images:qtdecomp:invalidMaxDimOrMinDim'))
    end

    % If the input is uint8, scale the threshold parameter.
    if (isa(A, 'uint8'))
        params{1} = round(255 * params{1});
    elseif isa(A, 'uint16')
        params{1} = round(65535 * params{1});
    elseif isa(A,'int16')
        A = images.internal.builtins.int16touint16(A);
        params{1} = round(65535 * params{1});
    end

    func = @QTDECOMP_Split;
end
