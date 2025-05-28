function y = implay(varargin) 

%

% Error for MATLAB Online
matlab.internal.capability.Capability.require(...
    matlab.internal.capability.Capability.LocalClient);

args = matlab.images.internal.stringToChar(varargin);
nargs = nargin;
names = cell(1, nargs);
for indx = 1:nargs
    names{indx} = inputname(indx);
end

hScopeCfg = iptscopes.IMPlayScopeCfg(args, ...
    uiservices.cacheFcnArgNames(names));

% Create new scope instance.
obj = uiscopes.new(hScopeCfg);

if nargout > 0
    y = obj;
end

%   Copyright 2007-2023 The MathWorks, Inc.
