classdef colorChecker  
    properties (SetAccess = private, GetAccess = public)
        Image
        
        RegistrationPoints
       
        ColorROIs struct
    end
    
    properties(Constant, Access = private)
        ReferenceLAB  = cat(3,[...
            37.5400   64.6600   49.3200   43.4600   54.9400   70.4800;
            62.7300   39.4300   50.5700   30.1000   71.7700   71.5100;
            28.3700   54.3800   42.4300   81.8000   50.6300   49.5700;
            95.1900   81.2900   66.8900   50.7600   35.6300   20.6400],...
            [14.3700   19.2700   -3.8200  -12.7400    9.6100  -32.2600;
            35.8300   10.7500   48.6400   22.5400  -24.1300   18.2400;
            15.4200  -39.7200   51.0500    2.6700   51.2800  -29.7100;
            -1.0300   -0.5700   -0.7500   -0.1300   -0.4600    0.0700],...
            [14.9200   17.5000  -22.5400   22.7200  -24.7900   -0.3700;
            56.5000  -45.1700   16.6700  -20.8700   58.1900   67.3700;
            -49.8000   32.2700   28.6200   80.4100  -14.1200  -28.3200;
            2.9300    0.4400   -0.0600    0.1400   -0.4800   -0.4600]);
        
        ReferenceCentroids = [118.5,118.5; 327.5,118.5; 536.5,118.5;
            745.5,118.5; 954.5,118.5; 1163.5,118.5;
            118.5,327.5; 327.5,327.5; 536.5,327.5;
            745.5,327.5; 954.5,327.5; 1163.5,327.5;
            118.5,536.5; 327.5,536.5; 536.5,536.5;
            745.5,536.5; 954.5,536.5; 1163.5,536.5;
            118.5,745.5; 327.5,745.5; 536.5,745.5;
            745.5,745.5; 954.5,745.5; 1163.5,745.5];
    end
    
    properties(Access = private)
        %PatchCentroids - Centroids of the chart in the actual image,
        %   obtained by applying the appropriate geometric transformation
        %   to ReferenceCentroids.
        PatchCentroids
    end
    
    methods
        
        function chart = colorChecker(Image, NameValuePairs)
            arguments
                Image {validateImage}
                NameValuePairs.Sensitivity {validateSensitivity}
                NameValuePairs.Downsample {validateDownsample}
                NameValuePairs.RegistrationPoints {validateRegistrationPoints}
            end
            
            if isfield(NameValuePairs, 'RegistrationPoints') && (isfield(NameValuePairs, 'Sensitivity')...
                    || isfield(NameValuePairs, 'Downsample'))
                error(message('images:colorChecker:invalidPVCombination'));
            end
            chart.Image                   = Image;
            if ~isfield(NameValuePairs, 'Sensitivity')
                sensitivity = 0.6;
            else
                sensitivity                   = NameValuePairs.Sensitivity;
            end
            if ~isfield(NameValuePairs, 'Downsample')
                resize = true;
            else
                resize                        = NameValuePairs.Downsample;
            end
            if isfield(NameValuePairs, 'RegistrationPoints')
                registrationPoints        = NameValuePairs.RegistrationPoints;
            else
                registrationPoints = [];
            end
            
            %%
            if isempty(registrationPoints)
                % Resize images with min_size>1000 such that min_size =1000.
                % Aspect ratio maintained.
                im = chart.Image;
                aspRatio = 1;
                if resize
                    minSize = min(size(im,[1, 2]));
                    reducedSize = 1000;
                    if minSize>reducedSize
                        aspRatio = reducedSize./minSize;
                        im = imresize(im,aspRatio);
                    end
                end
                % Preprocessing: Removing noise and thresholding
                imgray= rgb2gray(im);
                % Image is smoothened with an arbitrary neighborhood size
                % of [5 5], then adaptive thresholding is applied.
                % Neighborhood sizes for operations obtained from author's
                % code in Ref[1].
                imwien = wiener2(imgray,[5 5]);
                SE = strel('rectangle',[5 5]);
                imopened = imopen(imwien,SE);
                T = adaptthresh(imopened,sensitivity,'NeighborhoodSize',57);
                imbw = imbinarize(imopened,T);
                %% Find Contours
                % Find regions in BW image. Retain only the regions that
                % have features described at the end of page 4 in Ref[1].
                cc = bwconncomp(imbw);
                stats = regionprops(cc,'Area','Perimeter','MajorAxisLength',...
                    'MinorAxisLength','Solidity');
                if isempty(stats)
                    error(message('images:colorChecker:noPatchDetected'));
                end
                circularityFactor = (4*pi*[stats.Area])./([stats.Perimeter]).^2;
                circularityIndex = find((circularityFactor>0.65) & (circularityFactor<0.95));
                solidityIndex = find([stats.Solidity]>=0.90);
                axisIndex = find([stats.MinorAxisLength]./[stats.MajorAxisLength] >0.4);
                idx = intersect(intersect(circularityIndex,solidityIndex),axisIndex);
                if isempty(idx)
                    error(message('images:colorChecker:noPatchDetected'));
                end
                BW2 = ismember(labelmatrix(cc), idx);
                
                %% Find Candidate Patches
                % Ramer Douglas is used to simplify regions- keep only the
                % regions that are quadrilaterals (i.e. output of reducepoly
                % is a 5x2 array). Remove all regions that are too small
                % Arbitrary minSideLength of 10 obtained from author's code
                % in Ref[1].
                minSideLength = 10;
                b = bwboundaries(BW2);
                corners = [];
                for i = 1:length(b)
                    bReduced = reducepoly(b{i},0.05);
                    if (length(bReduced)==5)
                        side = zeros(1,4);
                        for j = 1:4
                            side(j) = norm(bReduced(j,:)-bReduced(mod(j,4)+1,:));
                        end
                        if min(side) >= minSideLength
                            corners = [corners, {bReduced(1:4,end:-1:1)}];
                        end
                    end
                end
                % At least 4 corners are required to calculate projective
                % transformation of the chart using fitgeotrans used in
                % checkerRecognize
                if length(corners) < 4
                    error(message('images:colorChecker:noPatchDetected'));
                end
                corners = removeNearCorners(corners);
                %% Clusters Analysis
                % Clustering based on graph representation- taking
                % connected components of graph.
                if length(corners) < 4
                    error(message('images:colorChecker:noPatchDetected'));
                end
                G = clustersAnalysis(corners);
                %% Checker Recognize
                if length(G) < 4
                    error(message('images:colorChecker:noPatchDetected'));
                end
                registrationPoints = checkerRecognize(G,corners,im,chart.ReferenceLAB);
                if isempty(registrationPoints)
                    error(message('images:colorChecker:invalidRegistrationPointsReturned'));
                else
                    registrationPoints = registrationPoints/aspRatio;
                    [m, n, ~] = size(chart.Image);
                    if rank(registrationPoints(2:end,:)-registrationPoints(1,:))< 2
                        error(message('images:colorChecker:invalidRegistrationPointsReturned'));
                    else
                        % Find fiducials given the Corner patch centroids.
                        % Based on reference measured values of Corners and
                        % Centroids on a physical Gretag Macbeth Color
                        % Checker chart.
                        refCorners = [27.5,18.05;0,18.05;0,0;27.5,0];
                        refCentroids = [25.3,15.875;2.2,15.875;2.2,2.175;25.3,2.175];
                        tform = fitgeotrans(refCentroids,registrationPoints,'projective');
                        [chart.RegistrationPoints(:,1), chart.RegistrationPoints(:,2)] = ...
                            transformPointsForward(tform,refCorners(:,1),refCorners(:,2));
                        if any(chart.RegistrationPoints(:,1)>=n)||any(chart.RegistrationPoints(:,2)>=m)
                            error(message('images:colorChecker:registrationPointsOutofBounds'));
                        elseif any(chart.RegistrationPoints(:,1)<=0)||any(chart.RegistrationPoints(:,2)<=0)
                            error(message('images:colorChecker:registrationPointsOutofBounds'));
                        end
                    end
                end
            else
                [m, n, ~] = size(chart.Image);
                if any(registrationPoints(:,1)>=n)||any(registrationPoints(:,2)>=m)
                    error(message('images:colorChecker:registrationPointsExceedSize'));
                elseif rank(registrationPoints(2:end,:)-registrationPoints(1,:))< 2
                    error(message('images:colorChecker:requireNonCollinearPoints'));
                elseif any(registrationPoints(:,1)<=0)||any(registrationPoints(:,2)<=0)
                    error(message('images:colorChecker:registrationPointsNegative'));
                else
                    chart.RegistrationPoints = registrationPoints;
                end
            end
            chart = colorCharts(chart);
        end
    end
    
    methods
        function displayChart(chart, NameValuePairs)
            arguments
                chart
                NameValuePairs.Parent {validateParentAxis}
                NameValuePairs.displayRegistrationPoints (1,1) logical = true
                NameValuePairs.displayColorROIs (1,1) logical = true
            end
            if ~isfield(NameValuePairs, 'Parent')
                parentAxes = [];
            else
                parentAxes = NameValuePairs.Parent;
            end
            registrationPoints = chart.RegistrationPoints;
            
            fig = chart.Image;
            [m, n, ~] = size(chart.Image);
            
            if NameValuePairs.displayColorROIs
                width = norm(registrationPoints(1,:)-registrationPoints(2,:))+...
                    norm(registrationPoints(3,:)-registrationPoints(4,:))/2;
                height = norm(registrationPoints(1,:)-registrationPoints(4,:))+...
                    norm(registrationPoints(2,:)-registrationPoints(3,:)/2);
                patchSize = round(min(width/24, height/16));
                roi_border = round(max(1,min([m,n])*0.005));
                Color_im = zeros(m,n);
                for numPatches = 1:24
                    ROI = chart.ColorROIs(numPatches).ROI;
                    Color_im(ROI(2):ROI(2)+ROI(4),ROI(1):ROI(1)+ROI(3)) = 1;
                    Color_im(ROI(2)+roi_border:ROI(2)+ROI(4)-roi_border,ROI(1)+...
                        roi_border:ROI(1)+ROI(3)-roi_border) = 0;
                    Color_text{numPatches} = num2str(numPatches);
                end
                fig = labeloverlay(fig,Color_im);
            end
            
            if NameValuePairs.displayRegistrationPoints
                % Display The registration points
                points_im = zeros(m,n);
                for i = 1:4
                    points_im(round(registrationPoints(i,2)),round(registrationPoints(i,1)))= 1;
                end
                bb = strel('diamond',max([1 ceil(n/200)]));
                points_im = imdilate(points_im, bb);
                fig = imoverlay(fig,points_im,'r');
            end
            
            if isempty(parentAxes)
                hIm = imshow(fig, 'Border','tight');
                set(hIm,'Tag','displayedColorChart');
                h = ancestor(hIm, 'figure');
                set(h,'Name',getString(message('images:colorChecker:colorCheckerFigureName')));
            else
                hIm = imshow(fig, 'Border','tight','Parent', parentAxes);
                set(hIm,'Tag','displayedColorChart');
                h = ancestor(hIm, 'figure');
                set(h,'Name',getString(message('images:colorChecker:colorCheckerFigureName')));
            end
            if NameValuePairs.displayColorROIs
                if isempty(parentAxes)
                    texth = text(chart.PatchCentroids(:,1)-patchSize/3,chart.PatchCentroids(:,2), Color_text,...
                        'FontSize',max(8,round(patchSize/15)),'Fontweight','bold','Color',[0 1 0]);
                else
                    texth = text(chart.PatchCentroids(:,1)-patchSize/3,chart.PatchCentroids(:,2), Color_text,...
                        'FontSize',max(8,round(patchSize/15)),'Fontweight','bold','Color',[0 1 0], 'Parent', parentAxes);
                end
                set(texth,'Clipping', 'on');
            end
        end
        
        function [colorTable, varargout] = measureColor(chart)
            nargoutchk(0,2);
            I = chart.Image;
            % Initialize resultant Table
            varNames = {'ROI','Color', 'Measured_R','Measured_G','Measured_B', 'Reference_L',...
                'Reference_a','Reference_b', 'Delta_E'};
            varTypes = {'double','string','double', 'double','double','double',...
                'double','double','double'};
            T = table('Size',[24, 9],'VariableNames',varNames, 'VariableTypes', varTypes);
            T.ROI(:) = 1:24;
            T.Color = {'DarkSkin';'LightSkin';'BlueSky';'Foliage';'BlueFlower';...
                'BluishGreen';'Orange';'PurplishBlue';'ModerateRed';'Purple';...
                'YellowGreen';'OrangeYellow';'Blue';'Green';'Red';'Yellow';'Magenta';...
                'Cyan';'White';'Neutral8';'Neutral6.5';'Neutral5';'Neutral3.5';'Black'};
            
            % Reference values from a template of the Gretag Macbeth ColorChecker
            Lab_Ref = permute(chart.ReferenceLAB,[2 1 3]);
            Lab_Ref = reshape(Lab_Ref,24,3);
            T.Reference_L = Lab_Ref(:,1);
            T.Reference_a = Lab_Ref(:,2);
            T.Reference_b = Lab_Ref(:,3);
            
            measured_R = zeros(24,1,'like',chart.Image);
            measured_G = zeros(24,1,'like',chart.Image);
            measured_B = zeros(24,1,'like',chart.Image);
            
            for i = 1:24
                measured_R(i) = mean2(chart.ColorROIs(i).ROIIntensity(:,:,1));
                measured_G(i) = mean2(chart.ColorROIs(i).ROIIntensity(:,:,2));
                measured_B(i) = mean2(chart.ColorROIs(i).ROIIntensity(:,:,3));
            end
            Lab_Measured = rgb2lab([measured_R measured_G measured_B],'Whitepoint','d50');
            T.Measured_R = measured_R;
            T.Measured_G = measured_G;
            T.Measured_B = measured_B;
            T.Delta_E = deltaE(Lab_Ref, Lab_Measured, isInputLab=true);
            colorTable = T;
            if (nargout == 2)
                varargout{1} = calculateColorCorMatrix([measured_R measured_G measured_B],...
                    lab2rgb(Lab_Ref,'WhitePoint','d50','OutputType', class(I)));
            end
        end
        
        function illum = measureIlluminant(chart)
            arguments
                chart (1,1) {isa(chart,'colorChecker'), mustBeNonempty}
            end
                        
            R_sum = 0;
            G_sum = 0;
            B_sum = 0;
            
            % 6 Grayscale colors are present in Row 4 of colorChecker chart
            for i = 19:24
                R_sum = R_sum + mean(chart.ColorROIs(i).ROIIntensity(:,:,1), 'all');
                G_sum = G_sum + mean(chart.ColorROIs(i).ROIIntensity(:,:,2), 'all');
                B_sum = B_sum + mean(chart.ColorROIs(i).ROIIntensity(:,:,3), 'all');
            end
            
            illum = double([R_sum G_sum B_sum])/6;
        end
    end
    
    
    methods (Access = private)
        %% Color Charts
        function chart = colorCharts(chart)
            registrationPoints = chart.RegistrationPoints;
            
            if ~isempty(registrationPoints)
                refCorners = [27.5,18.05;0,18.05;0,0;27.5,0];
                refCentroids = [25.3,15.875;2.2,15.875;2.2,2.175;25.3,2.175];
                xform = fitgeotrans(refCorners,registrationPoints,'projective');
                [registrationPoints(:,1), registrationPoints(:,2)] = transformPointsForward(xform,...
                    refCentroids(:,1),refCentroids(:,2));
                % Centroids of the Black, White, Dark Skin and Bluish Green patches
                % of reference image
                templateBoxCenters = [chart.ReferenceCentroids(24,:); chart.ReferenceCentroids(19, :);...
                    chart.ReferenceCentroids(1, :); chart.ReferenceCentroids(6,:)];
                
                % Projective transform matrix
                xform = fitgeotrans(templateBoxCenters, registrationPoints, 'projective');
                BoundingBox = [chart.ReferenceCentroids-92,ones(24,2).*184];
                % Bounding box values generated from a synthetic template
                % which has smaller patches(around 50% of original patch)
                % of the ColorChecker chart
                BoundingBoxSubIm = [BoundingBox(:,1:2)+46, ones(24,2)*91];
                
                for numPatches = 1:24
                    % Get the corner points of the bounding box
                    pointsSubIm = getPoints(BoundingBoxSubIm(numPatches,:));
                    PatchCornerSubIm = xform.transformPointsForward(pointsSubIm);
                    ColorPatch(numPatches,:) = [PatchCornerSubIm(1,:) PatchCornerSubIm(2,:)...
                        PatchCornerSubIm(3,:) PatchCornerSubIm(4,:)];
                end
                ratio = 0.8; %To ensure the region selected lies within the patch at all orientations
                half_ColorPatch_width = round(ratio*norm(ColorPatch(1,1:2)- ColorPatch(1,3:4))/2);
                half_ColorPatch_height = round(ratio*norm(ColorPatch(1,1:2)- ColorPatch(1,7:8))/2);
                
                ColorROI = repmat(struct('ROI',zeros(1,4),'ROIIntensity',zeros(2*half_ColorPatch_height+1, 2*half_ColorPatch_width+1, 3)),24,1);
                
                for i=1:24
                    x_cen = round(mean(ColorPatch(i,1:2:7)));
                    y_cen = round(mean(ColorPatch(i,2:2:8)));
                    ColorROI(i).ROI = [x_cen-half_ColorPatch_width, y_cen-half_ColorPatch_height,...
                        2*half_ColorPatch_width+1, 2*half_ColorPatch_height+1];
                    ColorROI(i).ROIIntensity = chart.Image(y_cen-half_ColorPatch_height:y_cen+half_ColorPatch_height,...
                        x_cen-half_ColorPatch_width:x_cen+half_ColorPatch_width,:);
                end
                
                chart.PatchCentroids = xform.transformPointsForward(chart.ReferenceCentroids);
                chart.ColorROIs = ColorROI;
                
            else
                error(message('images:colorChecker:invalidChartObject'));
            end
        end
        
    end
end
function corners = removeNearCorners(corners)
% Check if any candidate patches are too close to each other - keep the one
% with larger perimeter. Returns logical array indicating which patches to keep
removalMask = true(length(corners),1);
for i = 1:length(corners)
    for j = i+1:length(corners)
        v = vecnorm(corners{i}- corners{j},2,2);
        v = v.*v/4;
        distSquared = sum(v);
        if distSquared <100
            % Find perimeter of each candidate patch by calculating distance
            % between adjacent corner points(1&2, 2&3, 3&4, 4&1).
            side1 = vecnorm(corners{i}-circshift(corners{i},1),2,2);
            side2 = vecnorm(corners{j}-circshift(corners{j},1),2,2);
            if sum(side1)<sum(side2)
                removalMask(i) = false;
            else
                removalMask(j) = false;
            end
        end
    end
end
corners = corners(removalMask);
end

%% Cluster Analysis
% Hierarchical Compact Algorithm (HCA) is applied to candidate patches and
% groups of patches are assigned based on the connected components of the
% graph. See page 5 (eq.2,3) in Ref[1]. (area = A (area corresponding to i-th
% patch), center = X (i-th patch center), weight = w_ij (w_ij = |Ai-Aj|/Ai+Aj),
% dist = d_ij (d_ij = w_ij*||Xi-Xj||).)
function G = clustersAnalysis(corners)
N = length(corners);
G = zeros(N,1); %Group index
B0 = zeros(1,N); %Threshold dist, under which edge exists
area = zeros(1,N);
center = zeros(N,2);
for i = 1:N
    cornersSub = corners{i};
    axis(1) = norm(cornersSub(1,:)-cornersSub(3,:));
    axis(2) = norm(cornersSub(2,:)-cornersSub(4,:));
    B0(i) = max(axis)*1.45;
    center(i,:) = mean(cornersSub);
    area(i) = polyarea(cornersSub(:,1), cornersSub(:,2));
end

% Find edges based on Ref[1] (eq.2)
for i = 1:N-1
    k = 1;
    edge = zeros(N-i,1);
    for j = i+1:N
        d = norm(center(i,:)-center(j,:));
        w = abs((area(i)-area(j)))/(area(i)+area(j));
        % w should be less than 0.3 - an arbitrary value.
        dist = (w<0.3).*d;
        edge(k) = (dist<B0(i))*dist;
        k = k+1;
    end
    if (G(i) == 0)
        G(i) = i+1;
    end
    % Patches are considered members of a 'group' if an edge exists.
    % Multiple groups are reduced to the same group when there exists
    % common elements/patches for which there is an edge.
    posB0 = find(edge);
    if ~isempty(posB0)
        posB0 = posB0 + i;
        posNz = find(G(posB0));
        posZ = posB0(~G(posB0));
        G(posZ) = G(i);
        if (~isempty(posNz))
            posNz = posB0(posNz);
            g = unique(G(posNz));
            G(ismember(G,g)) = G(i);
        end
    end
end
% Check if the last patch is part of any group.
if (~(G(N)))
    G(N) = N;
end
S = unique(G);
for k = 1:length(S)
    G(G == S(k)) = k;
end
end

%% Checker Recognize
function registrationPoints = checkerRecognize(G,cornersNew,im,labRef)
% Each group of patches are analyzed - discard groups with <4 elements,
% then find the minimum enclosing quadrilateral. The orientation of the
% chart in the image is found and group which has least color distance
%(error) is returned.
Nc = length(unique(G));
chartError = Inf(Nc,1);
registrationPoints = [];

% Attributes of reference color checker chart with arbitrary area
sizeRef.width = 4;
sizeRef.height = 6;
centerRef = [1.5, 1.5; 4.25,1.5; 7, 1.5; 9.75, 1.5; 12.5, 1.5; 15.25, 1.5;
    1.5, 4.25; 4.25, 4.25; 7, 4.25; 9.75, 4.25; 12.5, 4.25; 15.25, 4.25;
    1.5, 7; 4.25, 7; 7, 7; 9.75, 7; 12.5,7; 15.25, 7;
    1.5, 9.75; 4.25, 9.75; 7, 9.75; 9.75, 9.75; 12.5,9.75; 15.25,9.75];

% Each group is analyzed for a valid Color Checker chart
for chartGroup = 1:Nc
    chartSub = find(G ==chartGroup);
    cornersSub = cornersNew(chartSub);
    lengthSubChart = length(chartSub);
    if (lengthSubChart<4)
        continue;
    end
    subChartCenters = zeros(lengthSubChart,2);
    subChartCorners = [];
    for i = 1:lengthSubChart
        subChartCorners = [subChartCorners; cornersSub{i}];
        subChartCenters(i,:) = mean(cornersSub{i});
    end
    % Min bounding quadrilateral
    Corners = minBoundingQuadrilateral(chartSub,subChartCorners);
    if (length(Corners)<4 || ~all(isfinite(Corners),'all'))  % ensures Corners are valid (i.e. not +/- Inf)
        continue;
    end
    % Create a reference chart with same height to width ratio as detected
    % minimum Bounding quadrilateral - find the transformation.
    Corners = polyanticlockwise(Corners);
    aspRatio = norm(Corners(4,:) - Corners(1,:))/norm(Corners(2,:) - Corners(1,:));
    h = floor(100*aspRatio + 0.5);
    chartPhysical = [0,0; 100,0; 100,h; 0,h];
    try
        tform = fitgeotrans(Corners,chartPhysical,'projective');
    catch
        continue;
    end
    chartPhysicalCenters = zeros(lengthSubChart,2);
    chartPhysicalCorners = zeros(4*lengthSubChart,2);
    [chartPhysicalCenters(:,1), chartPhysicalCenters(:,2)] = transformPointsForward(tform,subChartCenters(:,1),subChartCenters(:,2));
    [chartPhysicalCorners(:,1), chartPhysicalCorners(:,2)] = transformPointsForward(tform,subChartCorners(:,1),subChartCorners(:,2));
    % Find average height and width of patches.
    wchart = zeros(lengthSubChart,2);
    hchart = zeros(lengthSubChart,2);
    for i = 1:lengthSubChart
        k = (i-1)*4;
        wchart(i,:) = chartPhysicalCorners(k+2,:) - chartPhysicalCorners(k+1,:);
        hchart(i,:) = chartPhysicalCorners(k+4,:) - chartPhysicalCorners(k+1,:);
    end
    wchart = mean(vecnorm(wchart,2,2));
    hchart = mean(vecnorm(hchart,2,2));
    
    % Centers and color estimates
    chartXReduced = reduceArray(chartPhysicalCenters(:,1)',hchart/2);
    chartYReduced = reduceArray(chartPhysicalCenters(:,2)',wchart/2);
    im = im2double(im);
    
    % Color and center rectification
    k = 1;
    centerEstimate = [];
    srgb = [];
    for i = 1:length(chartYReduced)
        for j = 1:length(chartXReduced)
            centerEstimate(k,:) = [chartXReduced(j), chartYReduced(i)];
            % Find color at coordinate on image corresponding to the
            % estimated centers on physical chart.
            p = [centerEstimate(k,1);centerEstimate(k,2);1];
            xt = (tform.T')\p;
            x = floor(xt(1,1)./xt(3,1));
            y = floor(xt(2,1)./xt(3,1));
            % Calculate the mean color in a small arbitrary region around
            % the centroid of each patch. This 7x7 region is chosen to
            % ensure the points lie inside the patch (which has a minimum
            % side of 10.
            srgb(i,j,:) = mean(mean(im(y-3:y+3,x-3:x+3,1:3)),2);
            k = k+1;
        end
    end
    if isempty(centerEstimate)
        continue;
    end
    scm =[];
    scm.centers(:,:) = centerEstimate;
    scm.width = length(chartXReduced);
    scm.height = length(chartYReduced);
    scm.subChart = reshape(srgb, scm.height*scm.width,3);
    % If the 24 patches are not found, first, the orientation of the chart
    % is determined by finding the minimum color error wrt different rotations
    % of the reference chart.
    if length(centerEstimate)<=24
        [beval,offset,iTheta] = evaluate(scm,labRef);
        if ~beval
            continue
        end
        if (iTheta ==1 || iTheta ==3)
            size.width = sizeRef.height;
            size.height = sizeRef.width;
            center = sortrows(centerRef);
        else
            size = sizeRef;
            center = centerRef;
        end
        
        % Calculate the centers of the remaining patches by first finding
        % the transformation undergone by the known centers of the reference
        % to get ctss, and applying the same transformation to all the centers.
        cols = size.height - scm.width + 1;
        x = floor(offset/cols);
        y = mod(offset, cols);
        p = 1;
        ctss = [];
        for i = x:x+scm.height-1
            for j = y:y+scm.width-1
                iter = i*size.height + j;
                ctss(p,:) = center(iter+1,:);
                p= p+1;
            end
        end
        if isempty(ctss)
            continue;
        end
        point_ac = sum(ctss,1);
        if (point_ac(1) == ctss(1,1) * p || point_ac(2) == ctss(1,2)*p)
            continue;
        end
        
        try
            ccTe = fitgeotrans(ctss,centerEstimate,'projective');
        catch
            continue;
        end
        
        [center_patch(:,1), center_patch(:,2)] = transformPointsForward(ccTe,center(:,1),center(:,2));
        patches = transformPointsInverse(tform,center_patch);
        
        % Find the cost (color error) of each color checker chart found in
        % the image. If  chartError is inf, the estimated chart is invalid.
        chartError(chartGroup) = costPatches(patches,labRef,im,iTheta);
        if isinf(chartError(chartGroup))
            continue;
        end
        % The index of the corner patches depends on portrait/landscape
        % orientation of the chart in the image.
        if (iTheta ==1 || iTheta ==3)
            [centerPatch(:,1), centerPatch(:,2)] = transformPointsForward(ccTe,...
                center([1 4 21 24],1),center([1 4 21 24],2));
            centerPatch = transformPointsInverse(tform,centerPatch);
        else
            [centerPatch(:,1), centerPatch(:,2)] = transformPointsForward(ccTe,...
                center([1 6 19 24],1),center([1 6 19 24],2));
            centerPatch = transformPointsInverse(tform,centerPatch);
        end
        % Specify centroid of corner patches in the order of color
        % patches required in RegistrationPoints, based on orientation.
        if all(isfinite(Corners),'all')
            switch (iTheta)
                case 1
                    registrationPoints{chartGroup} = centerPatch([3 1 2 4],:); %#ok<*AGROW>
                case 2
                    registrationPoints{chartGroup} = centerPatch([1 2 4 3],:);
                case 3
                    registrationPoints{chartGroup} = centerPatch([2 4 3 1],:);
                case 4
                    registrationPoints{chartGroup} = centerPatch([4 3 1 2],:);
            end
        end
    end
end
if isempty(registrationPoints)
    return;
end
% Return the chart with minimum color error, filtering out invalid charts.
if isfinite(min(chartError))
    [~,ind] = min(chartError);
    registrationPoints = registrationPoints{ind};
end
end

function Corners = minBoundingQuadrilateral(chartSub, X)
% Find the minimum Bounding Quadrilateral based on [1] Algorithm 1
N = length(chartSub);
mu = mean(X,1);
X = X-mu;
L = zeros(N*4,3);
% Algorithm 1: Step 1
for i = 0:N-1
    ind = 4*i;
    X(ind+1:ind+4,1:2) = polyanticlockwise(X(ind+1:ind+4,1:2));
    l0 = [X(ind + 1,1:2), 1];
    l1 = [X(ind + 2,1:2), 1];
    l2 = [X(ind + 3,1:2), 1];
    l3 = [X(ind + 4,1:2), 1];
    
    L(ind + 1,:) = cross(l0,l1);
    L(ind + 2,:) = cross(l1,l2);
    L(ind + 3,:) = cross(l2,l3);
    L(ind + 4,:) = cross(l3,l0);
end

% Algorithm 1: Step 2
dist = zeros(1,4*N);
for i = 1:4*N
    n = L(i,1:2);
    d = L(i,3);
    s = 0;
    for j = 1:N
        if ((dot(X(j,:),n) + d) <=0)
            s = s+1;
        end
    end
    dist(i) = s;
end
[dist, idx] = sort(dist);
L = L(idx,:);
Lc = L(1,:);
k = 2;

% Algorithm 1: Step 3
for i = 2:4*N
    line = L(i,:);
    [x, j] = validateLine(Lc, line, k);
    if (x==0)
        Lc(k,:) = line;
        k =k+1;
    elseif ((abs(Lc(j,3))<abs(line(3))) && (abs(dist(i)-dist(j))<2))
        Lc(j,:) = line;
    end
    if (k ==5) && abs(dist(i) - dist(k - 1)) > 2
        break;
    end
end
if(k<5)
    return;
end

% Algorithm 1: Step 4
thetas = zeros(1,4);
for i = 1:4
    thetas(i) = atan2((Lc(i,2)/Lc(i,3)),(Lc(i,1)/Lc(i,3)));
end
[~, idx] = sort(thetas,'descend');
Lc = Lc(idx,:);
Corners = zeros(4,2);
for i= 1:4
    Vcart = cross(Lc(mod(i,4)+1,:),Lc(i,:));
    Corners(i,:) = [Vcart(1)/Vcart(3),Vcart(2)/Vcart(3)];
end
Corners = Corners+mu;
end

function cr = reduceArray(center,tol)
n = length(center);
center = sort(center);
label = zeros(1,n);
% Finding the difference in centers of patches 14&1, 1&2, ... 13&14 and
% choose the transitions where difference is greater than tolerance. If
% transitions are greater than 4*tolerance, insert an additional element
% in between.
for i = 1:n
    label(i) = abs(center(mod(n+i-2,n)+1)-center(i));
end
label = cumsum(label>tol);
uLabel = unique(label);
uLabellength = length(uLabel);
cr = zeros(1,uLabellength);
for i = 1:uLabellength
    cr(i) = mean(center(label==uLabel(i)));
end
dif = zeros(1,uLabellength-1);
for i = 1:uLabellength-1
    dif(i) = cr(mod(i,uLabellength)+1) - cr(i);
end
[fmax, idx] = max(dif(1:end-1));
if fmax > 4*tol
    cr = [cr(1:idx) (cr(idx)+cr(idx+1))/2 cr(idx+1:end)];
end
end

function [beval, offset, iTheta, error] = evaluate(scm,lab)
% Find the orientation of the chart by finding the closest match in terms
% of the color error wrt a reference chart that is rotated in the following:
% 0,90,180,270 degrees. Based on Ref[1] (eq. 4,5).
error = inf;
beval = false;
offset = 0;
iTheta = 1;
labEst = rgb2lab(scm.subChart);
for tTheta = 1:4
    [retval, tError, tOffset] = match(scm,tTheta,lab,labEst);
    if(retval && tError<error)
        error = tError;
        iTheta = tTheta;
        offset = tOffset;
        beval = true;
    end
end
end

function [retval, error, ierror] = match(scm,iTheta,lab,labEst)
switch (iTheta)
    case 1 % rotate 90 counter-clockwise
        lab = permute(lab,[2 1 3]);
        lab = fliplr(lab);
    case 2 % rotate 180
        lab = fliplr(lab);
        lab = flip(lab);
    case 3 % rotate 90 clockwise
        lab = permute(lab,[2 1 3]);
        lab = flip(lab);
end
[N, M] = size(lab,1:2);
n = scm.height;
m = scm.width;

if N<n || M< m
    retval = false;
    error = 0;
    ierror = 0;
    return;
end
% Reshape the rotated reference to be of same dimensions as the detected chart
% and find the color error between the two.
k = 1;
for i = 1:M-m+1
    for  j= 1:N-n+1
        labRot = reshape(reshape(lab(j:j+n-1, i:i+m-1,:), n*m,3), n*m,3);
        lEcm(k) = distColorLab(labRot,labEst)/(M*N);
        k = k+1;
    end
end
[error, ierror] = min(lEcm);
ierror = ierror -1;
retval = true;
end

function colorDist = distColorLab(lab1,lab2)
N = size(lab1,1);
v1 = [ones(N,1) lab1(:,2:3)];
v2 = [ones(N,1) lab2(:,2:3)];
colorDist = mean(vecnorm(v1-v2,2,2));
end

function  [x,j] = validateLine(Lc,ln,k)
% Algorithm 1: Step 3
line1 = ln(1:2);
for j = 1:k-1
    line2 = Lc(j,1:2);
    theta = dot(line2,line1)/(norm(line2)*norm(line1));
    if (acos(theta)<0.52) % theta should be >30 degrees
        x = 1;
        return;
    end
end
x =0;
end

function  Corners = polyanticlockwise(Corners)
v1 = Corners(2,:) - Corners(1,:);
v2 = Corners(3,:) - Corners(1,:);
if (v1(:,1)* v2(:,2) - v1(:,2)*v2(:,1))<0.0
    x(:,:) = Corners(4,:);
    Corners(4,:) = Corners(2,:);
    Corners(2,:) = x(:,:);
end
end

function chartError = costPatches(patches,lab,im,iTheta)
% Find the chart error, which is the total color error on detecting all 24
% color patches and comparing them with a reference, based on the
% orientation detected.
switch (iTheta)
    case 1
        patchreshape = reshape(patches,4,6,2);
        patchflip = flip(patchreshape);
        patchfinal = reshape(patchflip,24,2);
    case 2
        patchreshape = reshape(patches,6,4,2);
        patchflip = fliplr(patchreshape);
        patchfinal =  rot90(patchflip,3);
        patchfinal = reshape(patchfinal,24,2);
    case 3
        patchreshape = reshape(patches,4,6,2);
        patchflip = fliplr(patchreshape);
        patchfinal = reshape(patchflip,24,2);
    case 4
        patchreshape = reshape(patches,6,4,2);
        patchflip = permute(patchreshape,[2 1 3]);
        patchfinal = reshape(patchflip,24,2);
end
rgbMeasured = zeros(24,3);
% Checking if any patches are estimated to be outside the bounds of the image. 
% In such cases, the chartError is set to be infinite so that this chart
% will not be considered valid. 
[m,n,~] = size(im);
if any(floor(patchfinal(:,2))>m) || any(floor(patchfinal(:,1))>n)...
        || any(floor(patchfinal(:,2))<0) || any(floor(patchfinal(:,1))<0)
    chartError = inf;
    return;
end
for i = 1:24
    rgbMeasured(i,:) = im(floor(patchfinal(i,2)),floor(patchfinal(i,1)),1:3);
end
labMeasured = rgb2lab(rgbMeasured);
labRef = reshape(lab, 24,3);
chartError = distColorLab(labRef,labMeasured)/(24);
end

function colorCorMatrix = calculateColorCorMatrix(measured_RGB, reference_RGB)
measured_RGB = double(measured_RGB);
reference_RGB = double(reference_RGB);
appendedRGB = [measured_RGB ones(size(measured_RGB,1),1)];
colorCorMatrix = (appendedRGB' * appendedRGB) \ appendedRGB' * reference_RGB;
end

function points = getPoints(bbox)
points = zeros(4, 2, 'like', bbox);
% Points from upper-left, then clockwise
points(1,:) =  bbox(1:2);
points(2,:) = [bbox(1) + bbox(3), bbox(2)];
points(3,:) = [bbox(1) + bbox(3), bbox(2) + bbox(4)];
points(4,:) = [bbox(1), bbox(2) + bbox(4)];
end

%% Input Validation
function B = validateSensitivity(Sensitivity)
supportedClasses = {'single','double'};
attributes = {'nonempty','real','scalar','>=',0,'<=',1,'finite','nonsparse','nonnan'};
validateattributes(Sensitivity,supportedClasses,attributes);
B = true;
end

function B = validateRegistrationPoints(RegistrationPoints)
supportedClasses = {'double'};
attributes = {'nonempty','real','finite','nonsparse','nonnan','size',[4 2]};
validateattributes(RegistrationPoints,supportedClasses,attributes);
B = true;
end

function B = validateDownsample(Downsample)
supportedClasses = {'numeric','logical'};
attributes = {'nonempty','real','finite','nonsparse','scalar','nonnan'};
validateattributes(Downsample,supportedClasses,attributes);
B = true;
end

function validateImage(im)
supportedClasses = {'uint8','uint16','single','double'};
attributes = {'real','nonsparse','3d'};
validateattributes(im,supportedClasses,attributes);
validColorImage = (ndims(im) == 3) && (size(im,3) == 3);
if ~validColorImage
    error(message('images:colorChecker:invalidRGBImage'));
end
end

function validateParentAxis(Parent)
validateattributes(Parent, {'matlab.graphics.axis.Axes'},{'nonempty','nonsparse'});
end

% Copyright 2019-2023 The MathWorks, Inc.