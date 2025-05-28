classdef (ConstructOnLoad) NavigateLREventData < event.EventData

    % Copyright 2020 The MathWorks, Inc.

    properties
        ScrollDirection
    end

    methods
        function data = NavigateLREventData(lr)
            data.ScrollDirection = lr;
        end
    end
end