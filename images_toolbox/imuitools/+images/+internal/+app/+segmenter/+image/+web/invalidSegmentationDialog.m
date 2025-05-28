function dlg = invalidSegmentationDialog(hfig)
%invalidSegmentationDialog - Launch warning dialog for invalid
%segmentation.

% Copyright 2014 - 2020 The MathWorks, Inc.

warnstring = getString(message('images:imageSegmenter:badSegmentationDlgString'));
dlgname    = getString(message('images:imageSegmenter:badSegmentationDlgName'));

dlg = uialert(hfig,warnstring,dlgname);
end
