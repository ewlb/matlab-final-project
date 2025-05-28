function outputImage = interp3dImpl(inputImage,X,Y,Z,fillValue) %#codegen

% Copyright 2023 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(inputImage,X,Y,Z,fillValue);

outputImage = coder.nullcopy(zeros(size(X),'like',inputImage));

[nRows,nCols,nPlanes] = size(X);

[numImageRows,numImageCols,numImagePlanes] = size(inputImage);

if isa(inputImage,'double')
    inputImageDouble = inputImage;
else
    inputImageDouble = double(inputImage);
end

% Loop Scheduler
schedule = coder.loop.Control;

if coder.isColumnMajor()
    schedule = schedule.parallelize('j');
else
    schedule = schedule.interchange('i','k').parallelize('k');
end

% Apply Loop Scheduler
schedule.apply

for k =1:coder.internal.indexInt(nPlanes)
    for j = 1:coder.internal.indexInt(nCols)
        for i = 1:coder.internal.indexInt(nRows)
            queryX = X(i,j,k);
            queryY = Y(i,j,k);
            queryZ = Z(i,j,k);

            voxelInBounds = (queryX >= 1) && (queryX <= numImageCols) && ...
                (queryY >= 1) && (queryY <= numImageRows) && ...
                (queryZ >= 1) && (queryZ <= numImagePlanes);

            if (voxelInBounds)
                x0 = floor(queryX);
                y0 = floor(queryY);
                z0 = floor(queryZ);

                x1 = ceil(queryX);
                y1 = ceil(queryY);
                z1 = ceil(queryZ);

                xd = queryX - x0;
                yd = queryY - y0;
                zd = queryZ - z0;

                oneMinusXd = 1-xd;

                c00 = inputImageDouble(y0,x0,z0)*oneMinusXd  + inputImageDouble(y0,x1,z0)*xd;
                c10 = inputImageDouble(y1,x0,z0)*oneMinusXd  + inputImageDouble(y1,x1,z0)*xd;
                c01 = inputImageDouble(y0,x0,z1)*oneMinusXd  + inputImageDouble(y0,x1,z1)*xd;
                c11 = inputImageDouble(y1,x0,z1)*oneMinusXd  + inputImageDouble(y1,x1,z1)*xd;

                oneMinusYd = (1-yd);
                c0 = c00*oneMinusYd + c10*yd;
                c1 = c01*oneMinusYd + c11*yd;

                if isfloat(inputImage)
                    outputImage(i,j,k) =  eml_cast(c0*(1-zd) + c1*zd, class(inputImage));
                else
                    outputImage(i,j,k) =  eml_cast(c0*(1-zd) + c1*zd + 0.5, class(inputImage), 'floor');
                end
            else
                outputImage(i,j,k) = fillValue;
            end
        end
    end
end
end