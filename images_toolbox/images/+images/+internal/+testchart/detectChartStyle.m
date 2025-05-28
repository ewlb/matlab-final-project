function Style = detectChartStyle(ImageGray,RegistrationPoints)
%detectChartStyle will detect the Style of the chart input by the
%user. Based on the detected registration points, isolate the area of the
%chart containing the alignment points. Style detection is performed
%based on the number and orientation of alignment points
        indexPoint = RegistrationPoints(4,:);
        distancesRegistrationPoints12 = norm(RegistrationPoints(1,:)-RegistrationPoints(2,:));
        distancesRegistrationPoints34 = norm(RegistrationPoints(3,:)-RegistrationPoints(4,:));
        scalingFactor = (1/188)*mean([distancesRegistrationPoints12 distancesRegistrationPoints34]);
        ImageAlignmentPoints = ImageGray(round(indexPoint(2) - 60*scalingFactor : indexPoint(2)),...
            round(indexPoint(1) - 50*scalingFactor : indexPoint(1) + 50*scalingFactor));
        
        %detect dark circles in region containing alignment points
        [centers,radii,metric] = imfindcircles(ImageAlignmentPoints,round([5 8]*scalingFactor),'ObjectPolarity','dark','Method','TwoStage');
        if (isempty(centers))
            error(message('images:esfrChart:noDetectStyle'));
        end
        
        %Using the scaling factor and the known positions of centers of 
        %black dots in the original chart image, estimate the positions of
        %centers of black dots in the user-input chart
        estimatedCenters = [50*scalingFactor - 27.73*scalingFactor, 60*scalingFactor - 23.64*scalingFactor;...
            50*scalingFactor, 60*scalingFactor - 23.64*scalingFactor;...
            50*scalingFactor + 14.9*scalingFactor, 60*scalingFactor - 40.35*scalingFactor];
        
        %Find distance between estimated and detected center positions
        centersRepeated = repmat(centers,[size(estimatedCenters,1) 1]);
        estimatedCentersRepeated = repelem(estimatedCenters,size(centers,1),1);
        distanceCenters = vecnorm(centersRepeated-estimatedCentersRepeated,2,2);
        distanceCenters = reshape(distanceCenters,[size(centers,1) size(estimatedCenters,1)]);
        %Detect which alignment points are present in chart image        
        checkInside = distanceCenters<repmat(radii,[1 3]);
        detectedCircles = any(checkInside,1);
        
        if(detectedCircles == [1 1 0])
                Style='Extended';
        elseif(detectedCircles == [0 1 0])
                Style='Enhanced';
        elseif(detectedCircles == [0 1 1])
                Style='WedgeEnhanced';
        elseif(detectedCircles == [1 1 1])
                Style='WedgeExtended';
        else
            error(message('images:esfrChart:noDetectStyle'));
        end
                    
end

