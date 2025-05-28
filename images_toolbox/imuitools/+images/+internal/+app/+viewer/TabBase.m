classdef TabBase < matlab.mixin.SetGetExactNames
% Base class for classes that manage the ImageViewer toolstrip tabs

%   Copyright 2023 The Mathworks, Inc.

    properties(Access=protected)
        Tab             matlab.ui.internal.toolstrip.Tab
    end

    properties( SetAccess=private, ...
                GetAccess=?imtest.apptest.imageViewerTest.PropertyAccessProvider, ...
                Dependent )
        TabForTest
    end

    methods(Access=public)
        function obj = TabBase()
        end

        function enableAll(obj)
            enableAll(obj.Tab);
        end

        function disableAll(obj)
            disableAll(obj.Tab);
        end
    end

    methods
        function tab = get.TabForTest(obj)
            tab = obj.Tab;
        end
    end
end
