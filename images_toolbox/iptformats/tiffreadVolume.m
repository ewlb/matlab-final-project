function V = tiffreadVolume(filename, args)
%tiffreadVolume   Read volume from TIFF file.
%    V = tiffreadVolume(FILENAME) loads all of the volumetric data in the
%    TIFF file named FILENAME into V. All of the spatial dimensions in V
%    are first, and color (if present) is in the final dimension.
%
%    V = tiffreadVolume(____, 'PixelRegion', {ROWS, COLUMNS}) and 
%    V = tiffreadVolume(____, 'PixelRegion', {ROWS, COLUMNS, SLICES})
%    subset the volume V. ROWS, COLUMNS, and SLICES should each be 1-by-2
%    or 1-by-3 vectors containing the [START STOP] or [START STRIDE STOP]
%    integer indices for the region. START and STOP include their
%    respective voxels, and STOP can be inf to read to the end of the
%    dimension. If SLICES is not provided, all slices are returned.
%
%    Notes:
%    All slices/frames in a volume must have the same dimensions, datatype,
%    and number of color channels.
%
%    This function supports the following kinds of TIFF volumes:
%    * Individual images/IFDs of the same size and kind within the file.
%    * One image using the ImageDepth tag.
%    * Large, non-BigTIFF volumes greater than 4GB created by ImageJ.
%
%    Example:
%        % Load full volume.
%        V1 = tiffreadVolume('mri.tif');
%
%        % Downsample the volume and pull some middle slices.
%        V2 = tiffreadVolume('mri.tif', 'PixelRegion', {[1 2 inf], [1 2 inf], [10 15]});
%
%    See also dicomread, dicomreadVolume, imread, niftiread.

% Copyright 2020-2024 The MathWorks, Inc.

% NOTE: Colorspace conversions will happen in the appropriate low-level
% reader (i.e., via recursion for IFD-based images or in Tiff object).

arguments
    filename (1,1) string
    args.PixelRegion cell = {}
end

filename = images.internal.io.absolutePathForReading(filename);

persistent istif
if isempty(istif)
    fmts = imformats('tif');
    istif = fmts.isa;
end

if ~istif(filename)
    error(message('MATLAB:imagesci:imfinfo:badFormat', filename, 'TIF'))
end

% Avoid issuing lots of the same warning.
w = warning('off', 'imageio:tiffutils:libtiffWarning');
oc = onCleanup(@() warning(w));
details = matlab.io.internal.imagesci.imtifinfo(filename);

V = images.internal.tiff.readVolume(args, details);
