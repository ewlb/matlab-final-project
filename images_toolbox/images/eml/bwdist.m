function varargout = bwdist(varargin) %#codegen
%BWDIST Distance transform of binary image.

% Copyright 2013-2024 The MathWorks, Inc.

coder.extrinsic('eml_try_catch');

narginchk (1,2);
nargoutchk(1,2);

validateattributes(varargin{1}, {'logical','numeric'}, {'nonsparse', 'real'}, ...
    mfilename, 'BW', 1);

BW = varargin{1}~=0;

if nargin < 2
    method = 'euclidean';
else
    method = validatestring(varargin{2},...
        {'euclidean','cityblock','chessboard','quasi-euclidean'}, ...
        mfilename, 'METHOD', 2);
end
coder.internal.errorIf(~coder.internal.isConst(method),...
    'MATLAB:images:validate:codegenInputNotConst', 'METHOD');

D   = coder.nullcopy(zeros(size(BW),'single'));

% Number of threads (obtained at compile time)
singleThread = images.internal.coder.useSingleThread();

useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries();

if (useSharedLibrary)
    % MATLAB Host Target (PC)
    if strcmp(method,'euclidean')
        if (nargout == 2)
            % If GPU Coder pragma is enabled and input is 3D/2D input.
            % Output is distance-transform and feature-transform
            if (coder.gpu.internal.isGpuEnabled && ndims(BW) <= 3)
                % Call for 'euclidean'
                [D, IDX] = images.internal.coder.gpu.bwdistEuclideanDTFTGPUImpl(BW);
                varargout{1} = D;
                varargout{2} = IDX;
            else
                if (coder.gpu.internal.isGpuEnabled)
                    % If the target is an embedded device, for inputs
                    % dimensionality exceeding 3, no code is generated
                    % and code generation is aborted.

                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(), ...
                        'gpucoder:common:BwdistUnsupportedMultiDimImageError');

                    % If the target is not embedded device, warning is displayed
                    % and C/C++ code is generated.
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedMultiDimImage');
                end

                coder.internal.errorIf(numel(BW)>intmax('uint32'),...
                    'images:bwdist:numelExceededLimit');

                IDX    = coder.nullcopy(zeros(size(BW),'uint32'));

                if(singleThread)
                    [D, IDX] = ...
                        images.internal.coder.buildable.BwdistEDTFTBuildable.bwdist(BW, D, IDX);
                else
                    [D, IDX] = ...
                        images.internal.coder.buildable.BwdistEDTFT_tbb_Buildable.bwdist(BW, D, IDX);
                end

                varargout{1} = sqrt(D);
                varargout{2} = IDX;
            end

        else
            % If GPU Coder pragma is enabled and input is 3D/2D input.
            % Output is distance-transform only
            if (coder.gpu.internal.isGpuEnabled && ndims(BW) <= 3)
                % Call for 'euclidean'
                D = images.internal.coder.gpu.bwdistEuclideanGPUImpl(BW);
                varargout{1} = D;
            else
                if (coder.gpu.internal.isGpuEnabled)
                    % If the target is an embedded device, for inputs
                    % dimensionality exceeding 3, no code is generated
                    % and code generation is aborted.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(), 'gpucoder:common:BwdistUnsupportedMultiDimImageError');
                    % If the target is not embedded device, warning is displayed
                    % and C/C++ code is generated.
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedMultiDimImage');
                end

                if (singleThread)
                    D = ...
                        images.internal.coder.buildable.BwdistEDTBuildable.bwdist(BW, D);
                else
                    D = ...
                        images.internal.coder.buildable.BwdistEDT_tbb_Buildable.bwdist(BW, D);
                end

                varargout{1} = sqrt(D);
            end
        end
    else

        % If GPU Coder pragma is enabled and input is 3D/2D input. 'quasi-euclidean' is not supported for GPU.
        if (coder.gpu.internal.isGpuEnabled && ndims(BW) <= 3 && ~strcmp(method,'quasi-euclidean'))
            % Output is distance-transform
            if(nargout==1)

                if strcmp(method,'cityblock')
                    % Call for 'cityblock'
                    D = images.internal.coder.gpu.bwdistCityblockGPUImpl(BW);
                    varargout{1} = D;
                end

                if strcmp(method,'chessboard')
                    % Call for 'chessboard'
                    D = images.internal.coder.gpu.bwdistChessboardGPUImpl(BW);
                    varargout{1} = D;
                end

                % Output is distance-transform and feature-transform
            else %%(nargout == 2)

                if strcmp(method,'cityblock')
                    % Call for 'cityblock'
                    [D, IDX] = images.internal.coder.gpu.bwdistCityblockDTFTGPUImpl(BW);
                    varargout{1} = D;
                    varargout{2} = IDX;
                end

                if strcmp(method,'chessboard')
                    % Call for 'chessboard'
                    [D, IDX] = images.internal.coder.gpu.bwdistChessboardDTFTGPUImpl(BW);
                    varargout{1} = D;
                    varargout{2} = IDX;
                end
            end
        else

            if (coder.gpu.internal.isGpuEnabled)
                % If input dimensionality exceeds 3, CPU codes will be
                % generated instead of GPU (CUDA) codes.
                if (ndims(BW) > 3)
                    % If target is embedded, error out.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(),'gpucoder:common:BwdistUnsupportedMultiDimImageError');
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedMultiDimImage');
                end
                % Quasi-Euclidean case is not supported for GPU Code
                % generation. Instead CPU (C/C++) code will be generated.
                if strcmp(method,'quasi-euclidean')
                    % If target is embedded, error out.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(),'gpucoder:common:BwdistUnsupportedInputMethodError');
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedInputMethod');
                end
            end

            % Fold the connectivity and weights at compile time.
            myfun = 'images.internal.computeChamferMask';
            [errid,errmsg,weights, conn] = eml_const(...
                eml_try_catch(myfun,numel(size((BW))), method));
            eml_lib_assert(isempty(errmsg),errid,errmsg)

            weights((end+1)/2) = 0.0;

            if(nargout==1)
                D = ...
                    images.internal.coder.buildable.DdistBuildable.bwdist(BW, conn, weights, D);
                varargout{1} = D;
            else
                IDX = coder.nullcopy(zeros(size(BW),'uint32'));
                [D, IDX] = ...
                    images.internal.coder.buildable.DdistBuildable.bwdist(BW, conn, weights, D, IDX);
                varargout{1} = D;
                varargout{2} = IDX;
            end
        end
    end
else % Non-PC Targets

    if strcmp(method,'euclidean')
        if (nargout == 2)
            % If GPU Coder pragma is enabled and input is 3D/2D input.
            % Output is distance-transform and feature-transform
            if (coder.gpu.internal.isGpuEnabled && ndims(BW) <= 3)
                % Call for 'euclidean'
                [D, IDX] = images.internal.coder.gpu.bwdistEuclideanDTFTGPUImpl(BW);
                varargout{1} = D;
                varargout{2} = IDX;
            else
                if (coder.gpu.internal.isGpuEnabled)
                    % If the target is an embedded device, for inputs
                    % dimensionality exceeding 3, no code is generated
                    % and code generation is aborted.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(), ...
                        'gpucoder:common:BwdistUnsupportedMultiDimImageError');

                    % If the target is not embedded device, warning is displayed
                    % and C/C++ code is generated.
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedMultiDimImage');
                end

                coder.internal.errorIf(numel(BW)>intmax('uint32'),...
                    'images:bwdist:numelExceededLimit');

                IDX = coder.nullcopy(zeros(size(BW),'uint32'));

                [D, IDX] = imshared.coder.bwdistEDTFT(BW, D, IDX);

                varargout{1} = sqrt(D);
                varargout{2} = IDX;
            end

        else
            % If GPU Coder pragma is enabled and input is 3D/2D input.
            % Output is distance-transform only
            if (coder.gpu.internal.isGpuEnabled && ndims(BW) <= 3)
                % Call for 'euclidean'
                D = images.internal.coder.gpu.bwdistEuclideanGPUImpl(BW);
                varargout{1} = D;
            else
                if (coder.gpu.internal.isGpuEnabled)
                    % If the target is an embedded device, for inputs
                    % dimensionality exceeding 3, no code is generated
                    % and code generation is aborted.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(), 'gpucoder:common:BwdistUnsupportedMultiDimImageError');
                    % If the target is not embedded device, warning is displayed
                    % and C/C++ code is generated.
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedMultiDimImage');
                end

                D = images.internal.coder.bwdistEDT(BW, D);

                varargout{1} = sqrt(D);
            end
        end
    else

        % If GPU Coder pragma is enabled and input is 3D/2D input. 'quasi-euclidean' is not supported for GPU.
        if (coder.gpu.internal.isGpuEnabled && ndims(BW) <= 3 && ~strcmp(method,'quasi-euclidean'))
            % Output is distance-transform
            if(nargout==1)

                if strcmp(method,'cityblock')
                    % Call for 'cityblock'
                    D = images.internal.coder.gpu.bwdistCityblockGPUImpl(BW);
                    varargout{1} = D;
                end

                if strcmp(method,'chessboard')
                    % Call for 'chessboard'
                    D = images.internal.coder.gpu.bwdistChessboardGPUImpl(BW);
                    varargout{1} = D;
                end

                % Output is distance-transform and feature-transform
            else %%(nargout == 2)

                if strcmp(method,'cityblock')
                    % Call for 'cityblock'
                    [D, IDX] = images.internal.coder.gpu.bwdistCityblockDTFTGPUImpl(BW);
                    varargout{1} = D;
                    varargout{2} = IDX;
                end

                if strcmp(method,'chessboard')
                    % Call for 'chessboard'
                    [D, IDX] = images.internal.coder.gpu.bwdistChessboardDTFTGPUImpl(BW);
                    varargout{1} = D;
                    varargout{2} = IDX;
                end
            end
        else

            if (coder.gpu.internal.isGpuEnabled)
                % If input dimensionality exceeds 3, CPU codes will be
                % generated instead of GPU (CUDA) codes.
                if (ndims(BW) > 3)
                    % If target is embedded, error out.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(),'gpucoder:common:BwdistUnsupportedMultiDimImageError');
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedMultiDimImage');
                end
                % Quasi-Euclidean case is not supported for GPU Code
                % generation. Instead CPU (C/C++) code will be generated.
                if strcmp(method,'quasi-euclidean')
                    % If target is embedded, error out.
                    coder.internal.errorIf(coder.gpu.internal.isEmbeddedTarget(),'gpucoder:common:BwdistUnsupportedInputMethodError');
                    coder.internal.compileWarning('gpucoder:common:BwdistUnsupportedInputMethod');
                end
            end

            % Fold the connectivity and weights at compile time.
            myfun = 'images.internal.computeChamferMask';
            [errid,errmsg,weights, conn] = eml_const(...
                eml_try_catch(myfun,numel(size((BW))), method));
            eml_lib_assert(isempty(errmsg),errid,errmsg)

            weights((end+1)/2) = 0.0;

            if(nargout==1)
                computeFT = false;
                D = images.internal.coder.ddist(BW, conn, weights, ...
                    computeFT, D);

                varargout{1} = D;
            else
                IDX = coder.nullcopy(zeros(size(BW),'uint32'));
                computeFT = true;
                [D, IDX] = images.internal.coder.ddist(BW, conn, weights,...
                    computeFT, D, IDX);

                varargout{1} = D;
                varargout{2} = IDX;
            end
        end
    end
end
