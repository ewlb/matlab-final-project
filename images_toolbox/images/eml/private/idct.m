function a = idct(b,n)%#codegen
%IDCT Inverse discrete cosine transform.

%   Copyright 2023 The MathWorks, Inc.

if ~isa(b, 'double')
    bDouble = double(b);
else
    bDouble = b;
end

if min(size(bDouble)) == 1
    if size(bDouble,2) > 1
        doTrans = 1;
    else
        doTrans = 0;
    end
    bDoubleOne = bDouble(:);
else
    doTrans = 0;
    bDoubleOne = bDouble;
end
nRows = size(bDoubleOne,1);
nCols = size(bDoubleOne,2);
if nargin == 1
    n = nRows;
end
m = nCols;

% Pad or truncate b if necessary
if nRows < n
    bb = zeros(n,m,'like',bDoubleOne);
    bb(1:nRows,:) = bDoubleOne;
else
    bb = bDoubleOne(1:n,:);
end

if rem(n,2)==1 || ~isreal(bDoubleOne) % odd case
    % Form intermediate even-symmetric matrix.
    ww = sqrt(2*n) * exp(1i*(0:n-1)*pi/(2*n)).';
    ww(1) = ww(1) * sqrt(2);
    W = ww(:,ones(1,m));
    yy = zeros(2*n,m,'like',W);
    yy(1:n,:) = W.*bb;
    yy(n+2:n+n,:) = -1i*W(2:n,:).*flipud(bb(2:n,:));

    y = ifft(yy);

    % Extract inverse DCT
    aOut = y(1:n,:);

else % even case
    % Compute precorrection factor
    ww = sqrt(2*n) * exp(1i*pi*(0:n-1)/(2*n)).';
    ww(1) = ww(1)/sqrt(2);
    W = ww(:,ones(1,m));

    % Compute x tilde using equation (5.93) in Jain
    y = ifft(W.*bb);

    % Re-order elements of each column according to equations (5.93) and
    % (5.94) in Jain
    aOut = zeros(n,m,'like',y);
    aOut(1:2:n,:) = y(1:n/2,:);
    aOut(2:2:n,:) = y(n:-1:n/2+1,:);
end

if isreal(bDoubleOne)
    aTemp = real(aOut);
else
    aTemp = aOut;
end

if doTrans
    a = aTemp.';
else
    a = aTemp;
end