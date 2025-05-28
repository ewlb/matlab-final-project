function description = loadDescription(source)

% Load additional information (metadata) of the source
% If file.ext, look for file.mat
% If dir, look for dir/description.mat

%   Copyright 2020 The MathWorks, Inc.


arguments
    source (1,1) string
end

description = struct([]);

if isfile(source)
    [loc, fname]= fileparts(source);
    matfile = loc + filesep + fname + ".mat";
else
    matfile = source + filesep + "description.mat";
end

if isfile(matfile)
    description = load(matfile);
    if isfield(description, 'description')
        description = description.description;
    end
end
end