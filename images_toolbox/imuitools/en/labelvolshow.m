%LABELVOLSHOW Display labeled volume
%   LABELVOLSHOW(L) displays the labeled volume L in a figure, where L is a
%   3D labeled volume.
%
%   LABELVOLSHOW(L, V) displays the labeled volume L and a volume V in a
%   figure, where L is a 3D labeled volume and V is a 3D volume.Volumes L
%   and V should be of the same size.
%
%   LABELVOLSHOW(____, CONFIG) displays volume(s) in a figure, where CONFIG
%   is a struct exported from the Volume Viewer App. Visualization of the
%   volume(s) is controlled by the CONFIG struct containing values for
%   LABELVOLSHOW object properties.
%
%   LABELVOLSHOW(____, Name, Value) displays volume(s), using Name/Value
%   pairs to control visualization of the volume(s). Name/Value pairs get
%   priority when provided along with the CONFIG struct.
%
%   h = LABELVOLSHOW(____) returns a labelvolshow object with properties
%   that can be used to control visualization of the volume(s).
%
%   Parameters include:
%
%   'Parent'              labelvolshow parent, specified as a handle to a
%                         uipanel or figure. When no parent is provided,
%                         the labelvolshow object is parented to gcf.
%
%   'CameraPosition'      Location of camera, or the viewpoint, specified
%                         as a three-element vector of the form [x y z].
%                         Changing the CameraPosition property changes the
%                         point from which you view the volume. The camera
%                         is oriented along the view axis, which is a
%                         straight line that connects the camera position
%                         and the camera target. Default value is 
%                         [4 4 2.5]. Interactively rotating the volume will
%                         modify this property.
%
%   'CameraUpVector'      Vector defining upwards direction, specified as a
%                         three-element direction vector of the form
%                         [x y z]. Default value is [0 0 1]. Interactively
%                         rotating the volume will modify this property.
%
%   'CameraTarget'        Point used as camera target, specified as a
%                         three-element vector of the form [x y z]. The
%                         camera is oriented along the view axis, which is
%                         a straight line that connects the camera position
%                         and the camera target. The default value is
%                         [0 0 0].
%
%   'CameraViewAngle'     Field of view, specified as a scalar angle 
%                         greater than or equal to 0 and less than 180. The
%                         greater the angle, the larger the field of view
%                         and the smaller objects appear in the scene.
%                         The default value is 15.
%
%   'BackgroundColor'     Color of the background, specified as a MATLAB
%                         ColorSpec. The intensities must be in the range
%                         [0,1]. The default color is [0.3 0.75 0.93].
%
%   'ShowIntensityVolume' Logical scalar value that defines if volumes and 
%                         labels are embedded together.
%                         Default: true if volume and labeled volume both
%                         are present, false only if labeled volume is
%                         present.
%
%   'LabelColor'          Color of labels specified as NumLabels x 3 numeric
%                         array with values in the range [0 1].
%                         Default is a random colormap.
%
%   'LabelOpacity'        Opacity of labels specified as NumLabels x 1 
%                         numeric array with values in the range [0 1].
%                         LabelOpacity is not supported when embedding the
%                         volumes together.
%                         Default value is one for all the labels except
%                         Label 0 or background label if present.
%
%   'LabelVisibility'     Logical mask of size NumLabels x 1 defining
%                         visibility of the labels present. 
%                         Default value is true for all the labels except 
%                         Label 0 or background label if present.
%
%   'VolumeOpacity'       A numeric scalar in the range [0 1] defining the
%                         opacity of volume data when labeled and intensity
%                         volumes are embedded together. All the embedded
%                         volume intensities above the VolumeThreshold
%                         value have the opacity of VolumeOpacity.
%                         Default : 0.5
%
%   'VolumeThreshold'     A normalized numeric scalar in the range [0 1]
%                         defining the threshold of volume intensities. All
%                         the volume intensities below this threshold value
%                         have opacity 0.
%                         Default : 0.4
%
%   'ScaleFactors'        Scale factors used to rescale volume(s), specified
%                         as a [1x3] positive numeric array. The values in
%                         the array correspond to the scale factor applied
%                         in the x, y, and z direction. Default value is
%                         [1 1 1].
%
%   'InteractionsEnabled' Interactivity of the volume. When true (default),
%                         you can zoom using the mouse scroll wheel, and
%                         rotate by clicking and dragging on the volume.
%                         Rotation and zoom is performed about the value
%                         specified by CameraTarget. When false, you cannot
%                         interact with the volume.
%
%   Class Support
%   -------------
%   L is a scalar valued MxNxP image of class categorical, uint8, uint16,
%   uint32, int8, int16, int32, single, or double.
%
%   V is a scalar valued MxNxP image of class logical, uint8, uint16,
%   uint32, int8, int16, int32, single, or double.
%
%   labelvolshow Properties:
%
%     Parent               - Parent
%     CameraPosition       - Camera location
%     CameraUpVector       - Vector defining upwards direction
%     CameraTarget         - Camera target point
%     CameraViewAngle      - Field of view
%     BackgroundColor      - Background color
%     ShowIntensityVolume  - Show intensity volume along with labels
%     LabelsPresent        - List of labels present in the labeled volume L
%     LabelColor           - Color of labels
%     LabelOpacity         - Opacity of labels
%     LabelVisibility      - Visibility flag of the labels
%     VolumeOpacity        - Opacity of volume data
%     VolumeThreshold      - Threshold of visibility of volume intensities
%     ScaleFactors         - Volume scale factors
%     InteractionsEnabled  - Control interactivity
%
%   labelvolshow Methods:
%
%     setVolume            - set volume in labelvolshow object
%                            setVolume(hLabelvol,L) updates the labelvolshow
%                            object hLabelvol with a new labeled volume L.
%                            When setVolume is used, the current viewpoint
%                            and intensity volume properties will be
%                            preserved, but the label properties are set to
%                            their respective defaults.
%
%                            setVolume(hLabelvol,L,V) updates the
%                            labelvolshow object hLabelvol with a new
%                            labeled volume L and new intensity volume V.
%                            When setVolume is used, the current viewpoint
%                            and intensity volume properties will be
%                            preserved, but the label properties are set to
%                            their respective defaults.
%
%
%   Example 1
%   ---------
%   % Visualize labeled volume with intensity volume and separately
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','images','vol_001.mat'));
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','labels','label_001.mat'));
%   h = labelvolshow(label, vol);
%   
%   % Change threshold of intensity volume
%   h.VolumeThreshold = 0.35;
% 
%   % Change color of Label 2 to green
%   h.LabelColor(2,:) = [0 1 0];
% 
%   % Hide intensity volume
%   h.ShowIntensityVolume = false;
%   
%   % Change opacity of Label 2 to 0.03
%   h.LabelOpacity(2) = 0.03;
%
%   Example 2
%   ---------
%   % Create a GIF of a rotating volume
%   % Load and view the labeled volume with intensity volume
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','images','vol_001.mat'));
%   load(fullfile(toolboxdir('images'),'imdata','BrainMRILabeled','labels','label_001.mat'));
%   h = labelvolshow(label, vol);
%   
%   % Change threshold of intensity volume
%   h.VolumeThreshold = 0.35;
% 
%   % Specify the name of the GIF file
%   filename = 'animatedBrainTumor.gif';
% 
%   % Create an array of camera positions around the unit circle
%   vec = linspace(0,2*pi(),120)';
%   myPosition = [cos(vec) sin(vec) ones(size(vec))];
% 
%   % Loop through and create an image at each camera position
%   for idx = 1:120
%       % Update current view
%       h.CameraPosition = myPosition(idx,:);
% 
%       % Use getframe to capture image
%       I = getframe(gcf);
%       [indI,cm] = rgb2ind(I.cdata,256);
% 
%       % Write frame to the GIF File
%       if idx == 1
%           imwrite(indI, cm, filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.05);
%       else
%           imwrite(indI, cm, filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.05);
%       end
%   end
%
%
%   See also: volumeViewer, volshow, slice

% Copyright 2018-2020 The MathWorks, Inc.
