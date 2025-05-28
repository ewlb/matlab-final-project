function hyperspectralViewer(varargin)
%hyperspectralViewer Visualize hyperspectral data.
%   hyperspectralViewer opens a hyperspectral visualization app. The app can be
%   used to view individual bands, colorized representation of the
%   hyperspectral data, spectral plots and custom visulizations
%
%   hyperspectralViewer(HCUBE) loads the hypercube object HCUBE into a
%   hyperspectral visualization app.
%
%   hyperspectralViewer(CUBE) loads a 3D matrix CUBE into a hyperspectral
%   visualization app. When not loading a hypercube object, the
%   functionality of the app will be limited
%
%   hyperspectralViewer CLOSE closes all open hyperspectral viewer apps.
%
%   Class Support
%   -------------
%   HCUBE is a scalar hypercube object. 3D matrix CUBE is a real and
%   non-sparse valued MxNxP image of class uint8, uint16, uint32, int8,
%   int16, int32, single, double, uint64, int64.
%
%   Example
%   -------
%   % Construct hypercube object with Indian Pines data
%   hcube = hypercube('indian_pines.dat');
%
%   % Load the Hyperspectral Viewer App with this data
%   hyperspectralViewer(hcube);
%
%
%   See also hypercube

%   Copyright 2020-2022 The MathWorks, Inc.


breadcrumbFile = 'hyper.internal.isHyperspectalSPKGInstalled';
fullpath = which(breadcrumbFile);

if isempty(fullpath)
    
    % Not installed; throw an error
    name = 'Hyperspectral Imaging Library';
    basecode = 'HYPERSPECTRAL';
    error(message('MATLAB:hwstubs:general:spkgNotInstalled', name, basecode))

else
    
    if ~isempty(varargin)
        varargin{end+1} = inputname(1);
    end
    hyper.internal.app.viewer.hyperspectral.HyperspectralViewer(varargin{:});

end

end