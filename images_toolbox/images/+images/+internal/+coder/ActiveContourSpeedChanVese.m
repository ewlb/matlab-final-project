%ActiveContourSpeedChanVese Speed function for Chan-Vese model.
%
%   See also ActiveContourEvolver, ActiveContourSpeed, ActiveContourSpeedEdgeBased

% Copyright 2023-2024 The MathWorks, Inc.

%#codegen

classdef ActiveContourSpeedChanVese < images.internal.coder.ActiveContourSpeed

    properties

        smoothfactor
        foregroundweight
        backgroundweight
        balloonweight

    end

    properties(Access = 'private')

        inMean
        outMean
        inArea
        outArea
        sizePhi
        isColor

    end

    methods

        function obj = ActiveContourSpeedChanVese(smoothfactor, balloonweight, foregroundweight, backgroundweight,classVar)

            obj.smoothfactor = smoothfactor;
            obj.balloonweight = balloonweight;
            obj.foregroundweight = foregroundweight;
            obj.backgroundweight = backgroundweight;
            obj.isColor = false;
            obj.inMean = zeros(1,coder.ignoreConst(0),'like',classVar);
            obj.outMean = zeros(1,coder.ignoreConst(0),'like',classVar);
            obj.inArea= zeros(1,1,'like',classVar);
            obj.outArea= zeros(1,1,'like',classVar);
        end

        %==================================================================
        function obj = initalizeSpeed(obj,I,phi)

            obj.sizePhi = size(phi,3);
            obj.isColor = size(I,3) ~= size(phi,3);
            sz = size(I);
            phisz = size(phi);

            if ~isequal(sz(1),phisz(1)) || ~isequal(sz(2),phisz(2))
                coder.internal.error('images:activecontour:differentMatrixSize','I','PHI');
            end

            if obj.isColor
                numChannels = size(I,3);
            else
                numChannels = 1;
            end
            [obj.inArea,obj.outArea,obj.inMean,obj.outMean] = ...
                chanVeseInitializeSpeed(I,phi,sz,numChannels);
        end
        %=================================================================
        function F = calculateSpeed(obj, I, phi, pixIdx)

            if isempty(pixIdx)
                if isa(I,'single')
                    F = single(pixIdx);
                else
                    F = pixIdx;
                end
                return;
            end

            sz = ones(1,3);
            if obj.isColor
                if numel(size(I)) == 3
                    sz(1) = size(I,1);
                    sz(2) = size(I,2);
                    sz(3) = size(I,3);
                else
                    sz(1) = size(I,1);
                    sz(2) = size(I,2);
                end
                I = reshape(I,[sz(1)*sz(2),sz(3)]);

                I_idx = I(pixIdx,:);

                K = ((obj.foregroundweight*((I_idx - obj.inMean).^2))/sz(3)) - ...
                    ((obj.backgroundweight*((I_idx - obj.outMean).^2))/sz(3));
                F = sum(K,2);
            else
                I_idx = I(pixIdx);
                F = (obj.foregroundweight*((I_idx - obj.inMean).^2)) - ...
                    (obj.backgroundweight*((I_idx - obj.outMean).^2));

            end

            F = F/max(abs(F));
            curvature = images.internal.coder.calculateCurvature(phi, pixIdx);
            curvature = curvature/max(abs(curvature));
            F = F + (obj.smoothfactor)*curvature + obj.balloonweight;

            % Normalization
            % Since balloon weight is completely unbounded, we take abs to
            % ensure that a positive factor is added to the normalization
            % factor.
            F = F/(1 + obj.smoothfactor + abs(obj.balloonweight));

        end
        %==================================================================
        function obj = updateSpeed(obj, I, idxLin2out, idxLout2in)
            sz = ones(1,3);
            if obj.isColor
                if numel(size(I)) == 3
                    sz(1) = size(I,1);
                    sz(2) = size(I,2);
                    sz(3) = size(I,3);
                else
                    sz(1) = size(I,1);
                    sz(2) = size(I,2);
                end
                % sz = size(I);
                I = reshape(I,[sz(1)*sz(2),sz(3)]);
                I_Lin2out = I(idxLin2out,:);
                I_Lout2in = I(idxLout2in,:);
            else
                I_Lin2out = I(idxLin2out);
                I_Lout2in = I(idxLout2in);
            end

            % Handle points going in2out
            sumPnts = sum(I_Lin2out);
            tempSum = (obj.inMean*obj.inArea) - sumPnts;
            obj.inArea = obj.inArea - length(I_Lin2out);
            obj.inMean = tempSum/obj.inArea;
            tempSum = (obj.outMean*obj.outArea) + sumPnts;
            obj.outArea = obj.outArea + length(I_Lin2out);
            obj.outMean = tempSum/obj.outArea;

            % Handle points going out2in
            sumPnts = sum(I_Lout2in);
            tempSum = (obj.outMean*obj.outArea) - sumPnts;
            obj.outArea = obj.outArea - length(I_Lout2in);
            obj.outMean = tempSum/obj.outArea;
            tempSum = (obj.inMean*obj.inArea) + sumPnts;
            obj.inArea = obj.inArea + length(I_Lout2in);
            obj.inMean = tempSum/obj.inArea;

        end

        % Set methods
        % -----------
        function obj = set.smoothfactor(obj,smoothfactorValue)
            validateattributes(smoothfactorValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.smoothfactor = double(smoothfactorValue);
        end

        function obj = set.balloonweight(obj,balloonweightValue)
            validateattributes(balloonweightValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'scalar','nonnan','finite'});
            obj.balloonweight = double(balloonweightValue);
        end

        function obj = set.foregroundweight(obj,foregroundweightValue)
            validateattributes(foregroundweightValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.foregroundweight = double(foregroundweightValue);
        end

        function obj = set.backgroundweight(obj,backgroundweightValue)
            validateattributes(backgroundweightValue,{'uint8','int8','uint16', ...
                'int16','uint32','int32','single','double'},{'real', ...
                'nonnegative','scalar','nonnan','finite'});
            obj.backgroundweight = double(backgroundweightValue);
        end

    end % End of methods

end % End of class

%function finds the input mean and output mean
%==========================================================================
function  [inAreaOne,outAreaOne,inMeanOne,outMeanOne] = ...
    chanVeseInitializeSpeed(IOne,phiOne,szOne,numChannelsOne)
coder.inline('always');
coder.internal.prefer_const(IOne,phiOne,szOne,numChannelsOne);
validateattributes(IOne,{'single','double'},{'finite','nonsparse','real'},mfilename,'Image',1);

if isa(IOne,'single')
    phiOneTmp = single(phiOne);
    szOneTmp = single(szOne);
    numChannelsOneTmp = single(numChannelsOne);
else
    phiOneTmp = double(phiOne);
    szOneTmp = double(szOne);
    numChannelsOneTmp = double(numChannelsOne);
end

if numChannelsOne > 1
    [inAreaOne,outAreaOne,inMeanOne,outMeanOne] = ...
        multiChProcessing(IOne,phiOneTmp,szOneTmp,numChannelsOneTmp);
else
    [inAreaOne,outAreaOne,inMeanOne,outMeanOne] = ...
        singleChProcessing(IOne,phiOneTmp);
end

end

%==========================================================================
function [inAreaOne,outAreaOne,inMeanOne,outMeanOne] = ...
    multiChProcessing(IOne,phiOneTmp,szOneTmp,numChannelsOneTmp)

coder.inline('always');
coder.internal.prefer_const(IOne,phiOneTmp,szOneTmp,numChannelsOneTmp);

rows = szOneTmp(1);
cols = szOneTmp(2);

numPixels = rows*cols;

inAreaOne = zeros(1,1,'like',IOne);
outAreaOne = zeros(1,1,'like',IOne);
inMeanOne = zeros(1,numChannelsOneTmp,'like',IOne);
outMeanOne = zeros(1,numChannelsOneTmp,'like',IOne);

for i = 1:numPixels
    if phiOneTmp(i) <= 0
        inAreaOne =  inAreaOne + 1;
        for j = 1 : numChannelsOneTmp
            idx =  (j-1)*numPixels + i;
            inMeanOne(j) = inMeanOne(j) + IOne(idx);
        end
    else
        outAreaOne =  outAreaOne + 1;
        for j = 1 : numChannelsOneTmp
            idx =  (j-1)*numPixels + i;
            outMeanOne(j) = outMeanOne(j) + IOne(idx);
        end
    end
end
parfor i = 1:numChannelsOneTmp
    inMeanOne(i) = inMeanOne(i)/inAreaOne;
    outMeanOne(i) = outMeanOne(i)/outAreaOne;
end

end

%==========================================================================
function [inAreaOne,outAreaOne,inMeanOne,outMeanOne] = ...
    singleChProcessing(IOne,phiOneTmp)

coder.inline('always');
coder.internal.prefer_const(IOne,phiOneTmp);
[rows, cols] = size(IOne);

numElements = coder.internal.indexInt(rows) * coder.internal.indexInt(cols);

inAreaOne = zeros(1,'like',IOne);
outAreaOne = zeros(1,'like',IOne);
inMeanOne = zeros(1,'like',IOne);
outMeanOne = zeros(1,'like',IOne);

for i=1:numElements
    if phiOneTmp(i) <= 0
        inAreaOne = inAreaOne + 1;
        inMeanOne = inMeanOne + IOne(i);

    else
        outAreaOne = outAreaOne + 1;
        outMeanOne = outMeanOne + IOne(i);
    end
end
inMeanOne = inMeanOne/inAreaOne;
outMeanOne = outMeanOne/outAreaOne;
end