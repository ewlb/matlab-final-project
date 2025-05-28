function [B,D] = imlocalbrighten(im,varargin)
%IMLOCALBRIGHTEN  Brighten low-light image.
%   B = IMLOCALBRIGHTEN(A) brightens low-light areas in A, which is an
%   RGB or grayscale image. Returns B, the locally brightened image, which
%   is the same size and class as A.
%
%   B = IMLOCALBRIGHTEN(A,amount) brightens low-light areas in A, where 
%   amount specifies how much to brighten the dark areas of the image. 
%   Specify amount as a scalar in the range [0,1]. When the value is 1
%   (the default), imlocalbrighten brightens the low-light areas of A as
%   much as possible. When the value is 0, imlocalbrighten returns the
%   input image unmodified.
%
%   [B,D] = IMLOCALBRIGHTEN(___) brightens low-light areas in A,
%   additionally returning the darkness matrix D with values in the range
%   [0,1]. The value 1 in the darkness matrix indicates a pixel is
%   completely dark (black) and the value 0 indicates a pixel is not dark
%   (white).
%
%   [___] = IMLOCALBRIGHTEN(___,Name,Value) brightens low-light areas in A, 
%   with an additional parameter that controls some aspects of the
%   operation. The parameter name can be abbreviated, and case does not 
%   matter.
%
%
%     'AlphaBlend'           Alpha-blends the input image and the enhanced 
%                            image, specified as true or false (default). 
%                            Alpha-blending the input image with the
%                            enhanced image attempts to preserve content 
%                            of the input image proportional to the amount 
%                            of light in each pixel. When set to true, 
%                            imlocalbrighten alpha-blends the input and the
%                            enhanced output, using D to preserve more 
%                            content in the brighter areas.
%
%   Class Support
%   -------------
%   A must be a real, non-sparse, M-by-N-by-3 RGB or M-by-N grayscale image
%   of class single, double, uint8, or uint16. B is the same size and class 
%   as A. D is a matrix the same size as the first two dimensions of A of 
%   class double.
%
%   References
%   ---------
%   [1] Dong,X., G.Wang, Y. Pang, W. Li, J. Wen, W. Meng, and Y. Lu. "Fast
%   efficient algorithm for enhancement of low lighting video." Proceedings
%   of IEEE International Conference on Multimedia and Expo (ICME). 2011,
%   pp. 1-6.
%   [2] He, Kaiming. "Single Image Haze Removal Using Dark Channel Prior."
%   Thesis, The Chinese University of Hong Kong, 2011.
%   [3] Dubok et al. "Single Image Dehazing with Image Entropy and
%   Information Fidelity." ICIP, 2014.
%
%   Example 1
%   ---------
%   % Brighten low-light image using default parameters.
%
%       A = imread('lowlight_2.jpg');
%       B = imlocalbrighten(A);
%       figure, montage({A,B})
%
%   Example 2
%   ---------
%   % Brighten low-light image 80% by setting amount equal to 0.8.
%
%       A = imread('lowlight_2.jpg');
%       B2 = imlocalbrighten(A,0.8);
%       figure, montage({A,B2})
%
%   Example 3
%   ---------
%   % Set the AlphaBlend option to true in order to preserve content.
%
%       A = imread('lowlight_2.jpg');
%       B = imlocalbrighten(A);
%       % Brighten image, this time using AlphaBlend.
%       Bblend = imlocalbrighten(A,'AlphaBlend',true);
%       % Compare alpha-blended output with previous enhanced image.
%       figure, montage({B,Bblend})
%
%   Example 4
%   ---------
%   % Get the estimated darkness per pixel.
%
%       A = imread('lowlight_2.jpg');
%       [~,D] = imlocalbrighten(A);
%       figure, montage({A,D})
%
%   See also adapthisteq, histeq, imreducehaze.

%   Copyright 2019 The MathWorks, Inc.

[A,amount,alphaBlend] = parseInputs(im,varargin{:});

inputClass = class(A);

if ~isfloat(A)
    A = im2single(A);
end

if (amount == 0)
    B = A;
    D = [];
else
    Ainv = imcomplement(A);
    [Binv,D] = imreducehaze(Ainv,amount,'ContrastEnhancement','none');
    B = imcomplement(Binv);
    if alphaBlend
        B = A .* (1.0 - D) + B.* D;
    end
end

B = images.internal.changeClass(inputClass,B);

end


function [im,amount,alphaBlend] = parseInputs(im,varargin)

narginchk(1,4);

validateattributes(im,...
    {'single','double','uint8','uint16'},...
    {'real','nonsparse','nonempty'}, ...
    mfilename,'A',1);

if ~(ismatrix(im) || (ndims(im) == 3) && (size(im,3) == 3))
    error(message('images:validate:invalidImageFormat','A'));
end

parser = inputParser();
parser.addOptional('amount',1.0,@validateAmount);
parser.addParameter('AlphaBlend',false,@validateAlphaBlend);

parser.parse(varargin{1:end})
amount = parser.Results.amount;
alphaBlend = logical(parser.Results.AlphaBlend);

end


function TF = validateAmount(amount)

validateattributes(amount, ...
    {'numeric'}, ...
    {'scalar','real','nonnegative','<=',1,'nonsparse'}, ...
    mfilename,'amount');
TF = true;

end


function TF = validateAlphaBlend(arg)

validateattributes(arg, ...
    {'numeric','logical'}, ...
    {'scalar','real','nonsparse','nonnan'}, ...
    mfilename,'AlphaBlend');
TF = true;

end

