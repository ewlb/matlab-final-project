classdef Icons < handle
    %

    % Icons - Use this class as a constant property to store all icons
    % needed for Entry badges. This will only create a single copy of all
    % icons for all entries to share.

    % Copyright 2021 The MathWorks, Inc.

    properties

        Placeholder
        DoneIcon
        DoneIconAlpha
        ErrorIcon
        ErrorIconAlpha
        StaleIcon
        StaleIconAlpha
        WaitingIcon
        WaitingIconAlpha
        FullCheckerboardIcon
        FullCheckerboardIconAlpha
        PartialCheckerboardIcon
        PartialCheckerboardIconAlpha
        SelectedIcon
        SelectedIconAlpha
        WarningIcon
        WarningIconAlpha

        LabelingRequiredIcon
        LabelingRequiredIconAlpha
        LabelingInProgressIcon
        LabelingInProgressIconAlpha
        ReviewRequiredUnsentIcon
        ReviewRequiredUnsentIconAlpha
        ReviewRequiredIcon
        ReviewRequiredIconAlpha
        ReviewInProgressIcon
        ReviewInProgressIconAlpha
        ReadyForExportUnsentIcon
        ReadyForExportUnsentIconAlpha
        ReadyToExportIcon
        ReadyToExportIconAlpha

        InUnpublishedLTIcon    
        InUnpublishedLTIconAlpha
        LockedByLabelerIcon    
        LockedByLabelerIconAlpha
        LabelDoneNeedRTIcon    
        LabelDoneNeedRTIconAlpha
        InUnpublishedRTIcon    
        InUnpublishedRTIconAlpha  
        LockedByReviewerIcon   
        LockedByReviewerIconAlpha   
        LabelReviewDoneIcon   
        LabelReviewDoneIconAlpha  
        DoneUnsentIcon         
        DoneUnsentIconAlpha
        DoneSentIcon           
        DoneSentIconAlpha
        RejectedUnsentIcon     
        RejectedUnsentIconAlpha         
    end

    methods

        function self = Icons()

            self.Placeholder = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Placeholder_100.png'));
            [self.DoneIcon,~,self.DoneIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Completed_16.png'));
            [self.ErrorIcon,~,self.ErrorIconAlpha]         = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Error_16.png'));
            [self.WaitingIcon,~,self.WaitingIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Waiting_16.png'));
            [self.FullCheckerboardIcon,~,self.FullCheckerboardIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','FullCheckerboard_16.png'));
            [self.PartialCheckerboardIcon,~,self.PartialCheckerboardIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','PartialCheckerboard_16.png'));
            [self.StaleIcon,~,self.StaleIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Stale_16.png'));
            [self.SelectedIcon,~,self.SelectedIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Selected_16.png'));
            [self.WarningIcon,~,self.WarningIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Warning_16.png'));
            
            [self.LabelingRequiredIcon,~,self.LabelingRequiredIconAlpha]         = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','labelRequired_16.png'));
            [self.LabelingInProgressIcon,~,self.LabelingInProgressIconAlpha]     = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','labelInProgress_16.png'));
            [self.ReviewRequiredUnsentIcon,~,self.ReviewRequiredUnsentIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Completed_16.png'));
            [self.ReviewRequiredIcon,~,self.ReviewRequiredIconAlpha]             = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','reviewRequired_16.png'));
            [self.ReviewInProgressIcon,~,self.ReviewInProgressIconAlpha]         = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','reviewInProgress_16.png'));
            [self.ReadyForExportUnsentIcon,~,self.ReadyForExportUnsentIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','Completed_16.png'));
            [self.ReadyToExportIcon,~,self.ReadyToExportIconAlpha]               = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','accept_16.png'));

            [self.InUnpublishedLTIcon,~,self.InUnpublishedLTIconAlpha]   = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','InUnpublishedLT_16.png'));
            [self.LockedByLabelerIcon,~,self.LockedByLabelerIconAlpha]   = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','LockedByLabeler_16.png'));
            [self.LabelDoneNeedRTIcon,~,self.LabelDoneNeedRTIconAlpha]   = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','LabelDoneNeedRT_16.png'));
            [self.InUnpublishedRTIcon,~,self.InUnpublishedRTIconAlpha]   = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','InUnpublishedRT_16.png'));
            [self.LockedByReviewerIcon,~,self.LockedByReviewerIconAlpha] = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','LockedByReviewer_16.png'));
            [self.LabelReviewDoneIcon,~,self.LabelReviewDoneIconAlpha]   = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','LabelReviewDone_16.png'));
            [self.DoneUnsentIcon,~,self.DoneUnsentIconAlpha]             = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','DoneUnsent_16.png'));
            [self.DoneSentIcon,~,self.DoneSentIconAlpha]                 = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','DoneSent_16.png'));
            [self.RejectedUnsentIcon,~,self.RejectedUnsentIconAlpha]     = imread(fullfile(toolboxdir('images'),'imuitools','+images','+internal','+app','+browser','+icons','RejectedUnsent_16.png'));

        end

    end


end