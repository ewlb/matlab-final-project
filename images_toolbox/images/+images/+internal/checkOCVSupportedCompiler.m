function [isCompilerOK, compilerName, compilerOCVbuiltWith] = checkOCVSupportedCompiler(varargin)
% checkOCVSupportedCompiler(thisArch) and checkOCVSupportedCompiler(context) 
% determines if functions that depend
% on openCV can generate code based on the compilers that openCV is
% internally built on. It errors for desktop targets when unsupported
% compilers (like minGW) is used, and for mexOpenCV (openCV support
% package) re-uses this internal function for the same purpose.

% Copyright 2017-2022 The MathWorks, Inc.
if isa(varargin{1}, 'char')
    thisArch = varargin{1};
    compilerForMex = mex.getCompilerConfigurations('C','selected');
else
    context = varargin{1};
    thisArch = context.ToolchainInfo.Platform;
    compilerForMex.Name = context.ToolchainInfo.Name;
end
compilerName = compilerForMex.Name;
isCompilerOK = true;

if contains(compilerName,'MinGW',IgnoreCase=true)
    isCompilerOK = false;
end
% this list of compilers that are supported is current as of R2022b.
if strcmp(thisArch, 'glnxa64')
    compilerOCVbuiltWith = 'gcc-6.3';
elseif any(strcmp(thisArch, {'maci64','maca64'}))
    compilerOCVbuiltWith = 'Xcode 9.0.0'; 
elseif strcmp(thisArch, 'win64')
%     % Supported compilers on Windows include Visual Studio 2015 and above. 
%     % This is based on the article from Microsoft on Binary compatibility. 
%     % https://docs.microsoft.com/en-us/cpp/porting/binary-compat-2015-2017?view=vs-2019
    compilerOCVbuiltWith = 'Microsoft Visual C++ 2019';
end

end
