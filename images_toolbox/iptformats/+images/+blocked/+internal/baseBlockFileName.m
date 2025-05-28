function blockFileName = baseBlockFileName(source, level, blockSub)
%

%   Copyright 2020 The MathWorks, Inc.

%Example:
% source : /tmp
% level  : 1
% blockSub: [1 1]
% Results in /tmp/L1/1_1
% The caller then appends the extension required.

fname = sprintf('%d_', blockSub);
fname = fname(1:end-1); % trim the trailing _.
blockFileName = [char(source), filesep, ['L', num2str(level)], filesep, fname];
end
