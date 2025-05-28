classdef GetnumcoresBuildable < coder.ExternalDependency %#codegen
    %GETNUMCORESBUILDABLE - encapsulate Getnumcores implementation library
    
    % Copyright 2013-2022 The MathWorks, Inc.
    
    
    methods (Static)
        
        function name = getDescriptiveName(~)
            name = 'GetnumcoresBuildable';
        end
        
        function b = isSupportedContext(context)
            b = context.isMatlabHostTarget();
        end
        
        function updateBuildInfo(buildInfo, context)
            % File extensions
            [~, linkLibExt, execLibExt] = ...
                context.getStdLibInfo();
            group = 'BlockModules';
            
            % Header paths
            buildInfo.addIncludePaths(fullfile(matlabroot,'extern','include'));
            
            % Platform specific link and non-build files
            arch      = computer('arch');
            binArch   = fullfile(matlabroot,'bin',arch,filesep);
            sysOSArch = fullfile(matlabroot,'sys','os',arch,filesep);
            
            switch arch
                case {'win32','win64'}
                    linkFiles     = {'libmwgetnumcores'}; %#ok<*EMCA>
                    linkFiles     = strcat(linkFiles, linkLibExt);
                    libDir        = images.internal.getImportLibDirName(context);
                    linkLibPath   = fullfile(matlabroot,'extern','lib',computer('arch'),libDir);
                    
                    boostSystem   = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'mwboost_system-*');
                    boostThread   = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'mwboost_thread-*');
                    boostDateTime = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'mwboost_date_time-*');
                    boostChrono   = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'mwboost_chrono-*');
                    
                    nonBuildFiles = {['libmwgetnumcores' execLibExt],...
                        boostSystem, boostThread, boostDateTime, boostChrono};
                    nonBuildFiles = strcat(binArch,nonBuildFiles);
                    
                case {'glnxa64','maci64','maca64'}
                    linkFiles     = {'mwgetnumcores'}; %#ok<*EMCA>
                    linkLibPath   = binArch;
                    
                    % Non-build files
                    if strcmp(arch,'glnxa64')
                        libstdcpp = strcat(sysOSArch,{'libstdc++.so.6'});
                        sysosPath = fullfile(matlabroot,'sys','os',arch,filesep);
                        nonBuildFilesStd = {strcat(sysosPath,'libstdc++.so.6')};
                        nonBuildFilesStd{end+1} = strcat(sysosPath,'libgcc_s.so.1');
                        
                        boostSystem   = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'libmwboost_system.so.*');
                        boostThread   = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'libmwboost_thread.so.*');
                        boostDateTime = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'libmwboost_date_time.so.*');
                        boostChrono   = images.internal.coder.buildable.GetnumcoresBuildable.getBoostLibName(binArch,'libmwboost_chrono.so.*');
                        
                        nonBuildFilesBoost = {boostSystem};
                        nonBuildFilesBoost{end+1} = boostThread;
                        nonBuildFilesBoost{end+1} = boostDateTime;
                        nonBuildFilesBoost{end+1} = boostChrono;
                        nonBuildFilesBoost = strcat(binArch,nonBuildFilesBoost);
                        nonBuildFilesNoExt = [nonBuildFilesBoost nonBuildFilesStd];
                    else
                        libstdcpp          = [];
                        nonBuildFilesNoExt = {'libmwboost_thread'};
                        nonBuildFilesNoExt{end+1} = 'libmwboost_system';
                        nonBuildFilesNoExt{end+1} = 'libmwboost_date_time';
                        nonBuildFilesNoExt{end+1} = 'libmwboost_chrono';
                        nonBuildFilesNoExt = strcat(binArch,nonBuildFilesNoExt, execLibExt);
                    end
                    
                    nonBuildFilesExt = {'libmwgetnumcores'};
                    nonBuildFilesExt = strcat(binArch,nonBuildFilesExt, execLibExt);
                    nonBuildFiles = [libstdcpp nonBuildFilesExt nonBuildFilesNoExt];
                    
                otherwise
                    % unsupported
                    assert(false,[arch ' operating system not supported']);
            end
            
            if coder.internal.hostSupportsGccLikeSysLibs()
                buildInfo.addSysLibs(linkFiles, linkLibPath, group);
            else
                linkPriority    = '';
                linkPrecompiled = true;
                linkLinkonly    = true;
                buildInfo.addLinkObjects(linkFiles,linkLibPath,linkPriority,...
                    linkPrecompiled,linkLinkonly,group);
            end
            
            % Non-build files
            buildInfo.addNonBuildFiles(nonBuildFiles,'',group);
        end
        
        function libName = getBoostLibName(pathBinArch, libName)
            dirInfo = dir(fullfile(pathBinArch, libName));
            libName = dirInfo(1).name;
        end
        
        function out = getnumcores(out)
            coder.inline('always');
            coder.cinclude('libmwgetnumcores.h');
            coder.ceval('-layout:any','getnumcores',...
                coder.ref(out));
        end
        
    end
end
