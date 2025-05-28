function createFolder(dstFolder)
%

%   Copyright 2020 The MathWorks, Inc.

if isfolder(dstFolder)||isempty(dstFolder)
    return
end

[created, failMessage] = mkdir(dstFolder);
if ~created
    error(message('images:blockedImage:unableToCreateDir',dstFolder, failMessage))
end
end