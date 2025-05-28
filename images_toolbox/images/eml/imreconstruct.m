function im = imreconstruct(marker, mask, varargin) %#codegen
%IMRECONSTRUCT Morphological reconstruction.

% Copyright 2012-2024 The MathWorks, Inc.

%#ok<*EMCA>

%% Input parsing

validateattributes(marker,...
    {'uint8','int8','uint16','int16','uint32','int32','single','double','logical'},...
    {'real','nonsparse', 'nonnan'},...
    'imreconstruct');
validateattributes(mask,...
    {'uint8','int8','uint16','int16','uint32','int32','single','double','logical'},...
    {'real','nonsparse','nonnan'},...
    'imreconstruct');

% marker and mask must be of the same numeric class
coder.internal.errorIf(~isa(marker, class(mask)),...
    'images:imreconstruct:notSameClass');

coder.internal.errorIf(~isequal(size(marker), size(mask)),...
    'images:imreconstruct:notSameSize');

if nargin==3
    conn = varargin{1};
    eml_invariant(eml_is_const(conn),...
        eml_message('images:validate:connNotConst'));
    iptcheckconn(conn,'imreconstruct','CONN',3);
else
    if coder.gpu.internal.isGpuEnabled && (numel(size(marker))==2)
        conn = 8; % Use 8-connectivity if nothing is specified
    else
        conn = conndef(numel(size(marker)), 'maximal');
    end
end

%% Core
connb = images.internal.getBinaryConnectivityMatrix(conn);

singleThread = images.internal.coder.useSingleThread();

if images.internal.coder.isTargetMACA64()
    useSharedLibrary = false;
else
useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() && ...
    coder.const(~singleThread) && ...
    coder.const(~(coder.isRowMajor && numel(size(marker))>2));
end

if (useSharedLibrary)
    % Shared library
    modeFlag           = getModeFlag(marker, connb);

    if(modeFlag==0)
        % Default code path
        fcnName = ['imreconstruct_', images.internal.coder.getCtype(marker)];
        im = images.internal.coder.buildable.ImreconstructBuildable.imreconstructcore(...
            fcnName,...
            marker,...
            mask,...
            ndims(marker),...
            size(marker),...
            connb,...
            ndims(connb),...
            size(connb));

    else
        % IPP code path
        if(islogical(marker))
            % logical and uint8 share the same ipp code paths
            ctype = 'uint8';
        else
            ctype = images.internal.coder.getCtype(marker);
        end
        fcnName = ['ippreconstruct_', ctype];
        im = images.internal.coder.buildable.IppreconstructBuildable.ippreconstructcore(...
            fcnName,...
            marker,...
            mask,...
            size(marker),...
            modeFlag);
    end

else
    if coder.gpu.internal.isGpuEnabled && isscalar(conn) && (numel(size(marker))==2)
        % Call into hand-written gpuArray implementation
        % 2D inputs with conn 8 and 4 are supported

        coder.gpu.internal.includePtx(...
            'toolbox/images/builtins/src/imagesgpudevice/wrapper/imreconstruct_cuda.hpp', ...
            'toolbox/images/builtins/src/imagesgpudevice/ptxfiles/ImreconstructCuda_mw_ptx.cu', ...
            'toolbox/images/builtins/src/imagesgpudevice/wrapper/smemutil.hpp', ...
            'toolbox/images/builtins/src/imagesgpudevice/wrapper/gpu_imreconstruct_types.hpp');

        [imgRows,imgCols] = size(marker);
        im = coder.nullcopy(marker);
        % Make a copy to preserve constness of 'marker' variable
        marker_tmp = marker;
        coder.ceval('imreconstruct_cuda', ...
            coder.ref(marker_tmp(1), 'gpu'), ...
            coder.rref(mask(1), 'gpu'), ...
            uint32(imgRows), uint32(imgCols), ...
            uint64(conn), ...
            coder.ref(im(1),'gpu'));
    else
        if coder.gpu.internal.isGpuEnabled
            % For 3D and unsupported connectivity inputs, throw a warning
            % and generate unoptimized code
            coder.gpu.internal.diagnostic('gpucoder:diagnostic:Imreconstruct3DInput');
        end

        % Portable C code
        im = imreconstructSequentialAlgo(marker, mask, connb);
    end
end

end

%--------------------------------------------------------------------------
function marker = imreconstructSequentialAlgo(marker, mask, nhconn) %#codegen
% Portable C code generating version

if (coder.gpu.internal.isGpuEnabled)
    % Disable kernel creation for this function.
    % CPU code performs significantly better than inferred GPU code
    coder.inline('never');
else
    coder.inline('always');
end
coder.internal.prefer_const(mask);
coder.internal.prefer_const(nhconn);

% for 2D marker, modeFlag could be 4/8 depending on connectivity
% for 3D marker, modeFlag could be 6/18/26 depending on connectivity
% modeFlag will be 0 if custom connectivity matrix is used
modeFlag = images.internal.coder.bwfloodfillGetConnectivity(nhconn, marker);
coder.internal.prefer_const(modeFlag);

% use floodfill for logical marker and connectivity = 4, 8, 6, 18 or 26 for better performance
if (~isrow(marker) && islogical(marker) && modeFlag ~=0)
    if ismatrix(marker)  % call logical 2D flood fill
        marker = images.internal.coder.bwfloodfill2d(mask,modeFlag,"seedImage",marker);
    else  % call logical 3D flood fill
        marker = images.internal.coder.bwfloodfill3d(mask,modeFlag,"seedImage",marker);
    end
    return
end

% Constrain marker to be within the mask
marker(marker>mask) = mask(marker>mask);

np = images.internal.coder.NeighborhoodProcessor(size(marker), nhconn,...
    'NeighborhoodCenter', images.internal.coder.NeighborhoodProcessor.NEIGHBORHOODCENTER.TOPLEFT);
np.updateInternalProperties();

numPixels = coder.internal.indexInt(numel(marker));

% When marker and mark are row vectors, the neighborhood indices must also
% be row vectors.
if isrow(marker)
    % Forward sequential propagation
    for pInd = 1:numPixels
        imnhInds     = np.getNeighborIndices(pInd);
        maxnh        = max(marker(imnhInds'));
        marker(pInd) = min(maxnh,mask(pInd));
    end

    % Stack of pixel locations. Max size is a heuristic.
    locationStack = coder.nullcopy(...
        zeros(1,2*numPixels,coder.internal.indexIntClass()));
    stackTop = coder.internal.indexInt(0);

    % Inverse sequential propagation and stack population
    for pInd = numPixels:-1:1
        imnhInds     = np.getNeighborIndices(pInd);
        maxnh        = max(marker(imnhInds'));
        marker(pInd) = min(maxnh,mask(pInd));

        % Stack
        for ind = 1:numel(imnhInds)
            imnhInd = imnhInds(ind);
            if( marker(imnhInd)<marker(pInd) ...
                    && marker(imnhInd)<mask(imnhInd))
                % push
                stackTop = stackTop+1;
                locationStack(stackTop) = pInd;
                break;
            end
        end

    end
else
    % Forward sequential propagation
    for pInd = 1:numPixels
        imnhInds     = np.getNeighborIndices(pInd);
        maxnh        = max(marker(imnhInds));
        marker(pInd) = min(maxnh,mask(pInd));
    end

    % Stack of pixel locations. Max size is a heuristic.
    locationStack = coder.nullcopy(...
        zeros(1,2*numPixels,coder.internal.indexIntClass()));
    stackTop = coder.internal.indexInt(0);

    % Inverse sequential propagation and stack population
    for pInd = numPixels:-1:1
        imnhInds     = np.getNeighborIndices(pInd);
        maxnh        = max(marker(imnhInds));
        marker(pInd) = min(maxnh,mask(pInd));

        % Stack
        for ind = 1:numel(imnhInds)
            imnhInd = imnhInds(ind);
            if( marker(imnhInd)<marker(pInd) ...
                    && marker(imnhInd)<mask(imnhInd))
                % push
                stackTop = stackTop+1;
                locationStack(stackTop) = pInd;
                break;
            end
        end

    end
end

% Process stack
while(stackTop>0)
    % pop
    pInd = locationStack(stackTop);
    stackTop = stackTop - 1;

    imnhInds = np.getNeighborIndices(pInd);
    for ind = 1:numel(imnhInds)
        imnhInd = imnhInds(ind);
        if(marker(imnhInd) < marker(pInd)...
                && marker(imnhInd) ~= mask(imnhInd))
            marker(imnhInd) = min(marker(pInd), mask(imnhInd));
            % push
            stackTop = stackTop + 1;
            locationStack(stackTop) = imnhInd;
        end
    end
end

end

%--------------------------------------------------------------------------
function modeFlag = getModeFlag(marker, connb)

modeFlag = 0; % Default code-path

% IPP preference obtained and set at compile time
coder.extrinsic('eml_try_catch');
[errid,errmsg, ippFlag] = eml_const(eml_try_catch('iptgetpref', 'UseIppl'));
eml_lib_assert(isempty(errmsg),errid,errmsg);


if (    ippFlag...
        &&...
        ismatrix(marker)...         % 2D
        && (...
        isa(marker,'logical') ||...
        isa(marker,'uint8')   ||...
        isa(marker,'uint16')  ||...
        isa(marker,'single')  ||...
        isa(marker,'double')    ...
        ))

    if( isequal(connb, [ false true false
            true  true true
            false true false]))
        modeFlag = 1;                       % four connectivity
    elseif(isequal(connb, true(3,3)))
        modeFlag = 2;                       % eight connectivity
    end

end

myArchfun = 'computer';
[archErrid, archErrmsg, archStr] = eml_const(eml_try_catch(myArchfun,'arch'));
eml_lib_assert(isempty(archErrmsg),archErrid,archErrmsg);

if(strcmp(archStr,'win32') && isa(marker, 'double'))
    % force default-code path
    modeFlag = 0;
end

end
