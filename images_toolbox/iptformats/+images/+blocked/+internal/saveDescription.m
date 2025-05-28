function saveDescription(source, description)

% Save additional information (metadata) of the source
% If file.ext, save as file.mat
% If dir, save as dir/description.mat

%   Copyright 2020 The MathWorks, Inc.
arguments
    source (1,1) string
    description
end

if ~isempty(description)
    [loc, fname, ext]= fileparts(source);
    if isempty(ext)||ext=="" && ~isfile(source) % Assume dir
        save(fullfile(source, 'description.mat'), 'description');
    else
        save(fullfile(loc, fname + ".mat"), 'description');
    end
end
end