function f = corelucy(Y,H,damparTwo,wI,readOut,subSmpl,idx,vecMod,num)%#codegen
%CORELUCY Accelerated Damped Lucy-Richarson Operator

% Copyright 2022-2024 The MathWorks, Inc.

reblurred = real(ifftn(H.*fftn(Y)));
vec = zeros(1,coder.internal.indexInt(numel(vecMod)));
for i = 1:coder.internal.indexInt(numel(vecMod))
    vec(i) = vecMod(i);
end
yLen = coder.internal.indexInt(numel(size(Y)));
numLen = coder.internal.indexInt(numel(num));
if subSmpl ~= 1
    if yLen == 3
        if numLen == 1
            reblurredOne = reshape(reblurred,vec(1:4));
            if num(1) == 1
                vec(1) = [];
                reblurredTwo = reshape(mean(reblurredOne,1),vec(1:3));
            elseif num(1) == 2
                vec(2) = [];
                reblurredTwo = reshape(mean(reblurredOne,2),vec(1:3));
            else
                vec(3) = [];
                reblurredTwo = reshape(mean(reblurredOne,3),vec(1:3));
            end

            reblurredFinal = reblurredTwo;
        elseif numLen == 2
            reblurredOne = reshape(reblurred,vec(1:5));
            if num(1) == 3 && num(2) == 1
                vec(3) = [];
                reblurredTwo = reshape(mean(reblurredOne,3),vec(1:4));
                vec(1) = [];
                reblurredThree = reshape(mean(reblurredTwo,1),vec(1:3));
            elseif num(1) == 4 && num(2) == 2
                vec(4) = [];
                reblurredTwo = reshape(mean(reblurredOne,4),vec(1:4));
                vec(2) = [];
                reblurredThree = reshape(mean(reblurredTwo,2),vec(1:3));
            else
                vec(4) = [];
                reblurredTwo = reshape(mean(reblurredOne,4),vec(1:4));
                vec(1) = [];
                reblurredThree = reshape(mean(reblurredTwo,1),vec(1:3));
            end
            reblurredFinal = reblurredThree;
        else
            reblurredOne = reshape(reblurred,vec(1:6));
            vec(5) = [];
            reblurredTwo = reshape(mean(reblurredOne,5),vec(1:5));
            vec(3) = [];
            reblurredThree = reshape(mean(reblurredTwo,3),vec(1:4));
            vec(1) = [];
            reblurredFour = reshape(mean(reblurredThree,1),vec(1:3));
            reblurredFinal = reblurredFour;
        end
    else
        if numLen == 1
            reblurredOne = reshape(reblurred,vec(1:3));
            if num == 1
                vec(1) = [];
                reblurredTwo = reshape(mean(reblurredOne,1),vec(1:2));
            else
                vec(2) = [];
                reblurredTwo = reshape(mean(reblurredOne,2),vec(1:2));
            end
            reblurredFinal = reblurredTwo;
        else %numel(num) == 2
            reblurredOne = reshape(reblurred,vec(1:4));
            vec(3) = [];
            reblurredTwo = reshape(mean(reblurredOne,3),vec(1:3));
            vec(1) = [];
            reblurredThree = reshape(mean(reblurredTwo,1),vec(1:2));
            reblurredFinal = reblurredThree;
        end
    end
else
    reblurredFinal = reblurred;
end

% 2. An Estimate for the next step
reblurredFinal = reblurredFinal + readOut;

% Loop Scheduler
schedule = coder.loop.Control;
if size(reblurredFinal) == 3
    [rows,cols,planes] = size(reblurredFinal);
    if coder.isColumnMajor()
        schedule = schedule.parallelize('j');
    else
        schedule = schedule.interchange('i','k').parallelize('i');
    end
    % Apply Loop Scheduler
    schedule.apply
    for k = 1:coder.internal.indexInt(planes)
        for j = 1:coder.internal.indexInt(cols)
            for i = 1:coder.internal.indexInt(rows)
                if reblurredFinal(i,j,k) == 0
                    reblurredFinal(i,j,k) = eps('double');
                end
            end
        end
    end

else
    [rows,cols] = size(reblurredFinal);
    if coder.isColumnMajor()
        schedule = schedule.parallelize('j');
    else
        schedule = schedule.interchange('i','j').parallelize('i');
    end
    % Apply Loop Scheduler
    schedule.apply
    for j = 1:coder.internal.indexInt(cols)
        for i = 1:coder.internal.indexInt(rows)
            if reblurredFinal(i,j) == 0
                reblurredFinal(i,j) = eps('double');
            end
        end
    end
end

anEstim = wI./reblurredFinal + eps;

% 3. Damping if needed
if damparTwo == 0
    % No Damping
    imRatio = anEstim(idx{:});
else
    % Damping of the image relative to damparTwo = (N*sigma)^2
    gm = 10;
    aEs = log(complex(anEstim));
    g = (wI.*aEs + reblurredFinal - wI)./damparTwo;
    g = min(g,1);
    G = (g.^(gm-1)).*(gm - (gm-1)*g);
    imRatio = 1 + G(idx{:}).*(anEstim(idx{:}) - 1);
end
f = fftn(imRatio);