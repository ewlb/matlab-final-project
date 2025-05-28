function d = bwdistEDT(BW,d) %#codegen
% bwdistEDT - Euclidean distance transform 

inputSize = size(BW);
numDims = numel(size(BW));

if numel(BW) == 0
    d = single(BW);
    return
end

d = bwdistEDTRecursive(BW, inputSize, numDims, d);

% If first element is still -1 after processing, there are no feature points.
% Set output matrix elements to Inf.
if (d(1) == -1)
    for k = 1:numel(BW)
        if coder.target('MATLAB')
            d(k) = Inf('single');
        else
            d(k) = coder.internal.inf('single');
        end
    end
end

end

function d = bwdistEDTRecursive(BW, inputSize, numDims, d)

numElems = 1;
cumProd = coder.nullcopy(zeros(numDims,1));
for k = 1:numDims
    numElems = numElems * inputSize(k);
    cumProd(k) = numElems;
end

if (numDims == 1 || isscalar(BW))
    d = calcD0(BW, numel(BW), d);
else
    lengthDimN = inputSize(numDims);
    if (numDims == 2) % 2-D
        for k = 1:lengthDimN
            d = calcFirstPassD1(BW, inputSize(1), inputSize(1), k, d);
        end
    else % N-D
        inputDimsMinusOne = numDims-1;
        elementsLow = cumProd(numDims-1);
        
        % Copy (N-1)-D data to temp vars.
        for k = 1:lengthDimN
            % Compute (N-1)-D distance transform and closest feature transform
            inputIndices = coder.internal.indexPlus(coder.internal.indexTimes(coder.internal.indexMinus(k,1),elementsLow),1):coder.internal.indexTimes(k,elementsLow);
            d(inputIndices) = ...
                bwdistEDTRecursive(BW(inputIndices), inputSize, inputDimsMinusOne, d(inputIndices));
        end
    end
    
    % Process dimension N
    d = processDimN(inputSize, numDims, d);
end

end


function D = calcD0(BW, vectorLength, D)

% Create temporary vectors to store local copy of column or row vector
D0 = coder.nullcopy(zeros(vectorLength,1,class(D)));
% Initialize D0 - Feature points get set to zero, -1 otherwise
% Initialize F0 - Feature points get set to linear index, 0 otherwise
for k = 1:vectorLength
    if BW(k)
        D0(k) = single(0);
    else
        D0(k) = single(-1);
    end
end

% Create temporary working vectors fro voronoi generation
g = zeros(vectorLength,1,class(D));
h = zeros(vectorLength,1,class(D));

% Process D0 and F0
D0 = voronoiEDT(g, h, D0);

% Copy results to current N-D distance transform and closest feature transform
for k = 1:vectorLength
    D(k) = D0(k);
end

end

function D = calcFirstPassD1(BW, vectorLength, nrows, col, D)

% Create temporary vectors to store local copy of column vector
D1 = coder.nullcopy(zeros(vectorLength,1,class(D)));

% Initialize D1 - Feature points get set to zero, -1 otherwise
% Initialize F1 - Feature points get set to linear index, 0 otherwise
for k = 1:vectorLength
    if BW((col-1)*nrows+k) == 1
        D1(k) = single(0);
    else
        D1(k) = single(-1);
    end
end

% Create temporary working vectors fro voronoi generation
g = zeros(vectorLength,1,class(D));
h = zeros(vectorLength,1,class(D));

% Process column
D1 = voronoiEDT(g, h, D1);

% Copy results to current N-D distance transform and closest feature transform
for k = 1:vectorLength
    D((col-1)*nrows+k) = D1(k);
end

end

function D = voronoiEDT(g, h, D)
% Note: g and h are working vectors allocated in calling function

[ns, D, g, h] = constructPartialVoronoi(D, g, h);
if (ns == 0)
    return;
end

D = queryPartialVoronoi(g, h, ns, D);

end

function  [el, D, g, h] = constructPartialVoronoi(D, g, h)

% Construct partial voronoi diagram (see Maurer et al., 2003, Figs. 3 & 5, lines 1-14)
% Note: short variable names are used to mimic the notation of the paper

el = 0;
vectorLength = numel(D);
for k = 1:vectorLength
    dk = D(k);
    if (dk ~= single(-1))
        if (el < 2)
            el = el + 1;
            g(el) = dk;
            h(el) = single(k);
        else
            while ( (el >= 2) && removeEDT(g(el-1), g(el), dk, h(el-1), h(el), single(k)) )
                el = el - 1;
            end
            el = el + 1;
            g(el) = dk;
            h(el) = single(k);
        end
    end
end

end

function canRemove = removeEDT(du, dv, dw, u, v, w)

a = v - u;
b = w - v;
c = w - u;

% See Eq. 2 from Maurer et al., 2003
canRemove = ((c * dv) - (b * du) - (a * dw)) > (a * b * c);

end


function D = queryPartialVoronoi(g, h, ns, D)

% Query partial Voronoi diagram (see Maurer et al., 2003, Figs. 4 & 5, lines 18-24)
el = 1;
vectorLength = numel(D);
for k = 1:vectorLength
    while ( (el < ns) && ((g(el) + ((h(el) - k)*(h(el) - k))) > (g(el+1) + ((h(el+1) - k)*(h(el+1) - k)))) )
        el = el + 1;
    end
    D(k) = g(el) + (h(el) - k)*(h(el) - k);
end

end

function D = processDimN(inputSize, numDims, D)

% Create temporary vectors for processing along dimension N
vectorLength = inputSize(numDims);

m = 1;
n = 1;
nvectors = getNumberOfVectorsAtDimN(inputSize, numDims);

if (numDims == 2)
    linearIndexSerial = coder.nullcopy(zeros(vectorLength,1,coder.internal.indexIntClass));
    dVectorSerial = coder.nullcopy(zeros(vectorLength,1,'single'));
    gSerial = zeros(vectorLength,1,'single');
    hSerial = zeros(vectorLength,1,'single');
    
    for k = 1:nvectors
        linearIndexSerial = get2DLinearIndices(inputSize(1), k, linearIndexSerial);
        D = updateEDT(dVectorSerial, linearIndexSerial, gSerial, hSerial, D);
    end
else
    linearIndex = coder.nullcopy(zeros(vectorLength,1,coder.internal.indexIntClass));
    dVector = coder.nullcopy(zeros(vectorLength,1,'single'));
    g = zeros(vectorLength,1,'single');
    h = zeros(vectorLength,1,'single');
    
    for k = 1:nvectors
        linearIndex = getNDLinearIndices(nvectors, inputSize(1), m, n, linearIndex);
        if (mod(m,inputSize(1)) == 0)
            n = n + 1;
            m = 1;
        else
            m = m + 1;
        end
        D = updateEDT(dVector, linearIndex, g, h, D);
    end
end

end


function linearIndex = get2DLinearIndices(nrows, m, linearIndex)

for k = 1:numel(linearIndex)
    linearIndex(k) = ((k-1)*nrows + m);
end

end

function linearIndex = getNDLinearIndices(nvectors, nrows, m, n, linearIndex)

for k = 1:numel(linearIndex)
    linearIndex(k) = (k-1)*nvectors + (n-1)*nrows + m;
end

end

function nvectors = getNumberOfVectorsAtDimN(input_size, num_dims)

% Compute # of vectors at dimension N
nvectors = 1;
for d = 1:num_dims-1
    nvectors = nvectors * input_size(d);
end

end

function D = updateEDT(dVector, linearIndex, g, h, D)

vectorLength = numel(dVector);
% Populate temp vectors
for k = 1:vectorLength
    dVector(k) = D(linearIndex(k));
end

% Process vector
dVector = voronoiEDT(g, h, dVector);

% Copy results to current N-D distance transform and closest feature transform
for k = 1:vectorLength
    D(linearIndex(k)) = dVector(k);
end

end
