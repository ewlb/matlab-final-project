function Z = depthToSpaceForward(X,blockSize,mode)

[inputHeight,inputWidth,inputChannel,batchSize] = size(X);
outputChannel = inputChannel/((blockSize(1)*blockSize(2)));

if floor(outputChannel)*(blockSize(1)*blockSize(2)) ~= inputChannel
     error(message('images:depthToSpace:InputChannelDivisble'));
end

outputHeight = inputHeight*blockSize(1);
outputWidth =  inputWidth*blockSize(2);

switch (mode)
    
    case "dcr"
        
        % Depth column row order
        Z = reshape(X,[inputHeight,inputWidth,outputChannel,blockSize(2),blockSize(1),batchSize]);
        Z = permute(Z,[5 1 4 2 3 6]);
        Z = reshape(Z,[outputHeight,outputWidth,outputChannel,batchSize]); 
                
    case "crd"
        
        % Column row depth order
        Z = reshape(X,[inputHeight,inputWidth,blockSize(2),blockSize(1),outputChannel,batchSize]);
        Z = permute(Z,[4 1 3 2 5 6]);
        Z = reshape(Z,[outputHeight,outputWidth,outputChannel,batchSize]); 

end

end