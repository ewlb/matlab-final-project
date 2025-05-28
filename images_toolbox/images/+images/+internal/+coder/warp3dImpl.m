function outputImage = warp3dImpl(inputImage, tform, dstImageSize, fillValues, interpString) %#codegen

% Copyright 2023 The MathWorks, Inc.

coder.inline('always');
coder.internal.prefer_const(inputImage, tform, dstImageSize, fillValues, interpString);

outputImage = coder.nullcopy(zeros(dstImageSize, 'like', inputImage));

nRows = dstImageSize(1);
nCols = dstImageSize(2);
nPlanes = dstImageSize(3);

[numImageRows, numImageCols, numImagePlanes] = size(inputImage);

if isa(inputImage,'double')
    inputImageDouble = inputImage;
else
    inputImageDouble = double(inputImage);
end

interpMethod = stringToInterpType(interpString);

% Loop Scheduler
schedule = coder.loop.Control;

if coder.isColumnMajor()
    schedule = schedule.parallelize('j');
else
    schedule = schedule.interchange('i','k').parallelize('k');
end

% Apply Loop Scheduler
schedule.apply

for k = 1:nPlanes
    for j = 1:nCols
        for i = 1:nRows
            queryf = cast(i*tform(6) + j*tform(5) + k*tform(7) + tform(8), 'like', inputImageDouble);
            querys = cast(i*tform(2)+ j*tform(1) + k*tform(3) + tform(4), 'like', inputImageDouble);
            queryt = cast(i*tform(10) + j*tform(9) + k*tform(11) + tform(12), 'like', inputImageDouble);

            voxelInBounds = isVoxelInBounds(queryf, querys, queryt, ...
                numImageRows, numImageCols, numImagePlanes, interpMethod);

            if voxelInBounds
                if interpMethod == NEAREST
                    fnearest = floor(queryf + 0.5);
                    snearest = floor(querys + 0.5);
                    tnearest = floor(queryt + 0.5);

                    outVal = inputImageDouble(fnearest,snearest,tnearest);

                    if isfloat(inputImage)
                        outputImage(i,j,k) = eml_cast(outVal,class(inputImage));
                    else
                        outputImage(i,j,k) =  eml_cast(outVal,class(inputImage),'floor');
                    end

                elseif interpMethod == LINEAR
                    f0 = floor(queryf);
                    s0 = floor(querys);
                    t0 = floor(queryt);

                    f1 = ceil(queryf);
                    s1 = ceil(querys);
                    t1 = ceil(queryt);

                    fd = queryf-f0;
                    sd = querys-s0;
                    td = queryt-t0;

                    oneMinussd = 1-sd;

                    c00 = inputImageDouble(f0,s0,t0)*oneMinussd  + inputImageDouble(f0,s1,t0)*sd;
                    c10 = inputImageDouble(f1,s0,t0)*oneMinussd  + inputImageDouble(f1,s1,t0)*sd;
                    c01 = inputImageDouble(f0,s0,t1)*oneMinussd  + inputImageDouble(f0,s1,t1)*sd;
                    c11 = inputImageDouble(f1,s0,t1)*oneMinussd  + inputImageDouble(f1,s1,t1)*sd;

                    oneMinusfd = (1-fd);
                    c0 = c00*oneMinusfd+c10*fd;
                    c1 = c01*oneMinusfd+c11*fd;

                    outVal = c0*(1-td)+c1*td;

                    if isfloat(inputImage)
                        outputImage(i,j,k) =  eml_cast(outVal,class(inputImage));
                    else
                        if outVal < 0
                            outputImage(i,j,k) =  eml_cast(outVal-0.5 ,class(inputImage),'floor');                            
                        else
                            outputImage(i,j,k) =  eml_cast(outVal+0.5 ,class(inputImage),'floor');                            
                        end
                    end
                else
                    f = floor(queryf);
                    s = floor(querys);
                    t = floor(queryt);

                    df = queryf - f;
                    ds = querys - s;
                    dt = queryt - t;

                    u = coder.nullcopy(zeros(1,4,'like',inputImageDouble));
                    v = coder.nullcopy(zeros(1,4,'like',inputImageDouble));
                    w = coder.nullcopy(zeros(1,4,'like',inputImageDouble));
                    q = coder.nullcopy(zeros(1,4,'like',inputImageDouble));
                    r = coder.nullcopy(zeros(1,4,'like',inputImageDouble));

                    u = computeCubicWeights(df,u);
                    v = computeCubicWeights(ds,v);
                    w = computeCubicWeights(dt,w);

                    outVal = 0;

                    for kk=1:4
                        q(kk)=0;
                        for jj=1:4
                            r(jj)=0;
                            for ii=1:4
                                r(jj) = r(jj)+u(ii)*inputImageDouble(f+ii-2,s+jj-2,t+kk-2);
                            end
                            q(kk)=q(kk)+v(jj)*r(jj);
                        end
                        outVal = outVal+w(kk)*q(kk);
                    end

                   %Cubic interpolation can overshoot the values of its neighbors and exceed the range of the IMTYPE.
                   if isfloat(inputImage)
                       low = realmin(class(inputImage));
                       high = realmax(class(inputImage));
                   else
                       low = intmin(class(inputImage));
                       high = intmax(class(inputImage));
                   end

                   if outVal < low
                       outVal = cast(low,'like',inputImageDouble);
                   elseif outVal > high
                       outVal = cast(high,'like',inputImageDouble);
                   end

                    if isfloat(inputImage)
                        outputImage(i,j,k) =  eml_cast(outVal,class(inputImage));
                        outputImage(i,j,k) =  cast(outVal,class(inputImage));
                    else
                        if outVal < 0
                            outputImage(i,j,k) =  eml_cast(outVal-0.5 ,class(inputImage),'floor');                            
                        else
                            outputImage(i,j,k) =  eml_cast(outVal+0.5 ,class(inputImage),'floor');                            
                        end
                    end

                end
            else
                outputImage(i,j,k) = fillValues;
            end
        end
    end
end
end

%--------------------------------------------------------------------------
function weights = computeCubicWeights(dw,weights)
coder.inline('always');
coder.internal.prefer_const(dw);
sqr = dw*dw;
cube = sqr*dw;
weights(1) = -0.5*cube+sqr-0.5*dw;
weights(2) = 1.5*cube-2.5*sqr+1;
weights(3) = -1.5*cube +2*sqr+0.5*dw;
weights(4) = 0.5*cube-0.5*sqr;

end

%--------------------------------------------------------------------------
function voxelInBounds = isVoxelInBounds(fLoc,sLoc,tLoc,numImageRows,numImageCols,numImagePlanes,interpMethod)
coder.inline('always');

if  interpMethod == CUBIC
    voxelInBounds = (fLoc >= 2) && (fLoc <= numImageRows-1) && ...
        (sLoc >= 2) && (sLoc <= numImageCols-1) && ...
        (tLoc >= 2) && (tLoc <= numImagePlanes-1);
else
    voxelInBounds = (fLoc >= 1) && (fLoc <= numImageRows) && ...
        (sLoc >= 1) && (sLoc <= numImageCols) && ...
        (tLoc >= 1) && (tLoc <= numImagePlanes);
end
end


%--------------------------------------------------------------------------
function interpType = stringToInterpType(interpString)
% Convert interpType string to its corresponding enumeration
% Use strncmpi to allow case-insensitive, partial matches
if strncmpi(interpString,'linear',numel(interpString))
    interpType = LINEAR;
elseif strncmpi(interpString,'nearest',numel(interpString))
    interpType = NEAREST;
else % if strncmpi(interpString,'cubic',numel(interpString))
    interpType = CUBIC;
end
end

%--------------------------------------------------------------------------
function interpFlag = LINEAR()
coder.inline('always');
interpFlag = int8(1);
end

%--------------------------------------------------------------------------
function interpFlag = NEAREST()
coder.inline('always');
interpFlag = int8(2);
end

%--------------------------------------------------------------------------
function interpFlag = CUBIC()
coder.inline('always');
interpFlag = int8(3);
end