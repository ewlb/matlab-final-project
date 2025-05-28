function TF = blowAwaySegmentationDialog(fig)
%blowAwaySegmentationDialog - Launch warning dialog for threshold being
%a blow-out operation.

% Copyright 2015-2020 The MathWorks, Inc.

TF = false;

warnstring = getString(message('images:imageSegmenter:blowAwaySegmentationDlgString'));
dlgname    = getString(message('images:imageSegmenter:blowAwaySegmentationDlgName'));
yesbtn     = getString(message('images:commonUIString:yes'));
cancelbtn  = getString(message('images:commonUIString:cancel'));

dlg = uiconfirm(fig,warnstring,dlgname,...
           'Options',{yesbtn,cancelbtn},...
           'DefaultOption',2,'CancelOption',2);

switch dlg
    case yesbtn
        TF = true;
    case cancelbtn
        TF = false;
end
end
