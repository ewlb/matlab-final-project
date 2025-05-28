function volumeViewer(varargin)
%

%   Copyright 2016-2023 The MathWorks, Inc.

import matlab.internal.capability.Capability
isRunningOnMLOnline = ~Capability.isSupported(Capability.LocalClient);
if isRunningOnMLOnline
    error(message('images:volumeViewer:matlabOnlineNotSupported'));
end

if nargin>0 && ~ischar(varargin{1})
    source1Name = inputname(1);
    varargin = {varargin{1}, source1Name, varargin{2:end}};
end

if nargin>1 && images.internal.app.volview.isVolume(varargin{3})
    source2Name = inputname(2);
    varargin = {varargin{1:3}, source2Name, varargin{4:end}};
end

images.internal.app.volview.VolumeViewer(varargin{:});



