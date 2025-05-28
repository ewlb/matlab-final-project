classdef Morphop_ipp_Buildable < coder.ExternalDependency %#codegen
    % Encapsulate morphop implementation library
    
    % Copyright 2013-2019 The MathWorks, Inc.
    
    %#ok<*EMCA>    
    
    methods (Static)
        
        function name = getDescriptiveName(~)
            name = 'Morphop_ipp_Buildable';
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

            libstdcpp = [];
            % include libstdc++.so.6 on linux
            if strcmp(arch,'glnxa64')
                libstdcpp = strcat(sysOSArch,{'libstdc++.so.6'});
            end

            switch arch
                case {'win32','win64'}
                    libDir        = images.internal.getImportLibDirName(context);
                    linkLibPath   = fullfile(matlabroot,'extern','lib',arch,libDir);
                    linkFiles     = {'libmwmorphop_ipp'}; %#ok<*EMCA>
                    linkFiles     = strcat(linkFiles, linkLibExt);
                    
                    nonBuildFiles = {'libmwmorphop_ipp','libmwipp'};
                    nonBuildFiles = strcat(nonBuildFiles, execLibExt);
                    nonBuildFiles = strcat(binArch, nonBuildFiles);
                    
                case {'glnxa64','maci64'}
                    linkFiles     = {'mwmorphop_ipp','mwipp'};
                    
                    nonBuildFiles = {'libmwmorphop_ipp','libmwipp'};
                    nonBuildFiles = strcat(nonBuildFiles, execLibExt);
                    nonBuildFiles = strcat(binArch, nonBuildFiles);
                                                            
                otherwise
                    % unsupported
                    assert(false,[arch ' operating system not supported']);
            end
            
            if coder.internal.hostSupportsGccLikeSysLibs()
                buildInfo.addSysLibs(linkFiles, linkLibPath, group);
            else
                linkPriority    = images.internal.coder.buildable.getLinkPriority('ipp');
                linkPrecompiled = true;
                linkLinkonly    = true;
                buildInfo.addLinkObjects(linkFiles,linkLibPath,linkPriority,...
                                         linkPrecompiled,linkLinkonly,group);
            end
            
            % Non-build files
            nonBuildFiles = [nonBuildFiles libstdcpp];
            buildInfo.addNonBuildFiles(nonBuildFiles,'',group);
            
        end
        
        function b = morphop_ipp(...
                fcnName, a, asize, nhood, nsize, b)
            coder.inline('always');
            coder.cinclude('libmwmorphop_ipp.h');
            
            coder.ceval(fcnName,...
                coder.rref(a), coder.rref(asize), ...
                coder.rref(nhood), coder.rref(nsize), ...
                coder.ref(b));
        end
    end
end
