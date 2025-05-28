function J = roifilt2(varargin)%#codegen
%ROIFILT2 Filter region of interest.

%   Copyright 2023 The MathWorks, Inc.

[hFilt, JOne, BW, fcnFlag] = parseInputs(varargin{:});

if fcnFlag == true
    % case when J = ROIFILT2(I, BW, 'fun')
    filtI = hFilt(JOne);
    if ~isa(JOne,'double')
        JTemp = double(JOne);
    else
        JTemp = JOne;
    end
    if ~isa(JOne, class(filtI))
        if isreal(filtI)
            J = images.internal.coder.convert2Type(JTemp,class(filtI));
        else
            J = complex(images.internal.coder.convert2Type(JTemp,class(filtI)),0);
        end

    else
        if isreal(filtI)
            J = JTemp;
        else
            J = complex(JTemp,0);
        end
    end

    coder.internal.errorIf(~isequal(size(filtI), size(J)),...
        'images:roifilt2:imageSizeMismatch');
    J(BW) = filtI(BW);
else
    % case when J = ROIFILT2(H,I, BW)
    count = coder.internal.indexInt(0);
    [rows, cols] = size(BW);
    for i = 1:coder.internal.indexInt(rows)
        for j = 1:coder.internal.indexInt(cols)
            if BW(i,j) == 1
                count = count+1;
            end
        end
    end
    k = coder.internal.indexInt(1);
    row = coder.nullcopy(zeros(count,1));
    col = coder.nullcopy(zeros(count,1));
    for i = 1:coder.internal.indexInt(rows)
        for j = 1:coder.internal.indexInt(cols)
            if BW(i,j) == 1
                row(k) = i;
                col(k) = j;
                k=k+1;
            end
        end
    end

    hCols = size(hFilt, 2);
    hRows = size(hFilt, 1);
    jCols = size(JOne, 2);
    jRows = size(JOne, 1);
    colPad = ceil(hCols / 2);
    rowPad = ceil(hRows / 2);
    minCol = max(1, min(col(:)) - colPad);
    minRow = max(1, min(row(:)) - rowPad);
    maxCol = min(jCols, max(col(:)) + colPad);
    maxRow = min(jRows, max(row(:)) + rowPad);

    % perform filtering on y that is cropped to the rectangle.
    inImage = JOne;
    JCrop = JOne(minRow:maxRow, minCol:maxCol);
    BWOne = BW(minRow:maxRow, minCol:maxCol);

    filtI = imfilter(JCrop, hFilt);

    coder.internal.errorIf(~isequal(size(filtI), size(JCrop)),...
        'images:roifilt2:imageSizeMismatch');

    JCrop(BWOne) = filtI(BWOne);
    if minRow ~= 0
        inImage(minRow: maxRow, minCol: maxCol) = JCrop;
        J = inImage;
    else
        J =  JCrop;
    end

end

end
%% parse inputs
%==========================================================================
function [filter, I, mask,flag] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

% check number of inputs
narginchk(3, 3);

if isa(varargin{3},'string') || isa(varargin{3},'char')
    coder.internal.errorIf(isempty(varargin{3}),...
        'images:roifilt2:functionNameMustNotBeEmpty');
    funValidate = varargin{3};
    fun = str2func(varargin{3});
    isFunctionHandleProvided = true;
elseif isa(varargin{3},'function_handle')
    funValidate= func2str(varargin{3});
    fun = varargin{3};
    isFunctionHandleProvided = true;
else
    isFunctionHandleProvided = false;
end

if isFunctionHandleProvided == true
    I = varargin{1};
    validateInImage(varargin{1},'I',1);
    maskOne = varargin{2};
    validateInMask(varargin{2},'MASK',2)
    II = zeros(2,2,'like',varargin{1});
    coder.const(feval(funValidate,II));
    filter = fun;
    flag = true;
else
    filter = varargin{1};
    validateInFilter(varargin{1},'FILTER',1)
    I = varargin{2};
    validateInImage(varargin{2},'I',2);
    maskOne = varargin{3};
    validateInMask(varargin{3},'MASK',3)
    flag = false;
end

coder.internal.errorIf(~ismatrix(I),...
    'images:roifilt2:imageMustBe2D');

if ~islogical(maskOne)
    mask = maskOne ~= 0;
else
    mask = maskOne;
end
coder.internal.errorIf(~isequal(size(mask),size(I)),...
    'images:roifilt2:imageMaskSizeMismatch');
end

%% Validate Inputs
%==========================================================================
function validateInImage(in,inString,n)
validateattributes(in,images.internal.iptnumerictypes, ...
    {'nonsparse'}, mfilename,inString,n);
end

%==========================================================================
function validateInMask(in,inString,n)
validateattributes(in, {'numeric' 'logical'}, {'real' 'nonsparse'}, ...
    mfilename, inString, n);
end

%==========================================================================
function validateInFilter(in,inString,n)
validateattributes(in,{'double'},{'nonsparse'},...
    mfilename,inString,n);
end