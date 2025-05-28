classdef MeasureDist < images.internal.app.viewer.IMeasure
% Helper class that supports drawing distance measurements on the image.
% This helper requires only an axes on which the measurement has to be
% drawn.

%   Copyright 2023, The MathWorks, Inc.

    methods
        function obj = MeasureDist()
            obj@images.internal.app.viewer.IMeasure();
        end
    end

    % Implementation of Abstract Methods
    methods(Access=protected)
        function newLine = addImpl(obj, ax, measNum)
            newLine = images.roi.Line( Parent=ax, Visible="on", ...
                                       Tag=obj.MeasBaseTag + measNum );
        end

        function [measVal, measLabel] = computeMeasImpl(obj, src)
            % Perform the measurement computation

            % Compute the euclidean distance
            pos = src.Position;
            delta = pos(2,:) - pos(1,:);
            
            measVal = hypot(delta(1), delta(2));
            measIdx = extractAfter(src.Tag, obj.MeasBaseTag);

            % Create the label of the format "D<IDX> = <VAL>". This will be
            % shown along with the measurement.
            measLabel = "D" + measIdx + " = " + measVal;
        end

        function measType = getMeasType(~)
            measType = "distance";
        end
    end
end
