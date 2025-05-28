%

% Copyright 2020 The MathWorks, Inc.

function dlg = export2wsdlg(loc, varName, labelMsg, var)
dlg = images.internal.app.utilities.ExportToWorkspaceDialog(loc,...
    'Export To Workspace', varName, labelMsg);
movegui(dlg.FigureHandle,'center');

wait(dlg);

if ~dlg.Canceled
    for idx = 1: numel(varName)
        if dlg.VariableSelected(idx)
            assignin('base',dlg.VariableName(idx),var{idx});
        end
    end
end
