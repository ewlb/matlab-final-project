function tf = isexr(fileName)

    fullFileName = images.internal.io.absolutePathForReading(fileName);

    fp = fopen(fullFileName, "rb");
    if fp == -1
        % Adding an assertion here because validation of existence and read
        % permissions was done in the previous helper call.
        assert(false, "File open failed");
    end

    fpOc = onCleanup( @() fclose(fp) );

    magicNum = fread(fp, 1, "uint32=>double");
    expMagicNum = 20000630;
    
    tf = magicNum == expMagicNum;
end

%   Copyright 2022 The MathWorks, Inc.
