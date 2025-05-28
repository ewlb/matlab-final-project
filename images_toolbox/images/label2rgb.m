function RGB = label2rgb(varargin) 

args = matlab.images.internal.stringToChar(varargin);
[label,map,zerocolor,order,fcnflag,outputFormat,numregion] = parse_inputs(args{:});

% If MAP is a function, evaluate it.  Make sure that the evaluated function
% returns a valid colormap.
if  fcnflag == 1
    if numregion == 0
      cmap = [];
    else
      cmap = feval(map, numregion);
      if ~isreal(cmap) || any(cmap(:) > 1) || any(cmap(:) < 0) || ...
            ~isequal(size(cmap,2),3) || size(cmap,1) < 1
        error(message('images:label2rgb:functionReturnsInvalidColormap'));
      end
    end
else
    cmap = map;
end

% If ORDER is set to 'shuffle', create a private stream with a fixed seed,
% which creates the same "random" permutation every time it is called.
if isequal(order,'shuffle')
    stream = RandStream('swb2712','seed',0);
    index = randperm(stream,numregion);
    cmap = cmap(index,:,:);
end

% Issue a warning if the zerocolor (boundary color) matches the color of one
% of the regions. 
for i=1:numregion
  if isequal(zerocolor,cmap(i,:))
    warning(message('images:label2rgb:zerocolorSameAsRegionColor', i));
  end
end
cmap = [zerocolor;cmap];

if isa(label,'uint8') || isa(label,'uint16') || isa(label,'uint32')
    RGB = matlab.images.internal.ind2rgb8(label, cmap);
else
    % Using label + 1 for two reasons: 1) IND2RGB and IND2RGB8 do not like
    % double arrays containing zero values, and 2)for non-double, IND2RGB would
    % cast to a double and do this.
    RGB = matlab.images.internal.ind2rgb8(double(label)+1,cmap);
end

if strncmp(outputFormat,'triplets',1) % RGB image or triplets
    % Reshape to numel(L)-by-3
    RGB = reshape(RGB,numel(label),3);
end
    

%  Function: parse_inputs
%  ----------------------
function [L, Map, Zerocolor, Order, Fcnflag, outputFormat, numRegion] = parse_inputs(varargin) 
% L         label matrix: matrix containing non-negative values.  
% Map       colormap: name of standard colormap, user-defined map, function
%           handle.
% Zerocolor RGB triple or Colorspec
% Order     keyword if specified: 'shuffle' or 'noshuffle'
% Fcnflag   flag to indicating that Map is a function
% numRegion maximimum label value in L


narginchk(1,6);

% set defaults
L = varargin{1};
Map = 'jet';    
Zerocolor = [1 1 1]; 
Order = 'noshuffle';
Fcnflag = 0;
outputFormat = 'image';

% parse inputs
if nargin-1 > 0
    switch nargin
        case 2
            % optional colormap input
            Map = varargin{2};
        case 3
            % Parse and validate the following syntaxes:
            %    - (L,map,zerocolor) || (L,'OutputFormat',value)
            outputFormatSpecified = parseOutputFormat(varargin{2:3});
            if outputFormatSpecified
                outputFormat = varargin{3};
            else
                Map = varargin{2};
                Zerocolor = varargin{3};
            end
               
        case 4
            % Parse and validate the following syntaxes:
            %    - (L,map,zerocolor,order) || (L,map,'OutputFormat',value)
            Map = varargin{2};
            
            outputFormatSpecified = parseOutputFormat(varargin{3:4});
            if outputFormatSpecified
                outputFormat = varargin{4};
            else
                Zerocolor = varargin{3};
                Order = varargin{4};
            end

        case 5
            % Parse and validate the following syntaxes:
            %    - (L,map,zerocolor,'OutputFormat',value)
            %    - (L,map,zerocolor,order,'OutputFormat')
            
            Map = varargin{2};
            Zerocolor = varargin{3};
            
            outputFormatSpecified = parseOutputFormat(varargin{4:5});
            if outputFormatSpecified
                outputFormat = varargin{5};
            else
                % Not enough inputs.
                narginchk(6,6);
            end
           
        case 6
            % Parse and validate the following syntaxes:
            %    - (L,map,zerocolor,order,'OutputFormat',value)
            Map = varargin{2};
            Zerocolor = varargin{3};
            Order = varargin{4};
            outputFormat = varargin{6};
            
         % otherwise, narginchk(1,6) above errors out.
            
    end
end
            
% error checking for L
if iscategorical(L)
    attributes = {'2d','nonsparse'};
else    
    attributes = {'2d','nonsparse','real','finite','nonnegative','integer'};
end
validateattributes(L,{'numeric','logical','categorical'}, attributes, mfilename,'L',1);

% Convert categorical image to numeric
if iscategorical(L)
    catConverter = images.internal.utils.CategoricalConverter(categories(L));
    L = catConverter.categorical2Numeric(L);
end

% error checking for Map
[fcn, fcnchk_msg] = fcnchk(Map);
if isempty(fcnchk_msg)
    Map = fcn;
    Fcnflag = 1;
else
    if isnumeric(Map)
        if ~isreal(Map) || any(Map(:) > 1) || any(Map(:) < 0) || ...
                    ~isequal(size(Map,2), 3) || size(Map,1) < 1
          error(message('images:label2rgb:invalidColormap'));
        end
    else
        error(fcnchk_msg);
    end
end 

% Validate that the max of the label matrix is less than or equal to the
% number of colors in the colormap.
numRegion = max(double(L),[],"all");
if ~isempty(L) && isnumeric(Map) && (numRegion > size(Map,1))
    error(message('images:label2rgb:colormapNumColorsTooSmall'));
end
    
% error checking for Zerocolor
if ~ischar(Zerocolor)
    % check if Zerocolor is a RGB triple
    if ~isreal(Zerocolor) || ~isequal(size(Zerocolor),[1 3]) || ...
                any(Zerocolor> 1) || any(Zerocolor < 0)
      error(message('images:label2rgb:invalidZerocolor'));
    end
else    
    [cspec, msg] = cspecchk(Zerocolor);
    if ~isempty(msg)
	%message is translated at source.
        error(message('images:label2rgb:notInColorspec', msg))
    else
        Zerocolor = cspec;
    end
end

% error checking for Order
valid_order = {'shuffle', 'noshuffle'};
idx = strncmpi(Order, valid_order,length(Order));
if ~any(idx)
    error(message('images:label2rgb:invalidEntryForOrder'))
elseif nnz(idx) > 1
    error(message('images:label2rgb:ambiguousEntryForOrder', Order))
else
    Order = valid_order{idx};
end

% error checking for OutputFormat
outputFormat = validatestring(outputFormat,{'image','triplets'},...
    mfilename,'OutputFormat');


%  Function: parse_inputs
%  ----------------------
function outputFormatSpecified = parseOutputFormat(varargin)
if ischar(varargin{1})
    remapped = images.internal.remapPartialParamNames({'OutputFormat'},varargin{:});
    outputFormatSpecified = strcmp(remapped{1},'OutputFormat');
else
    outputFormatSpecified = false;
end

%   Copyright 1993-2024 The MathWorks, Inc.
