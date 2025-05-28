classdef FilterNames < int8
% Enumeration class that holds the filter names
% This is primarily required to support input parsing during codegen for
% IRADON. 

%   Copyright 2022 The MathWorks, Inc.

    enumeration
        RamLak      (0)
        SheppLogan  (1)
        Cosine      (2)
        Hamming     (3)
        Hann        (4)
        None        (5)
        Invalid     (6)
    end
end