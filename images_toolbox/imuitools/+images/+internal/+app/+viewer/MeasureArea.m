classdef MeasureArea < images.internal.app.viewer.IMeasure
% Helper class that supports drawing area measurements on the image.
% This helper requires only an axes on which the measurement has to be
% drawn.

%   Copyright 2023, The MathWorks, Inc.

    methods
        function obj = MeasureArea()
            obj@images.internal.app.viewer.IMeasure();
        end
    end

    % Implementation of Abstract Methods
    methods(Access=protected)
        function newPoly = addImpl(obj, ax, measNum)
            newPoly = images.roi.Polygon( Parent=ax, Visible="on", ...
                                       Tag=obj.MeasBaseTag + measNum );

            addlistener(newPoly, "AddingVertex", @(src, ~) reactToROIMoved(obj, src));
            addlistener(newPoly, "DeletingVertex", @(src, ~) reactToROIMoved(obj, src));
        end

        function [measVal, measLabel] = computeMeasImpl(obj, src)
            % Perform the measurement

            % The vertices might not be positioned exactly on the pixel
            % grid locations. Compute the area independent of the pixel
            % grid to ensure the area does not vary based on polygon
            % position.
            % Using polyshape to compute areas of regions drawn using
            % interecting lines. See g3047701 for details
            warnState1 = warning("off", "MATLAB:polyshape:repairedBySimplify");
            wsOC1 = onCleanup( @() warning(warnState1) );
            warnState2 = warning("off", "MATLAB:polyshape:boundary3Points");
            wsOC2 = onCleanup( @() warning(warnState2) );
            pgon = polyshape(src.Position);
            measVal = area(pgon);

            % Create the label of the format "A<IDX> = <VAL>". This will be
            % shown along with the measurement.
            measIdx = extractAfter(src.Tag, obj.MeasBaseTag);
            measLabel = "A" + measIdx + " = " + measVal;
        end

        function measType = getMeasType(~)
            measType = "area";
        end
    end
end