function mask = circles2mask(centers,radii,mask_size)
    arguments
        centers   (:,2) double {mustBeReal}
        radii     (:,1) double {mustBeVector,mustBeReal,mustBeNonnegative}
        mask_size (1,2) double {mustBeInteger,mustBeNonnegative}
    end

    num_radii = length(radii);
    num_circles = size(centers,1);

    % If only one radius is specified, use that value for all the circles.
    if (num_radii == 1)
        radii = repmat(radii,num_circles,1);
    else
        if (num_radii ~= num_circles)
            error(message("images:circles2mask:sizeMismatch"))
        end
    end

    % Initialize the output mask.
    mask = false(mask_size);
    [M,N] = size(mask);

    % Process each circle.
    for k = 1:num_circles
        xc = centers(k,1);
        yc = centers(k,2);
        r = radii(k);

        % Find the submatrix of mask that completely contains the portion
        % of this circle that lies within the bounds of the image. First,
        % find the smallest bounding box with integer coordinates that
        % contains the circe. The bounding box goes from x1 to x2
        % horizontally and from y1 to y2 vertically.
        x1 = floor(xc - r);
        x2 = ceil(xc + r);
        y1 = floor(yc - r);
        y2 = ceil(yc + r);

        % Next, clip the bounding box to the domain of the image.
        ix1 = max(x1,1);
        ix2 = min(x2,N);
        iy1 = max(y1,1);
        iy2 = min(y2,M);

        % Construct subscript values that can be used to extract and to
        % assign into a submatrix of mask.
        xx = ix1:ix2;
        yy = (iy1:iy2)';

        % For the submatrix defined by the indices xx and yy, compute which
        % pixels lie within (or on the perimeter of) the circle.
        submask = hypot(xx - xc, yy - yc) <= r;

        % Update the mask submatrix.
        mask(yy,xx) = mask(yy,xx) | submask;
    end
end

% Copyright 2023 The MathWorks, Inc.