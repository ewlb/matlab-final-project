function TF = isValidNetwork(net)
% Use ducktyped validation for the minimum interface we require for a
% network-like thing

% Copyright 2021 The MathWorks, Inc.

TF = isprop(net,'Learnables') && isprop(net,'Layers') &&...
    ismethod(net,'forward');
end