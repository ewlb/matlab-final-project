%ActiveContourEvolver Evolve active contour on an image.
%
%   See also ActiveContourSpeed, ActiveContourSpeedChanVese, ActiveContourSpeedEdgeBased

% Copyright 2023 The MathWorks, Inc.

%#codegen

classdef ActiveContourEvolver

    % ============ PROPERTIES ==============

    properties

        ContourSpeed  % Speed function object
        Image         % Image array

    end

    properties(SetAccess = private)

        NumDimensions % Number of dimensions
        NumChannels % Number of color/texture channels

    end

    properties(Dependent = true)

        ContourState  % Current contour location
        phiTmp
    end

    properties(Hidden, Access = private)

        ImageSize     % Size of the image array (always a 3-element vector)

        neighs
        phi     % Level set matrix
        phiOne
        label
        Lz
        Ln1
        Lp1
        Ln2
        Lp2
        Lin2out
        Lout2in
    end

    properties(Hidden, Access = private, Constant = true)

        c_neighs_2D = [1 0 0; -1 0 0; 0 1 0; 0 -1 0];
        c_neighs_3D = [1 0 0; -1 0 0; 0 1 0; 0 -1 0; 0 0 1; 0 0 -1];

    end

    % ============ METHODS ==============

    methods

        function obj = ActiveContourEvolver(Image, ContourState, ContourSpeed)

            if size(ContourState,3) == 1
                obj.NumChannels = size(Image,3); % Color or texture
            else
                obj.NumChannels = 1; % 3D grayscale
            end
            obj.phi = zeros(coder.ignoreConst(0),coder.ignoreConst(0),coder.ignoreConst(0));
            obj.label = zeros(coder.ignoreConst(0),coder.ignoreConst(0),coder.ignoreConst(0),'int8');
            obj.Lz =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.Ln1 =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.Ln2 =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.Lp1 =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.Lp2 =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.Lin2out =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.Lout2in =struct('idx',zeros(coder.ignoreConst(0),1),'r',zeros(coder.ignoreConst(0),1),'c',zeros(coder.ignoreConst(0),1),'z',zeros(coder.ignoreConst(0),1));
            obj.neighs = zeros(coder.ignoreConst(0),coder.ignoreConst(0));

            if isinteger(Image)
                classVar = zeros(1,'single');
            else
                classVar = zeros(1,'like',Image);
            end
            obj.ContourSpeed = makeEmptyActiveContourSpeedMethod(class(ContourSpeed),classVar);
            obj.Image = Image;
            obj.ContourState = ContourState;
            ContourSpeedOne  = validateContourSpeed(obj.Image,obj.phi,ContourSpeed);
            obj.ContourSpeed = ContourSpeedOne;
        end
        %==================================================================
        function [obj, currentIteration] = moveActiveContour(obj, numIterations, varargin)

            validateattributes(numIterations,{'numeric'},{'nonnan', ...
                'nonsparse','nonempty','finite','integer','scalar','positive'});

            for currentIteration = 1:numIterations

                % Calculate speed
                F = calculateSpeed(obj.ContourSpeed, obj.Image, obj.phi, obj.Lz.idx);

                % Evolve level set
                obj = updateLevelSetSFM(obj, F);

                % Update Energy

                contTmp = obj.ContourSpeed;
                obj.ContourSpeed = updateSpeed(contTmp, obj.Image, ...
                    obj.Lin2out.idx, obj.Lout2in.idx);
                contTmp1 = obj.ContourSpeed;
                ContourSpeedOne  = validateContourSpeed(obj.Image,obj.phi,contTmp1);
                obj.ContourSpeed = ContourSpeedOne;

                if isempty(obj.Lz.idx)
                    coder.internal.warning('images:activecontour:vanishingContour','MASK')
                    break;
                end

            end

        end

        % Set methods
        %==================================================================
        function obj = set.ContourState(obj, ContourState)

            validateattributes(ContourState,{'numeric','logical'},{'nonnan', ...
                'nonsparse','nonempty','real'});



            isImageInPlace = ~isempty(obj.Image);
            className = class(obj.ContourSpeed);
            if strcmp(className,'images.internal.coder.ActiveContourSpeedEdgeBased')
                A = logical(obj.ContourSpeed.smoothfactor);
                B = logical(obj.ContourSpeed.balloonC);
                C = logical(obj.ContourSpeed.advectionC);
                D = logical(obj.ContourSpeed.sigma);
                E = logical(obj.ContourSpeed.lambda);
                F = logical(obj.ContourSpeed.edgeExponent);
            else
                A = logical(obj.ContourSpeed.smoothfactor);
                B = logical(obj.ContourSpeed.balloonweight);
                C = logical(obj.ContourSpeed.foregroundweight);
                D = logical(obj.ContourSpeed.backgroundweight);
                E = false;
                F = false;
            end

            if (A || B || C || D || E || F) == 0
                isContourSpeedInPlace = 0;
            else
                isContourSpeedInPlace = 1;

            end
            sz = size(obj.Image);
            P = isImageInPlace && (obj.NumChannels > 1) && ~isequal(sz(1:2), size(ContourState));
            Q = isImageInPlace && ~(obj.NumChannels > 1) && ~isequal(size(obj.Image), size(ContourState));

            coder.internal.errorIf(P,...
                'images:activecontour:differentMatrixSize',...
                'Image','ContourState');
            coder.internal.errorIf(Q,...
                'images:activecontour:differentMatrixSize',...
                'Image','ContourState');
            coder.internal.errorIf(~isImageInPlace,'images:activecontour:ErrorSettingUpActivecontour');

            % If any regions touch the image border(s), dissociate them
            % from the borders.
            ContourState(1,:,:) = false;
            ContourState(end,:,:) = false;
            ContourState(:,1,:) = false;
            ContourState(:,end,:) = false;
            if obj.NumDimensions > 2 && obj.NumChannels == 1
                ContourState(:,:,1) = false;
                ContourState(:,:,end) = false;
            end

            % Initialize phi, label, and the lists based on initial contour
            obj = initializeLevelSetSFM(obj, ContourState);

            if isImageInPlace && isContourSpeedInPlace
                % Internal image and speed function exist - re-initialize speed function
                obj.ContourSpeed = initalizeSpeed(obj.ContourSpeed, ...
                    obj.Image, obj.phi);
            end

        end
        %==================================================================
        function obj = set.Image(obj, Image)

            validateattributes(Image,{'numeric'},{'finite', 'nonsparse', ...
                'nonempty', 'real'});

            isPhiInPlace = ~isempty(obj.phi); %#ok<MCSUP>
            className = class(obj.ContourSpeed); %#ok<MCSUP>
            if strcmp(className,'images.internal.coder.ActiveContourSpeedEdgeBased')
                A = logical(obj.ContourSpeed.smoothfactor);%#ok<MCSUP>
                B = logical(obj.ContourSpeed.balloonC);%#ok<MCSUP>
                C = logical(obj.ContourSpeed.advectionC);%#ok<MCSUP>
                D = logical(obj.ContourSpeed.sigma);%#ok<MCSUP>
                E = logical(obj.ContourSpeed.lambda);%#ok<MCSUP>
                F = logical(obj.ContourSpeed.edgeExponent);%#ok<MCSUP>
            else
                A = logical(obj.ContourSpeed.smoothfactor);%#ok<MCSUP>
                B = logical(obj.ContourSpeed.balloonweight);%#ok<MCSUP>
                C = logical(obj.ContourSpeed.foregroundweight);%#ok<MCSUP>
                D = logical(obj.ContourSpeed.backgroundweight);%#ok<MCSUP>
                E = false;
                F = false;
            end

            if (A || B || C || D || E || F) == 0
                isContourSpeedInPlace = 0;
            else
                isContourSpeedInPlace = 1;

            end

            coder.internal.errorIf(isPhiInPlace && ~isequal(size(obj.phi), size(Image)),...
                'images:activecontour:differentMatrixSize', ...
                'Image','phi');%#ok<MCSUP>

            obj.NumDimensions = ndims(Image); %#ok<MCSUP>

            ImgSizeOne = size(Image);
            ImgSize=ones(1,3);

            if numel(size(Image)) == 3
                ImgSize(1) = ImgSizeOne(1);
                ImgSize(2) = ImgSizeOne(2);
                ImgSize(3) = ImgSizeOne(3);

            else
                ImgSize(1) = ImgSizeOne(1);
                ImgSize(2) = ImgSizeOne(2);
            end
            if obj.NumDimensions < 3 %#ok<MCSUP>
                obj.ImageSize = [ImgSize(1) ImgSize(2) 1]; %#ok<MCSUP>
            elseif obj.NumChannels > 1 %#ok<MCSUP>
                obj.ImageSize = [ImgSize(1) ImgSize(2) 1]; %#ok<MCSUP>
            else
                obj.ImageSize = [ImgSize(1) ImgSize(2) ImgSize(3)]; %#ok<MCSUP>
            end


            if isinteger(Image)
                ImageOne = single(Image);
            else
                ImageOne = Image;
            end
            obj.Image = ImageOne;

            if isPhiInPlace && isContourSpeedInPlace
                % Speed function and phi exist - re-initialize speed function
                obj.ContourSpeed = initalizeSpeed(obj.ContourSpeed, ...
                    obj.Image, obj.phi);                        %#ok<MCSUP>
            end

        end
        %==================================================================
        function obj = set.NumDimensions(obj, NumDimensions)

            obj.NumDimensions = NumDimensions;
            NumDims = obj.NumDimensions;
            NumChs = obj.NumChannels;%#ok<MCSUP>

            if (NumDims == 2) || (NumChs > 1)
                A = obj.c_neighs_2D;
                obj.neighs = A; %#ok<MCSUP>
            elseif (NumDims == 3) && (NumChs == 1)
                A = obj.c_neighs_3D;
                obj.neighs = A; %#ok<MCSUP>
            end
            P  = ~((NumDims == 2) || (NumChs > 1));
            Q  =~( (NumDims == 3) && (NumChs == 1) );

            coder.internal.errorIf(~(P||Q), ...
                'images:activecontour:mustBe2Dor3D','Image or phi');
        end

        % Get methods
        % -----------
        function ContourState = get.ContourState(obj)

            ContourState = obj.phi < 0; % phi == 0 is not part of the object. It is part of the interface.

        end

    end % End of methods

    methods(Hidden, Access = private)

        function obj = initializeLevelSetSFM(obj, initContour)

            % Creates all the lists for representing the level sets at and around 0.

            obj.phi = zeros(obj.ImageSize,'double');
            obj.label  = zeros(obj.ImageSize,'int8');

            obj.label(initContour) = -3;
            obj.phi(initContour)   = -3;

            obj.label(~initContour) = 3;
            obj.phi(~initContour)   = 3;

            % Find the zero-level sets
            obj.Lz.idx = [];
            obj.Lz.r = [];
            obj.Lz.c = [];
            obj.Lz.z = [];
            if obj.NumDimensions == 3 && obj.NumChannels == 1 % 3D Image
                obj.Lz.idx = find(initContour & (neighL(~initContour) | neighR(~initContour) ...
                    | neighU(~initContour) | neighD(~initContour) | neighF(~initContour) ...
                    | neighB(~initContour)));
            else
                obj.Lz.idx = find(initContour & (neighL(~initContour) | neighR(~initContour) ...
                    | neighU(~initContour) | neighD(~initContour)));
            end
            obj.Lz.idx = unique(obj.Lz.idx);
            [obj.Lz.r, obj.Lz.c, obj.Lz.z] = ind2sub(obj.ImageSize,obj.Lz.idx);
            obj.label(obj.Lz.idx) = 0;
            obj.phi(obj.Lz.idx) = 0;

            % Find the +1 and -1 level sets
            obj.Ln1.idx = []; obj.Ln1.r = []; obj.Ln1.c = []; obj.Ln1.z = [];
            obj.Lp1.idx = []; obj.Lp1.r = []; obj.Lp1.c = []; obj.Lp1.z = [];

            for i = 1:size(obj.neighs,1)
                neighIdx = images.internal.coder.getNeighIdx(obj.neighs(i,:), obj.ImageSize, ...
                    obj.Lz.r, obj.Lz.c, obj.Lz.z);
                idx3n = obj.label(neighIdx) == -3;
                obj.Ln1.idx = [obj.Ln1.idx; neighIdx(idx3n)];
                obj.Ln1.idx = unique(obj.Ln1.idx);
                idx3p = obj.label(neighIdx) == 3;
                obj.Lp1.idx = [obj.Lp1.idx; neighIdx(idx3p)];
                obj.Lp1.idx = unique(obj.Lp1.idx);
            end
            obj.label(obj.Ln1.idx) = -1;
            obj.phi(obj.Ln1.idx)   = -1;
            obj.label(obj.Lp1.idx) = 1;
            obj.phi(obj.Lp1.idx)   = 1;

            [obj.Ln1.r, obj.Ln1.c, obj.Ln1.z] = ind2sub(obj.ImageSize, obj.Ln1.idx);
            [obj.Lp1.r, obj.Lp1.c, obj.Lp1.z] = ind2sub(obj.ImageSize, obj.Lp1.idx);

            % Find the +2 and -2 level sets
            obj.Ln2.idx = []; obj.Ln2.r = []; obj.Ln2.c = []; obj.Ln2.z = [];
            obj.Lp2.idx = []; obj.Lp2.r = []; obj.Lp2.c = []; obj.Lp2.z = [];

            for i = 1:size(obj.neighs,1)
                neighIdx = images.internal.coder.getNeighIdx(obj.neighs(i,:), obj.ImageSize, ...
                    obj.Ln1.r, obj.Ln1.c, obj.Ln1.z);
                idx3n = obj.label(neighIdx) == -3;
                obj.Ln2.idx = [obj.Ln2.idx; neighIdx(idx3n)];
                obj.Ln2.idx = unique(obj.Ln2.idx);
            end
            obj.label(obj.Ln2.idx) = -2;
            obj.phi(obj.Ln2.idx)   = -2;
            for i = 1:size(obj.neighs,1)
                neighIdx = images.internal.coder.getNeighIdx(obj.neighs(i,:), obj.ImageSize, ...
                    obj.Lp1.r, obj.Lp1.c, obj.Lp1.z);
                idx3p = obj.label(neighIdx) == 3;
                obj.Lp2.idx = [obj.Lp2.idx; neighIdx(idx3p)];
                obj.Lp2.idx = unique(obj.Lp2.idx);
            end
            obj.label(obj.Lp2.idx) = 2;
            obj.phi(obj.Lp2.idx)   = 2;

            [obj.Ln2.r, obj.Ln2.c, obj.Ln2.z] = ind2sub(obj.ImageSize, obj.Ln2.idx);
            [obj.Lp2.r, obj.Lp2.c, obj.Lp2.z] = ind2sub(obj.ImageSize, obj.Lp2.idx);

        end
        %==================================================================
        function obj = updateLevelSetSFM(obj, F)

            % Add F to zero-level set of Phi
            oldPhi = obj.phi(obj.Lz.idx);
            obj.phi(obj.Lz.idx) = (F) + oldPhi;

            % Get Lin2out
            obj.Lin2out.idx = []; obj.Lin2out.r = []; obj.Lin2out.c = []; obj.Lin2out.z = [];
            idxNeg2Pos = (oldPhi <= 0) & (obj.phi(obj.Lz.idx) > 0);
            obj.Lin2out = copyPointsToList(obj.Lz, obj.Lin2out, idxNeg2Pos);

            % Get Lout2in
            obj.Lout2in.idx = []; obj.Lout2in.r = []; obj.Lout2in.c = []; obj.Lout2in.z = [];
            idxPos2Neg = (oldPhi > 0)  & (obj.phi(obj.Lz.idx) <= 0);
            obj.Lout2in = copyPointsToList(obj.Lz, obj.Lout2in, idxPos2Neg);

            [obj, Sz, Sn1, Sp1, Sn2, Sp2] = movePointsOutOfLevelSets(obj);

            obj = movePointsIntoLevelSets(obj, Sz, Sn1, Sp1, Sn2, Sp2);

        end

        %==================================================================
        function [obj, Sz, Sn1, Sp1, Sn2, Sp2] = movePointsOutOfLevelSets( ...
                obj)

            % Initialize transition lists
            Sz.idx  = []; Sz.r  = []; Sz.c  = []; Sz.z  = [];
            Sn1.idx = []; Sn1.r = []; Sn1.c = []; Sn1.z = [];
            Sp1.idx = []; Sp1.r = []; Sp1.c = []; Sp1.z = [];
            Sn2.idx = []; Sn2.r = []; Sn2.c = []; Sn2.z = [];
            Sp2.idx = []; Sp2.r = []; Sp2.c = []; Sp2.z = [];

            % Update the zero-level set. F has already been updated as: phi(Lz.idx) = F + phi(Lz.idx);
            p2remove = obj.phi(obj.Lz.idx) > 0.5;
            [obj.Lz, Sp1] = movePointsToList(obj.Lz, Sp1, p2remove);

            p2remove = obj.phi(obj.Lz.idx) < -0.5;
            [obj.Lz, Sn1] = movePointsToList(obj.Lz, Sn1, p2remove);

            % Update -1 level set
            if isempty(obj.Ln1.idx)
                L_neighIdx = zeros(0,1);
            else
                L_neighIdx = zeros(length(obj.Ln1.idx),size(obj.neighs,1));
                parfor i = 1:size(obj.neighs,1)
                    L_neighIdx(:,i) = images.internal.coder.getNeighIdx(obj.neighs(i,:), ...
                        obj.ImageSize, obj.Ln1.r, obj.Ln1.c, obj.Ln1.z);
                end
            end
            phiVals = obj.phi(L_neighIdx);
            phiVals(obj.label(L_neighIdx) < 0) = -3; % Consider only points that have obj.label(q) >= 0. Using -3 instead of NaNs because if there's nothing then it should return -3 because we are going to do max on it.
            M = max(phiVals,[],2);
            isHasLNeigh = M >= -0.5;
            obj.phi(obj.Ln1.idx(isHasLNeigh)) = M(isHasLNeigh) - 1;
            [obj.Ln1, Sn2] = movePointsToList(obj.Ln1, Sn2, ~isHasLNeigh);

            p2remove = obj.phi(obj.Ln1.idx) >= -0.5;
            [obj.Ln1, Sz] = movePointsToList(obj.Ln1, Sz, p2remove);

            p2remove = obj.phi(obj.Ln1.idx) < -1.5;
            [obj.Ln1, Sn2] = movePointsToList(obj.Ln1, Sn2, p2remove);

            % Update +1 level set
            if isempty(obj.Lp1.idx)
                L_neighIdx = zeros(0,1);
            else
                L_neighIdx = zeros(length(obj.Lp1.idx),size(obj.neighs,1));
                parfor i = 1:size(obj.neighs,1)
                    L_neighIdx(:,i) = images.internal.coder.getNeighIdx(obj.neighs(i,:), ...
                        obj.ImageSize, obj.Lp1.r, obj.Lp1.c, obj.Lp1.z);
                end
            end
            phiVals = obj.phi(L_neighIdx);
            phiVals(obj.label(L_neighIdx) > 0) = 3; % Consider only points that have obj.label(q) <= 0.
            M = min(phiVals,[],2);
            isHasLNeigh = M <= 0.5;
            obj.phi(obj.Lp1.idx(isHasLNeigh)) = M(isHasLNeigh) + 1;
            [obj.Lp1, Sp2] = movePointsToList(obj.Lp1, Sp2, ~isHasLNeigh);

            p2remove = obj.phi(obj.Lp1.idx) <= 0.5;
            [obj.Lp1, Sz] = movePointsToList(obj.Lp1, Sz, p2remove);

            p2remove = obj.phi(obj.Lp1.idx) > 1.5;
            [obj.Lp1, Sp2] = movePointsToList(obj.Lp1, Sp2, p2remove);

            % Update -2 level set
            if isempty(obj.Ln2.idx)
                L_neighIdx = zeros(0,1);
            else
                L_neighIdx = zeros(length(obj.Ln2.idx),size(obj.neighs,1));
                parfor i = 1:size(obj.neighs,1)
                    L_neighIdx(:,i) = images.internal.coder.getNeighIdx(obj.neighs(i,:), ...
                        obj.ImageSize, obj.Ln2.r, obj.Ln2.c, obj.Ln2.z);
                end
            end
            phiVals = obj.phi(L_neighIdx);
            phiVals(obj.label(L_neighIdx) < -1) = -3; % Consider only points that have obj.label(q) >= -1. Using -3 instead of NaNs because if there's nothing then it should return -3 because we are going to do max on it.
            M = max(phiVals,[],2);
            isHasLNeigh = M >= -1.5;
            obj.phi(obj.Ln2.idx(isHasLNeigh)) = M(isHasLNeigh) - 1;
            obj.label(obj.Ln2.idx(~isHasLNeigh)) = -3;
            obj.phi(obj.Ln2.idx(~isHasLNeigh)) = -3;
            obj.Ln2 = removePointsFromList(obj.Ln2, ~isHasLNeigh);

            p2remove = obj.phi(obj.Ln2.idx) >= -1.5;
            [obj.Ln2, Sn1] = movePointsToList(obj.Ln2, Sn1, p2remove);

            p2remove = obj.phi(obj.Ln2.idx) < -2.5;
            obj.label(obj.Ln2.idx(p2remove)) = -3;
            obj.phi(obj.Ln2.idx(p2remove)) = -3;
            obj.Ln2 = removePointsFromList(obj.Ln2, p2remove);

            % Update +2 level set
            if isempty(obj.Lp2.idx)
                L_neighIdx = zeros(0,1);
            else
                L_neighIdx = zeros(length(obj.Lp2.idx),size(obj.neighs,1));
                parfor i = 1:size(obj.neighs,1)
                    L_neighIdx(:,i) = images.internal.coder.getNeighIdx(obj.neighs(i,:), ...
                        obj.ImageSize, obj.Lp2.r, obj.Lp2.c, obj.Lp2.z);
                end
            end
            phiVals = obj.phi(L_neighIdx);
            phiVals(obj.label(L_neighIdx) > 1) = 3; % Consider only points that have obj.label(q) <= 1.
            M = min(phiVals,[],2);
            isHasLNeigh = M <= 1.5;
            obj.phi(obj.Lp2.idx(isHasLNeigh)) = M(isHasLNeigh) + 1;
            obj.label(obj.Lp2.idx(~isHasLNeigh)) = 3;
            obj.phi(obj.Lp2.idx(~isHasLNeigh)) = 3;
            obj.Lp2 = removePointsFromList(obj.Lp2, ~isHasLNeigh);

            p2remove = obj.phi(obj.Lp2.idx) <= 1.5;
            [obj.Lp2, Sp1] = movePointsToList(obj.Lp2, Sp1, p2remove);

            p2remove = obj.phi(obj.Lp2.idx) > 2.5;
            obj.label(obj.Lp2.idx(p2remove)) = 3;
            obj.phi(obj.Lp2.idx(p2remove)) = 3;
            obj.Lp2 = removePointsFromList(obj.Lp2, p2remove);

        end
        %==================================================================
        function obj = movePointsIntoLevelSets(obj, Sz, Sn1, Sp1, Sn2, Sp2)

            % Move points into zero-level set
            obj.label(Sz.idx) = 0;
            [~, obj.Lz] = movePointsToList(Sz, obj.Lz, true(size(Sz.idx))); % Sz should be empty after this

            % Move points into -1 level set and ensure -2 neighbors
            obj.label(Sn1.idx) = -1;
            n = length(Sn1.idx);
            if n < 1
                L_neighIdx = zeros(0,1);
            else
                L_neighIdx = zeros(n*size(obj.neighs,1),1);
                for i = 1:size(obj.neighs,1)
                    L_neighIdx(n*(i-1)+1:n*i) = images.internal.coder.getNeighIdx( ...
                        obj.neighs(i,:), obj.ImageSize, Sn1.r, Sn1.c, Sn1.z);
                end
            end
            L_neighIdx = unique(L_neighIdx);
            isHasLNeigh = obj.phi(L_neighIdx) == -3;
            neighIdx = L_neighIdx(isHasLNeigh); % Only those neighbors who have obj.phi == -3.
            origIdx = repmat(Sn1.idx,size(obj.neighs,1),1);
            origIdx = origIdx(isHasLNeigh);
            obj.phi(neighIdx) = obj.phi(origIdx) - 1;
            Sn2 = addNewPointsToList(Sn2,obj.ImageSize,neighIdx);

            [~, obj.Ln1] = movePointsToList(Sn1, obj.Ln1, true(size(Sn1.idx))); % Sn1 should be empty after this

            % Move points into 1 level set and ensure 2 neighbors
            obj.label(Sp1.idx) = 1;
            n = length(Sp1.idx);
            if n < 1
                L_neighIdx = zeros(0,1);
            else
                L_neighIdx = zeros(n*size(obj.neighs,1),1);
                for i = 1:size(obj.neighs,1)
                    L_neighIdx(n*(i-1)+1:n*i) = images.internal.coder.getNeighIdx(...
                        obj.neighs(i,:), obj.ImageSize, Sp1.r, Sp1.c, Sp1.z);
                end
            end
            L_neighIdx = unique(L_neighIdx);
            isHasLNeigh = obj.phi(L_neighIdx) == 3;
            neighIdx = L_neighIdx(isHasLNeigh); % Only those neighbors who have obj.phi == -3.
            origIdx = repmat(Sp1.idx,size(obj.neighs,1),1);
            origIdx = origIdx(isHasLNeigh);
            obj.phi(neighIdx) = obj.phi(origIdx) + 1;
            Sp2 = addNewPointsToList(Sp2,obj.ImageSize,neighIdx);

            [~, obj.Lp1] = movePointsToList(Sp1, obj.Lp1, true(size(Sp1.idx))); % Sp1 should be empty after this

            % Move points into -2 level set
            obj.label(Sn2.idx) = -2;
            [~, obj.Ln2] = movePointsToList(Sn2, obj.Ln2, true(size(Sn2.idx))); % Sn2 should be empty after this

            % Move points into +2 level set
            obj.label(Sp2.idx) = 2;
            [~, obj.Lp2] = movePointsToList(Sp2, obj.Lp2, true(size(Sp2.idx))); % Sp2 should be empty after this

        end

    end % End of methods(Hidden, Access = private)

end % End of class


%==========================================================================

function [fromListOne, toListOne] = movePointsToList(fromList, toList, pnts2move)
% Add points to toList
toListOne = copyPointsToList(fromList, toList, pnts2move);
% Remove points from fromList
fromListOne = removePointsFromList(fromList, pnts2move);
end

%==========================================================================
function toListOne = copyPointsToList(fromList, toList, pnts2move)
% Copy points to toList
toListOne.idx = [toList.idx; fromList.idx(pnts2move)];
toListOne.r = [toList.r; fromList.r(pnts2move)];
toListOne.c = [toList.c; fromList.c(pnts2move)];
toListOne.z = [toList.z; fromList.z(pnts2move)];
end

%==========================================================================
function fromList = removePointsFromList(fromList, pnts2remove)
% Remove points from fromList
fromList.idx(pnts2remove) = []; fromList.r(pnts2remove) = [];
fromList.c(pnts2remove) = []; fromList.z(pnts2remove) = [];
end

%==========================================================================
function pointList = addNewPointsToList(pointList,imgSize,idx)
[r, c, z] = ind2sub(imgSize, idx);
pointList.idx = [pointList.idx; idx];
pointList.r   = [pointList.r; r];
pointList.c   = [pointList.c; c];
pointList.z   = [pointList.z; z];
end

function D = neighD(A)
D = A([2:end end],:,:);
end

function U = neighU(A)
U = A([1 1:end-1],:,:);
end

function L = neighL(A)
L = A(:,[1 1:end-1],:);
end

function R = neighR(A)
R = A(:,[2:end end],:);
end

function F = neighF(A)
F = A(:,:,[1 1:end-1]);
end

function B = neighB(A)
B = A(:,:,[2:end end]);
end

%==========================================================================
function objOne = makeEmptyActiveContourSpeedMethod(className,classVar)
if strcmp(className,'images.internal.coder.ActiveContourSpeedEdgeBased')
    objOne = images.internal.coder.ActiveContourSpeedEdgeBased(0,0,0,0,0,0,classVar);

else
    objOne = images.internal.coder.ActiveContourSpeedChanVese(0,0,0,0,classVar);
end

end

%==========================================================================
function ContourSpeedOne = validateContourSpeed(imageOne,phiOne,ContourSpeed)
coder.inline('always');
coder.internal.prefer_const(imageOne,phiOne,ContourSpeed);
validActiveCountourSpeed = isa(ContourSpeed,'images.internal.coder.ActiveContourSpeed');

isImageInPlace = ~isempty(imageOne);
isPhiInPlace = ~isempty(phiOne);

coder.internal.errorIf(~validActiveCountourSpeed,...
    'images:activecontour:invalidSpeedObject', ...
    'ContourSpeed');
ContourSpeedOne = ContourSpeed;


if isImageInPlace && isPhiInPlace
    % Internal image and phi exist - initialize speed function
    ContourSpeedOne = initalizeSpeed(ContourSpeedOne, ...
        imageOne, phiOne);
end
end