function addTitledBorderToPanel(panel,title)
%

% Copyright 2015-2020 The MathWorks, Inc.

emptyBorder = javaMethodEDT('createEmptyBorder','javax.swing.BorderFactory');
titledBorder = javaMethodEDT('createTitledBorder','javax.swing.BorderFactory',emptyBorder,title);
javaObjectEDT(titledBorder);
panel.Peer.setBorder(titledBorder);
end