classdef Imterp2DBuildable < coder.ExternalDependency %#codegen
    %

    % Copyright 2018-2023 The MathWorks, Inc.
    
    methods (Static)
        
        function name = getDescriptiveName(~)
            name = 'Imterp2DBuildable';
        end
        
        function b = isSupportedContext(context)
            b = context.isMatlabHostTarget();
        end
        
        function updateBuildInfo(buildInfo,context)

            % File extensions
            [linkLibPath, linkLibExt, execLibExt] = ...
                context.getStdLibInfo();
            group = 'BlockModules';
            
            % Header paths
            buildInfo.addIncludePaths(fullfile(matlabroot,'extern','include'));
            
            % Platform specific link and non-build files
            arch      = computer('arch');
            binArch   = fullfile(matlabroot,'bin',arch,filesep);
            sysOSArch = fullfile(matlabroot,'sys','os',arch,filesep);

            % include libstdc++.so.6 on linux
            libstdcpp = [];

            switch arch
                case {'win32','win64'}                    
                    libDir        = images.internal.getImportLibDirName(context);
                    linkLibPath   = fullfile(matlabroot,'extern','lib',arch,libDir);
                    linkFiles     = {'libmwimterp2d'}; %#ok<*EMCA>
                    linkFiles     = strcat(linkFiles, linkLibExt);
                    
                    nonBuildFiles = {'libmwimterp2d', 'tbb12'};
                    nonBuildFiles = strcat(nonBuildFiles, execLibExt);
                    nonBuildFiles = strcat(binArch, nonBuildFiles);   
                    
                   
                case 'glnxa64'
                    libstdcpp     = strcat(sysOSArch,{'libstdc++.so.6'});

                    linkFiles     = {'mwimterp2d'};

                    nonBuildFiles = {'libmwimterp2d'};
                    nonBuildFiles = strcat(nonBuildFiles, execLibExt);
                                       
                    nonBuildFiles{end+1} = 'libtbb.so.12';
                    nonBuildFiles{end+1} = 'libtbbmalloc.so.2';                    
                    
                    nonBuildFiles = strcat(binArch, nonBuildFiles);
                                        
                case {'maci64','maca64'}     
                    linkFiles     = {'mwimterp2d'};

                    nonBuildFiles = {'libmwimterp2d', 'libtbb', 'libtbbmalloc'};
                    nonBuildFiles = strcat(nonBuildFiles, execLibExt);
                    nonBuildFiles = strcat(binArch, nonBuildFiles);
                                 
                otherwise
                    % unsupported
                    assert(false,[arch ' operating system not supported']);
            end
            
            if coder.internal.hostSupportsGccLikeSysLibs()
                buildInfo.addSysLibs(linkFiles, linkLibPath, group);
            else
                linkPriority    = images.internal.coder.buildable.getLinkPriority('tbb');
                linkPrecompiled = true;
                linkLinkonly    = true;
                buildInfo.addLinkObjects(linkFiles,linkLibPath,linkPriority,...
                                         linkPrecompiled,linkLinkonly,group);
            end

            % Non-build files
            nonBuildFiles = [nonBuildFiles libstdcpp];
            buildInfo.addNonBuildFiles(nonBuildFiles,'',group);
                                 
        end
        
                
        function outputImage = imterp2d(fcnName, inputImage, Y, X, methodEnum, fillValues, outputImage) 
            coder.inline('always');
            coder.cinclude('libmwimterp2d.h');
            
            % C code expects 1x3 size
            inputImageSize_ = coder.internal.flipIf(coder.isRowMajor,size(inputImage));
            if numel(inputImageSize_)==2
                inputImageSize = [inputImageSize_, 1];
            else
                inputImageSize = [inputImageSize_(1:2), prod(inputImageSize_(3:end))];
            end
            
            outputImageSize = coder.internal.flipIf(coder.isRowMajor,size(outputImage));
            
            if coder.isRowMajor
                X_T = X;
                Y_T = Y;
            else                    
                X_T = Y;
                Y_T = X;
            end
            
            doScalarExtrap = numel(fillValues)==1;
            
            coder.ceval('-layout:any',fcnName,...
                        coder.rref(inputImage),...
                        inputImageSize, ...
                        coder.rref(X_T), ...
                        coder.rref(Y_T), ...
                        outputImageSize, ...
                        methodEnum, ...
                        doScalarExtrap, ...
                        coder.rref(fillValues), ...
                        coder.ref(outputImage));
        end
    end
end
