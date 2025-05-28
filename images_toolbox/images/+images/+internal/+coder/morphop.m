function Bout = morphop(A,se,op_type,func_name,varargin) %#codegen
%MORPHOP Dilate or erode image.
%   B = MORPHOP(OP_TYPE,A,SE,...) computes the erosion or dilation of A,
%   depending on whether OP_TYPE is 'erode' or 'dilate'.  SE is a
%   STREL array or an NHOOD array.  MORPHOP is intended to be called only
%   by IMDILATE or IMERODE.  Any additional arguments passed into
%   IMDILATE or IMERODE should be passed into MORPHOP following SE.  See
%   the help entries for IMDILATE and IMERODE for more details about the
%   allowable syntaxes.

%   Copyright 2013-2024 The MathWorks, Inc.

%#ok<*EMCA>

narginchk(4,7);

se = images.internal.strelcheck(se,func_name,'SE',2);

if coder.const(se.UseConstantFoldingImpl)
    % When generating with all constant folded inputs other than
    % Input Image
    Bout = images.internal.coder.morphopConstantFoldingImpl(A,se,op_type,func_name,varargin{:});
    return;
end

%
%% Parse Inputs & Validate
[A, input_is_packed, output_is_full, inNumRows, ...
    input_is_logical, input_is_2d] = images.internal.coder.morphopInputParser(A, op_type,func_name, varargin{:});

if images.internal.coder.isTargetMACA64
    useSharedLibrary = false;
else
    useSharedLibrary = coder.internal.preferMATLABHostCompiledLibraries() && ...
        coder.const(~images.internal.coder.useSingleThread()) && ...
        ~(coder.isRowMajor && coder.const(numel(size(A))>2));
end

%
%% Compute processing flags
% Figure out the appropriate image preprocessing steps, image
% postprocessing steps, and method to invoke.
%
% First, find out the values of all the necessary predicates.
%

% Get the sequence of decomposed strels from given strel input
[seq, isEachStrelInSE2D] = decompose(se);
num_strels        = numel(seq);
strel_is_single   = num_strels == 1;
strel_is_all_flat = is_strel_all_flat(seq);
strel_is_all_2d   = is_strel_all_2d(seq);

% When using shared library, decide for each strel in seq to use either shared library or PortableC
useSharedLibraryForEachStrelInSeq = useSharedLibrary & ...
    ~(coder.isRowMajor & ~isEachStrelInSE2D);

%
% Check for error conditions related to packing
%
coder.internal.errorIf(...
    input_is_packed && ~strel_is_all_2d,...
    'images:morphop:packedStrelNot2D');

coder.internal.errorIf(...
    input_is_packed && ~strel_is_all_flat,...
    'images:morphop:nonflatStrelPacked');

coder.internal.errorIf(...
    input_is_packed && ~useSharedLibrary,...
    'images:morphop:packedInputsNotSupported');

coder.internal.errorIf(...
    input_is_packed && ~all(useSharedLibraryForEachStrelInSeq),...
    'images:morphop:packedInputsNotSupported');

%
% Next, use predicate values to determine the necessary preprocessing and
% postprocessing steps.
%

% If the user has asked for full-size output, or if there are multiple
% and/or decomposed strels that are not rectangular, then pre-pad the input image.
% Note - currently strel_is_single is always true.
pre_pad = output_is_full || (~strel_is_single && ~isdecompositionorthogonal(se));

% If we had to pre-pad the input but the user didn't specify the 'full'
% option, then crop the image before returning it.
% Note - This is always false (since strel_is_single is always true.)
post_crop = pre_pad & ~output_is_full;

% If the input image is logical, then the strel must be flat.
coder.internal.errorIf(...
    input_is_logical && ~strel_is_all_flat,...
    'images:morphop:binaryWithNonflatStrel',func_name);

if coder.internal.preferMATLABHostCompiledLibraries() && ...
        coder.const(~images.internal.coder.useSingleThread())
    % If the input image is logical and not packed, and if there are multiple
    % all-flat strels, the prepack the input image.
    pre_pack = ~strel_is_single & input_is_logical & input_is_2d & ...
        strel_is_all_flat & strel_is_all_2d;
    % packed processing is only supported with shared libraries

    pre_pack = pre_pack & all(useSharedLibraryForEachStrelInSeq);
else
    pre_pack = false;
end

% If this function pre-packed the image, unpack it before returning it.
post_unpack = pre_pack;

%
%% Other compile time constants
%
if(images.internal.coder.useSingleThread())
    tsuffix         = '';
else
    tsuffix         = '_tbb';
end

% iptgetpref for IPP preference (obtained at compile time)
myfun      = 'iptgetpref';
coder.extrinsic('eml_try_catch');
[errid, errmsg, prefFlag] = eml_const(eml_try_catch(myfun, 'UseIPPL'));
eml_lib_assert(isempty(errmsg), errid, errmsg);

%
%% Determine function and corresponding library to call.
%
ctype = images.internal.coder.getCtype(A);
if pre_pack || input_is_packed
    fcnNameEnum = stringToFunction(op_type, '_', 'packed_uint32');
    libNameEnum = stringToLib('packed');

elseif input_is_logical
    if input_is_2d && strel_is_single && strel_is_all_2d
        if isequal(getnhood(se), ones(3))
            fcnNameEnum = stringToFunction('binary_ones33');
        else
            fcnNameEnum = stringToFunction('binary_twod');
        end
    else
        fcnNameEnum = stringToFunction('binary');
    end
    libNameEnum = stringToLib('binary', tsuffix);

elseif strel_is_all_flat
    fcnNameEnum = stringToFunction(op_type, '_', 'flat_', ctype, tsuffix);
    libNameEnum = stringToLib('flat', tsuffix);

else
    fcnNameEnum = stringToFunction(op_type, '_', 'nonflat_', ctype, tsuffix);
    libNameEnum = stringToLib('nonflat', tsuffix);
end

%
%% PreProcessing
%
if input_is_packed
    % In a prepacked binary image, the fill bits at the bottom of the packed
    % array should be handled just like pad values.  The fill bits should be
    % 0 for dilation and 1 for erosion.

    fill_value = strcmp(op_type, 'erode');
    fill_value = coder.const(fill_value);
    A          = images.internal.setPackedFillBits(A, inNumRows, fill_value);
end

if pre_pad
    % Now compute how padding is needed based on the strel offsets.

    switch(op_type)
        case 'erode'
            % Swap
            [pad_ul1, pad_lr1] = getpadsize(se);
            tmp     = pad_ul1;
            pad_ul1 = pad_lr1;
            pad_lr1 = tmp;
        case 'dilate'
            [pad_ul1, pad_lr1] = getpadsize(se);
        otherwise
            assert(false, 'Unknown option');
    end

    P = length(pad_ul1);
    Q = ndims(A);
    if P < Q
        pad_ul = [pad_ul1 zeros(1,Q-P)];
        pad_lr = [pad_lr1 zeros(1,Q-P)];
    else
        pad_ul = pad_ul1;
        pad_lr = pad_lr1;
    end

    if input_is_packed
        % Input is packed binary.  Adjust padding appropriately.
        pad_ul(1) = ceil(pad_ul(1) / 32);
        pad_lr(1) = ceil(pad_lr(1) / 32);
    end

    pad_val = getPadValue(class(A), op_type);

    Apadpre = padarray(A,pad_ul,pad_val,'pre');
    Apad    = padarray(Apadpre,pad_lr,pad_val,'post');
else
    Apad    = A;
    pad_ul = [-1 -1];
    pad_lr = [-1 -1];
end


if input_is_packed
    numRows  = inNumRows;
    Apadpack = Apad;
    Apadnotpack = zeros(0,0, 'like', Apad);

elseif pre_pack
    numRows  = size(Apad,1);
    Apadpack = bwpack(Apad);
    Apadnotpack = zeros(0,0, 'like', Apad);

else
    numRows  = inNumRows;
    Apadpack =  uint32([]);
    Apadnotpack = Apad;

end

%
%% Apply the sequence of dilations/erosions.
%
Bpack = coder.nullcopy(Apadpack);
Bnotpack = coder.nullcopy(Apadnotpack);

for sInd = 1:num_strels
    nhoodIn     = getnhood(seq(sInd));
    allheightIn = getheight(seq(sInd));

    if useSharedLibrary
        if useSharedLibraryForEachStrelInSeq(sInd)
            if useIPP(A, nhoodIn, allheightIn, prefFlag) && strel_is_all_flat
                % The definition of kernel center for even kernels differs between
                % IPP9.0's new morphology symbols and the toolbox version.
                % The IPP 9.0 symbols take the rounded bottom right element as center
                % To address this, we pad the top and left with zeros to make the kernel dimensions
                % odd. This removes any ambiguity in the definition of kernel's center.
                %
                %                       c    1
                %                       2    3  % c is the center of the kernel as defined in the toolbox version
                %
                %
                %                   0    0    0
                %                   0    c    1
                %                   0    2    3  % We pad the even kernel with zeros to remove ambiguity of kernel's center
                %
                if(any(~mod(size(nhoodIn),2)))
                    nhoodNumRows = size(nhoodIn,1);
                    nhoodNumCols = size(nhoodIn,2);
                    iPPCenterPixelRow = ceil(nhoodNumRows/2);
                    iPPCenterPixelCol = ceil(nhoodNumCols/2);

                    numRowPad = nhoodNumRows-2*iPPCenterPixelRow+1;
                    numColPad = nhoodNumCols-2*iPPCenterPixelCol+1;


                    nhood = zeros(coder.ignoreConst(nhoodNumRows+numRowPad), ...
                        coder.ignoreConst(nhoodNumCols+numColPad), coder.ignoreConst(1), 'logical');

                    allheight = zeros(coder.ignoreConst(nhoodNumRows+numRowPad), ...
                        coder.ignoreConst(nhoodNumCols+numColPad), coder.ignoreConst(1));


                    nhood(numRowPad+1:end,numColPad+1:end) = nhoodIn(:,:,1);
                    allheight(numRowPad+1:end,numColPad+1:end) = allheightIn(:,:,1);

                else
                    nhood = nhoodIn;
                    allheight = allheightIn;
                end

                % Flip height if we are dilating.
                if(strcmp(op_type,'dilate'))
                    if(ismatrix(A))
                        % If ndims(nhood)>2, then trailing dimension dont count.
                        % Effectively, reflect only the first plane. (the rest get
                        % flipped, but they are 'dont-cares').
                        allheight = flip(flip(allheight,1),2);
                        if(any(allheight(:)))
                            % Flip nhood only for non-flat se
                            nhood     = flip(flip(nhood,1),2);
                        end
                    else
                        allheight(1:end) = allheight(end:-1:1);
                        if(any(allheight(:)))
                            nhood(1:end)     = nhood(end:-1:1);
                        end
                    end
                end


                % pick only non-zero heights. (For the toolbox, this is done in the
                % mex layer)
                allheight_ = allheight(:);
                height = allheight_(nhood(:));

                ippFcnNameEnum = stringToFunction(op_type,'_', ctype,'_ipp');
                ippLibNameEnum = stringToLib('ipp');
                [Bpack, Bnotpack] = callSharedLibrary(ippLibNameEnum, ippFcnNameEnum, ctype, '', op_type, ...
                    Apadpack, Apadnotpack, logical(nhood), height, numRows, Bpack, Bnotpack, pre_pack || input_is_packed, input_is_logical);

            else
                nhood = nhoodIn;
                allheight = allheightIn;
                % Flip height if we are dilating.
                if(strcmp(op_type,'dilate'))
                    if(ismatrix(A))
                        % If ndims(nhood)>2, then trailing dimension dont count.
                        % Effectively, reflect only the first plane. (the rest get
                        % flipped, but they are 'dont-cares').
                        allheight = flip(flip(allheight,1),2);
                        if(any(allheight(:)))
                            % Flip nhood only for non-flat se
                            nhood = flip(flip(nhood,1),2);
                        end
                    else
                        allheight(1:end) = allheight(end:-1:1);
                        if(any(allheight(:)))
                            nhood(1:end) = nhood(end:-1:1);
                        end
                    end
                end

                if(coder.isRowMajor)
                    % Transpose height and nhood so that they are traversed in
                    % row-major format
                    allheightT = allheight(:,:,1)';
                    nhoodT = nhood(:,:,1)';
                else
                    allheightT = allheight;
                    nhoodT = nhood;
                end

                % pick only non-zero heights. (For the toolbox, this is done in the
                % mex layer)
                allheightT_ = allheightT(:);
                height = allheightT_(nhoodT(:));

                [Bpack, Bnotpack] = callSharedLibrary(libNameEnum, fcnNameEnum, ctype, tsuffix, op_type, ...
                    Apadpack, Apadnotpack, nhood, height, numRows, Bpack, Bnotpack, pre_pack || input_is_packed, input_is_logical);

            end
        else
            % portable C code
            Bnotpack = images.internal.coder.morphopPortable(Apadnotpack,...
                nhoodIn , allheightIn,...
                op_type, Bnotpack);
        end
    else
        % portable C code
        Bnotpack = images.internal.coder.morphopPortable(Apadnotpack,...
            nhoodIn , allheightIn,...
            op_type, Bnotpack);
    end

    % prepare for next iteration
    if pre_pack || input_is_packed
        Apadpack = Bpack;
    else
        Apadnotpack = Bnotpack;
    end
end

%% Postprocessing
if input_is_logical
    if post_unpack
        Bunpack = bwunpack(Bpack,numRows);
    else
        Bunpack = Bnotpack;
    end

    if post_crop
        % Crop out the padded portion
        diml = pad_ul+1;
        dimh = diml + size(Bunpack) - pad_ul - pad_lr -1;
        switch numel(size(Bunpack))
            case 2
                Bout = Bunpack(diml(1):dimh(1), diml(2):dimh(2));
            case 3
                Bout = Bunpack(diml(1):dimh(1), diml(2):dimh(2), diml(3):dimh(3));
                % otherwise - covered in input validation.
        end
    else
        Bout = Bunpack;
    end
elseif input_is_packed
    if post_crop
        % Crop out the padded portion
        diml = pad_ul+1;
        dimh = diml + size(Bpack) - pad_ul - pad_lr -1;
        switch numel(size(Bpack))
            case 2
                Bout = Bpack(diml(1):dimh(1), diml(2):dimh(2));
            case 3
                Bout = Bpack(diml(1):dimh(1), diml(2):dimh(2), diml(3):dimh(3));
                % otherwise - covered in input validation.
        end
    else
        Bout = Bpack;
    end
else
    if post_crop
        % Crop out the padded portion
        diml = pad_ul+1;
        dimh = diml + size(Bnotpack) - pad_ul - pad_lr -1;
        switch numel(size(Bnotpack))
            case 2
                Bout = Bnotpack(diml(1):dimh(1), diml(2):dimh(2));
            case 3
                Bout = Bnotpack(diml(1):dimh(1), diml(2):dimh(2), diml(3):dimh(3));
                % otherwise - covered in input validation.
        end
    else
        Bout = Bnotpack;
    end
end
%--------------------------------------------------------------------------

%==========================================================================
function pad_value = getPadValue(className, op_type)
% Returns the appropriate pad value, depending on whether we are performing
% erosion or dilation, and whether or not A is logical (binary).

if strcmp(op_type, 'dilate')
    switch className
        case 'logical'
            pad_value = false;
        case {'single', 'double'}
            pad_value = -inf(1,className);
        otherwise
            pad_value = intmin(className);
    end
else
    switch className
        case 'logical'
            pad_value = true;
        case {'single', 'double'}
            pad_value = inf(1,className);
        otherwise
            pad_value = intmax(className);
    end
end
%--------------------------------------------------------------------------

%==========================================================================
function TF = useIPP(A, nhood, allheightIn, prefFlag)

TF = false;

supportedType   = isa(A,'single') || isa(A,'uint8') || isa(A,'uint16');
if ~supportedType
    return;
end

if isempty(nhood)
    return;
end

is2DInput = ismatrix(A);
strelIsAll2D = ismatrix(nhood);

strelSize = size(nhood);
if any(strelSize > 200)
    isSizeBadForIPP = true;
else
    isSizeBadForIPP = false;
end

density = nnz(nhood)/numel(nhood);
if density < 0.05
    isDensityBadForIPP = true;
else
    isDensityBadForIPP = false;
end

TF  = is2DInput && supportedType && strelIsAll2D && ~any(allheightIn(:)) && ...
    ~isSizeBadForIPP && ~isDensityBadForIPP && prefFlag;
%--------------------------------------------------------------------------

%==========================================================================
function TF = is_strel_all_flat(se)
coder.inline('always');
% Check if all the decomposed strel elements are flat
num_strels = length(se);
TF = true;
for sInd = 1:num_strels
    if (~isflat(se(sInd)))
        TF = false;
        break;
    end
end
%--------------------------------------------------------------------------


%==========================================================================
function TF = is_strel_all_2d(se)
coder.inline('always');
num_strels = length(se);
TF = true;
for sInd = 1:num_strels
    if (~ismatrix(getnhood(se(sInd))))
        TF = false;
        break;
    end
end
%--------------------------------------------------------------------------


%==========================================================================
function [Bpack, Bnotpack] = callSharedLibrary(libNameEnum, fcnNameEnum, ctype, tsuffix, op_type, ...
    Apadpack, Apadnotpack, nhood, height, numRows, Bpack, Bnotpack, isInputPrePacked, isInputLogical)
coder.inline('always');
size_nhood = size(nhood);
numDims_nhood = ndims(nhood);

if isInputPrePacked
    if(strcmp(op_type,'dilate'))
        Bpack = images.internal.coder.buildable.Morphop_packed_Buildable.dilate_packed(...
            [op_type, '_', 'packed_uint32'], ...
            Apadpack,     size(Apadpack),     ndims(Apadpack),...
            nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
            Bpack);
    else %imerode
        Bpack = images.internal.coder.buildable.Morphop_packed_Buildable.erode_packed(...
            [op_type, '_', 'packed_uint32'], ...
            Apadpack,     size(Apadpack),     ndims(Apadpack),...
            nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
            numRows,...
            Bpack);
    end
elseif isInputLogical
    if libNameEnum == LIB_BINARY_TBB
        if fcnNameEnum == FUNCTION_BINARY_ONES33()
            Bnotpack = images.internal.coder.buildable.Morphop_binary_tbb_Buildable.morphop_binary_tbb(...
                [op_type, '_', 'binary_ones33', tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        elseif fcnNameEnum == FUNCTION_BINARY_TWOD()
            Bnotpack = images.internal.coder.buildable.Morphop_binary_tbb_Buildable.morphop_binary_tbb(...
                [op_type, '_', 'binary_twod', tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        elseif fcnNameEnum == FUNCTION_BINARY()
            Bnotpack = images.internal.coder.buildable.Morphop_binary_tbb_Buildable.morphop_binary_tbb(...
                [op_type, '_', 'binary', tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        else
            % The code should be unreachable
            assert(false,"Unrecognized Function");
        end

    else %libNameEnum == LIB_BINARY
        if fcnNameEnum == FUNCTION_BINARY_ONES33()
            Bnotpack = images.internal.coder.buildable.Morphop_binary_Buildable.morphop_binary(...
                [op_type, '_', 'binary_ones33', tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        elseif fcnNameEnum == FUNCTION_BINARY_TWOD()
            Bnotpack = images.internal.coder.buildable.Morphop_binary_Buildable.morphop_binary(...
                [op_type, '_', 'binary_twod', tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        elseif fcnNameEnum == FUNCTION_BINARY()
            Bnotpack = images.internal.coder.buildable.Morphop_binary_Buildable.morphop_binary(...
                [op_type, '_', 'binary', tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        else
            % The code should be unreachable
            assert(false, "Unrecognized Function");
        end
    end
else
    switch libNameEnum
        case LIB_NONFLAT_TBB
            Bnotpack = images.internal.coder.buildable.Morphop_nonflat_tbb_Buildable.morphop_nonflat_tbb(...
                [op_type, '_', 'nonflat_', ctype, tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                height,...
                Bnotpack);
        case LIB_NONFLAT
            Bnotpack = images.internal.coder.buildable.Morphop_nonflat_Buildable.morphop_nonflat(...
                [op_type, '_', 'nonflat_', ctype, tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                height,...
                Bnotpack);
        case LIB_FLAT_TBB
            Bnotpack = images.internal.coder.buildable.Morphop_flat_tbb_Buildable.morphop_flat_tbb(...
                [op_type, '_', 'flat_', ctype, tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        case LIB_FLAT
            Bnotpack = images.internal.coder.buildable.Morphop_flat_Buildable.morphop_flat(...
                [op_type, '_', 'flat_', ctype, tsuffix], ...
                Apadnotpack,     size(Apadnotpack),     ndims(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), numDims_nhood,...
                Bnotpack);
        case LIB_IPP
            Bnotpack = images.internal.coder.buildable.Morphop_ipp_Buildable.morphop_ipp(...
                [op_type, '_', ctype, '_ipp'], ...
                Apadnotpack,     size(Apadnotpack),...
                nhood, size_nhood(1:numDims_nhood), ...
                Bnotpack);
        otherwise
            % The code should be unreachable
            assert(false,"Unrecognized Library");
    end
end
%--------------------------------------------------------------------------

%==========================================================================
function libNameEnum = stringToLib(varargin)
% Convert libName string to its corresponding enumeration
% Use strcmp not to allow case-insensitive, partial matches
if strcmp([varargin{:}], 'packed')
    libNameEnum = LIB_PACKED;
elseif strcmp([varargin{:}], 'binary')
    libNameEnum = LIB_BINARY;
elseif strcmp([varargin{:}], 'flat')
    libNameEnum = LIB_FLAT;
elseif strcmp([varargin{:}], 'nonflat')
    libNameEnum = LIB_NONFLAT;
elseif strcmp([varargin{:}], 'binary_tbb')
    libNameEnum = LIB_BINARY_TBB;
elseif strcmp([varargin{:}], 'flat_tbb')
    libNameEnum = LIB_FLAT_TBB;
elseif strcmp([varargin{:}], 'nonflat_tbb')
    libNameEnum = LIB_NONFLAT_TBB;
elseif strcmp([varargin{:}], 'ipp')
    libNameEnum = LIB_IPP;
else
    libNameEnum = UNRECOGNIZED;
end
%--------------------------------------------------------------------------

%==========================================================================
function fcnNameEnum = stringToFunction(varargin)
% Convert fcnName string to its corresponding enumeration
% Use strcmp to allow case-insensitive, partial matches
if strcmp([varargin{:}], 'binary_ones33')
    fcnNameEnum = FUNCTION_BINARY_ONES33;
elseif strcmp([varargin{:}], 'binary_twod')
    fcnNameEnum = FUNCTION_BINARY_TWOD;
elseif strcmp([varargin{:}], 'binary')
    fcnNameEnum = FUNCTION_BINARY;
elseif strcmp([varargin{:}], 'ipp')
    fcnNameEnum = FUNCTION_IPP;
else
    fcnNameEnum = UNRECOGNIZED;
end
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
function flag = UNRECOGNIZED()
coder.inline('always');
flag = int8(-1);

%--------------------------------------------------------------------------
function libFlag = LIB_PACKED()
coder.inline('always');
libFlag = int8(1);

%--------------------------------------------------------------------------
function libFlag = LIB_BINARY()
coder.inline('always');
libFlag = int8(2);

%--------------------------------------------------------------------------
function libFlag = LIB_FLAT()
coder.inline('always');
libFlag = int8(3);

%--------------------------------------------------------------------------
function libFlag = LIB_NONFLAT()
coder.inline('always');
libFlag = int8(4);

%--------------------------------------------------------------------------
function libFlag = LIB_BINARY_TBB()
coder.inline('always');
libFlag = int8(5);

%--------------------------------------------------------------------------
function libFlag = LIB_FLAT_TBB()
coder.inline('always');
libFlag = int8(6);

%--------------------------------------------------------------------------
function libFlag = LIB_NONFLAT_TBB()
coder.inline('always');
libFlag = int8(7);

%--------------------------------------------------------------------------
function libFlag = LIB_IPP()
coder.inline('always');
libFlag = int8(8);

%--------------------------------------------------------------------------
function fcnFlag = FUNCTION_BINARY_ONES33()
coder.inline('always');
fcnFlag = int8(10);

%--------------------------------------------------------------------------
function fcnFlag = FUNCTION_BINARY_TWOD()
coder.inline('always');
fcnFlag = int8(11);

%--------------------------------------------------------------------------
function fcnFlag = FUNCTION_BINARY()
coder.inline('always');
fcnFlag = int8(12);
