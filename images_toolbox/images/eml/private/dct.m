function b = dct(a,n) %#codegen
%DCT Discrete cosine transform.

%   Copyright 2023 The MathWorks, Inc.

if ~isa(a, 'double')
    aDouble = double(a);
else
    aDouble = a;
end

if min(size(aDouble)) == 1
    if size(aDouble,2) > 1
        doTrans = 1;
    else
        doTrans = 0;
    end
    aDoubleOne = aDouble(:);
else
    doTrans = 0;
    aDoubleOne = aDouble;
end

nRows = size(aDoubleOne,1);
nCols = size(aDoubleOne,2);

if nargin == 1
    n = nRows;
end
m = nCols;

% Pad or truncate a if necessary
if nRows < n
    aa = zeros(n,m,'like',aDoubleOne);
    aa(1:nRows,:) = aDoubleOne;
else
    aa = aDoubleOne(1:n,:);
end

mm = ones(1,m);

if ((rem(n,2) == 1) || (~isreal(aDoubleOne))) % odd case
    % Form intermediate even-symmetric matrix.
    y = zeros(2*n,m,'like',aa);
    y(1:n,:) = aa;
    y(n+1:n+n,:) = flipud(aa);

    % Perform FFT
    yy = fft(y);

    % Compute DCT coefficients
    ww = (exp(-1i*(0:n-1)*pi/(2*n))/sqrt(2*n)).';
    ww(1) = ww(1) / sqrt(2);

    bOut = ww(:,mm).*yy(1:n,:);

else % even case

    % Re-order the elements of the columns of x
    y = [ aa(1:2:n,:); aa(n:-2:2,:) ];

    % Compute weights to multiply DFT coefficients
    ww = 2*exp(-1i*(0:n-1)'*pi/(2*n))/sqrt(2*n);
    ww(1) = ww(1) / sqrt(2);
    W = ww(:,mm);

    % Compute DCT using equation (5.92) in Jain
    bOut = W .* fft(y);
end

if isreal(aDoubleOne)
    bTemp = real(bOut);
else
    bTemp = bOut;
end
if doTrans
    b = bTemp.';
else
    b = bTemp;
end
