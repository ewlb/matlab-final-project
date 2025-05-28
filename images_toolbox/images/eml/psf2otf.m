function otf = psf2otf(varargin)%#codegen
%PSF2OTF Convert point-spread function to optical transfer function.
%  Syntax
%  ------
%
%   OTF = PSF2OTF(PSF)
%   OTF = PSF2OTF(PSF,OUTSIZE)
%
%  Input Specs
%  ------------
%
%  PSF:
%    non-sparse numeric array
%
%  OUTSIZE:
%  positive integer
%
%  Output Specs
%  ------------
%
%  OTF:
%     double

%   Copyright 2022 The MathWorks, Inc.

[psf, psfSize, outSize] = parseInputs(varargin{:});

if  ~all(psf(:)==0)

    % Pad the PSF to outSize
    padSize = outSize - psfSize;
    psf = padarray(psf, padSize, 'post');
    
    % Circularly shift otf so that the "center" of the PSF is at the
    % (1,1) element of the array.
    psf    = circshift(psf,-floor(psfSize/2));

    % Compute the OTF
    otf = double(fftn(psf));

    % Estimate the rough number of operations involved in the
    % computation of the FFT.
    nElem = prod(psfSize);
    nOps  = 0;
    for k=1:ndims(psf)
        nffts = nElem/psfSize(k);
        nOps  = nOps + psfSize(k)*log2(psfSize(k))*nffts;
    end

    % Discard the imaginary part of the psf if it's within roundoff error.
    if max(abs(imag(otf(:))))/max(abs(otf(:))) <= nOps*eps
        otf = double(real(otf));
    end
else
    otf = double(zeros(outSize));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Parse inputs
%%%

function [psf, psfSize, outSize] = parseInputs(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

narginchk(1,2)

% Check validity of the input parameters
% psf can be empty. it treats empty array as the fftn does
coder.internal.errorIf(~isnumeric(varargin{1}) || issparse(varargin{1}),...
    'images:psf2otf:expectedNonSparseAndNumeric');
if ~isa(varargin{1},'double')
    psf = double(varargin{1});
else
    psf = varargin{1};
end

% checks whether input PSF is finite or not
coder.internal.errorIf(~all(isfinite(psf(:))),'images:psf2otf:expectedFinite');

psfSizeOne = size(psf);

if (nargin == 1) || (nargin==2 && isempty(varargin{2}))
    outSizeOne = psfSizeOne;
else
    outSizeOne = varargin{2};
end

% checks the class of outSize
coder.internal.errorIf(nargin ~=1 && ~isa(outSizeOne, 'double'), ...
    'images:psf2otf:invalidType');

% checks whether the outSize is valid or not
cond = ((nargin ~=1) && isa(outSizeOne, 'double') && (any(outSizeOne(:)<0) ||...
    ~isreal(outSizeOne) || all(size(outSizeOne)>1) || ~all(isfinite(outSizeOne(:)))));
coder.internal.errorIf(cond,'images:psf2otf:invalidOutSize');

% checks whether outSize is Smaller than input PSF
if (~isempty(outSizeOne) && ~isempty(psf))
    [psfSize, outSize] = padlength(psfSizeOne, outSizeOne(:).');
    coder.internal.errorIf(any(outSize < psfSize),...
        'images:psf2otf:outSizeIsSmallerThanPsfSize');
else
    psfSize = psfSizeOne;
    outSize = outSizeOne;
end