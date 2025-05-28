function h = fspecial3(varargin) %#codegen
% Copyright 2018 The MathWorks, Inc.

coder.extrinsic('eml_try_catch');

% Check the number of input arguments.
narginchk(1,3);

coder.internal.prefer_const(varargin);

% Determine filter type from the user supplied string and check if constant.
coder.internal.errorIf(~coder.internal.isConst(varargin{1}),...
            'MATLAB:images:validate:codegenInputNotConst','TYPE', ...
            'IfNotConst','Fail');
type = varargin{1};
type = validatestring(type,{'gaussian','sobel','prewitt','laplacian','log',...
    'average','ellipsoid'},mfilename,'TYPE',1);

if ((nargin == 1) ||(nargin==2 && coder.internal.isConst(varargin{2})) || ...
        (nargin==3 && coder.internal.isConst(varargin{2}) && coder.internal.isConst(varargin{3}))) 
    % Constant fold
    [errid,errmsg,h] = eml_const(eml_try_catch('fspecial3',varargin{:}));
    eml_lib_assert(isempty(errmsg),errid,errmsg);
else
    % Generate code
    switch type
        case 'average' % Smoothing filter
            % FSPECIAL3('average',HSIZE)
            coder.internal.errorIf((nargin==3),'images:fspecial3:tooManyArgsForThisFilter');
            Hsize = varargin{2};
            validateattributes(Hsize,{'double'},...
                {'positive','nonsparse','finite','real','nonempty','integer'},...
                mfilename,'HSIZE',2);
            
            coder.internal.errorIf((numel(Hsize) > 3 || numel(Hsize) == 2),'images:fspecial3:wrongSizeHSize');
            if numel(Hsize)==1
                p2 = [Hsize Hsize Hsize];
            else
                p2 = Hsize;
            end
            h = ones(p2(1:3))/prod(p2(1:3));
            
        case 'ellipsoid' % Ellipsoid filter
            % FSPECIAL3('ellipsoid',SEMIAXES)
            coder.internal.errorIf((nargin==3),'images:fspecial:tooManyArgsForThisFilter');
            Hsize = varargin{2};
            validateattributes(Hsize,{'double'},...
                {'positive','nonsparse','finite','real','nonempty','vector'},...
                mfilename,'SEMIAXES',2);
            coder.internal.errorIf((numel(Hsize) > 3 || numel(Hsize) == 2),'images:fspecial3:wrongSizeHSize');
            if numel(Hsize)==1
                p2 = [Hsize Hsize Hsize];
            else
                p2 = Hsize;
            end
            % Variable Size refers to the length of SEMI-AXES values
            xr = p2(2);
            yr = p2(1);
            zr = p2(3);
            % Get the 3D array dimensions = 2*ceil(SEMIAXES)+1
            p2 = ceil(p2);
            xs = p2(2);
            ys = p2(1);
            zs = p2(3);
            [X,Y,Z] = meshgrid(-xs:xs,-ys:ys,-zs:zs);
            h = (1 - X.^2/xr^2 - Y.^2/yr^2 -Z.^2/zr^2) >= 0;
            sumh = mysum(h);
            h = h/sumh;
            
        case 'gaussian' % Gaussian filter
            % FSPECIAL3('gaussian',HSIZE)
            % FSPECIAL3('gaussian',HSIZE,SIGMA)
            if (nargin==2)
                sigma = [1 1 1];                
            elseif (nargin==3)
                sigma = varargin{3};                                            
            end
           [p2,p3] = gaussianArgValidateHelper(varargin{2},sigma);
           logFlag = false;
           h = gaussianHelperAlgo(p2,p3,logFlag);
                        
        case 'laplacian' % Laplacian filter
            % FSPECIAL3('laplacian',GAMMA1) GAMMA2=0
            % FSPECIAL3('laplacian',GAMMA1,GAMMA2)
            if(nargin==2)
                p3 =0;
                p2 = varargin{2};
                validateattributes(p2,{'double'},{'nonnegative','nonsparse','real',...
                'nonempty','finite','scalar','<=',1},...
                mfilename,'GAMMA1',2);
            elseif(nargin==3)
                p2= varargin{2};
                p3= varargin{3};
                validateattributes(p2,{'double'},{'nonnegative','nonsparse','real',...
                    'nonempty','finite','scalar'},...
                    mfilename,'GAMMA1',2);
                validateattributes(p3,{'double'},{'nonnegative','nonsparse','real',...
                    'nonempty','finite','scalar'},...
                    mfilename,'GAMMA2',2);
                coder.internal.errorIf((p2+p3) > 1,'images:fspecial3:outOfRangeSumGamma');               
            end
            h1 = coder.nullcopy(zeros(3,3,3));
            h1(:,:,1) = [0 0 0; 0 1 0; 0 0 0];
            h1(:,:,2) = [0 1 0; 1 -6 1; 0 1 0];
            h1(:,:,3) = h1(:,:,1);
            
            h2 = coder.nullcopy(zeros(3,3,3));
            h2(:,:,1) = [0 1 0; 1 0 1; 0 1 0];
            h2(:,:,2) = [1 0 1; 0 -12 0; 1 0 1];
            h2(:,:,3) = h2(:,:,1);
            h2 = 0.25*h2;
            
            h3 = coder.nullcopy(zeros(3,3,3));
            h3(:,:,1) = [1 0 1; 0 0 0; 1 0 1];
            h3(:,:,2) = [0 0 0; 0 -8 0; 0 0 0];
            h3(:,:,3) = h3(:,:,1);
            h3 = 0.25*h3;
            
            h = (1 - p2 - p3)*h1 + p2*h2 + p3*h3;
            
        
        case 'log' % Laplacian of Gaussian
            % FSPECIAL3('log',Hsize)
            % FSPECIAL3('log',Hsize,SIGMA)
            
            % First calculate General 3D Gaussian
            if (nargin==2)
                sigma = [1 1 1];
            elseif (nargin==3)
                sigma = varargin{3};
            end
            [p2,p3] = gaussianArgValidateHelper(varargin{2},sigma);
            logFlag = true;
            h = gaussianHelperAlgo(p2,p3,logFlag);
        case 'prewitt'
            direction = validatestring(varargin{2},{'X','Y','Z'},mfilename,'DIRECTION',2);
            ht =[ 1 0 -1 ; 1 0 -1 ; 1 0 -1 ];
            h = cat(3,ht,ht,ht);
            if strcmp(direction,'Y')
                h = permute(h,[2 1 3]);
            elseif strcmp(direction,'Z')
                h = permute(h,[3 1 2]);
            end
        case 'sobel'
            direction = validatestring(varargin{2},{'X','Y','Z'},mfilename,'DIRECTION',2);
            h = coder.nullcopy(zeros(3,3,3));
            h(:,:,1) =[1 0 -1; 2 0 -2 ; 1 0 -1];
            h(:,:,2) =2*h(:,:,1);
            h(:,:,3) = h(:,:,1);
            if strcmp(direction,'Y')
                h = permute(h,[2 1 3]);
            elseif strcmp(direction,'Z')
                h = permute(h,[3 1 2]);
            end
    end
end

function [p2,p3] = gaussianArgValidateHelper(varargin)

coder.inline('always');
coder.internal.prefer_const(varargin);

Sigma = varargin{2};
validateattributes(Sigma,{'double'},...
    {'positive','nonsparse','finite','real','nonempty'},...
    mfilename,'SIGMA',3);
coder.internal.errorIf((numel(Sigma) > 3 || numel(Sigma) == 2),'images:fspecial3:wrongSizeSigma');
if numel(Sigma)==1
    p3 = [Sigma Sigma Sigma];
else
    p3 = Sigma;
end

if(isempty(varargin{1}))
    Hsize = 2*ceil(2*Sigma)+1;
else
    Hsize = varargin{1};
end
validateattributes(Hsize,{'double'},...
    {'positive','nonsparse','finite','real','nonempty','integer'},...
    mfilename,'HSIZE',2);
coder.internal.errorIf((numel(Hsize) > 3 || numel(Hsize) == 2),'images:fspecial3:wrongSizeHSize');
if numel(Hsize)==1
    p2 = [Hsize Hsize Hsize];
else
    p2 = Hsize;
end


function [H] = gaussianHelperAlgo(p2,p3,logFlag)

coder.inline('always');
coder.internal.prefer_const(p2,p3,logFlag);

xsize = (p2(2)-1)/2;
ysize = (p2(1)-1)/2;
zsize = (p2(3)-1)/2;
[X,Y,Z] = meshgrid(-xsize:xsize,-ysize:ysize,-zsize:zsize);
xsig2 = p3(2)^2;
ysig2 = p3(1)^2;
zsig2 = p3(3)^2;

arg = -(X.^2/(2*xsig2) + Y.^2/(2*ysig2) + Z.^2/(2*zsig2));
H     = exp(arg);

truncateVal = eps*mymax(H);
if coder.isRowMajor()
    for i=1:p2(1)
        for j=1:p2(2)
            for k=1:p2(3)
                if H(i,j,k) < truncateVal
                    H(i,j,k) = 0;
                end
            end
        end
    end
else
    H(H<truncateVal) = 0;
end
% Normalize Gaussian: Essentially takes care of the constant
% 1/(2pi*sigma)^0.5 term which only normalizes in continuous domain
sumh = mysum(H);
if sumh ~= 0
    H  = H/sumh;
end

if logFlag
    % Calculate Laplacian of Gaussian
    h1 = H.*(X.^2/xsig2^2 + Y.^2/ysig2^2 + Z.^2/zsig2^2 - 1/xsig2 -1/ysig2 -1/zsig2);
    sumh = mysum(h1);
    H  = h1 - sumh/prod(p2(1:3)); % make the filter sum to zero
end

function sumh = mysum(H)
% H is always 3d 
coder.inline('always');
coder.internal.prefer_const(H);

if coder.isRowMajor()
    sumh = sum(sum(sum(H,3),2),1);
else
    sumh = sum(H(:));
end

function maxh = mymax(H)

% H is always 3d 
coder.inline('always');
coder.internal.prefer_const(H);

if coder.isRowMajor()
    max3 = max(H,[],3);
    max2 = max(max3,[],2);
    maxh = max(max2);
else
    maxh = max(H(:));
end
