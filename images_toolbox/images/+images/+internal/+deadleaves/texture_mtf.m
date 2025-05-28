function [MTF, Rspec_sig1, Rspec_sig2, freq2, acut] = ...
                texture_mtf( refDLRegion, refUniRegion, ...
                                    testDLRegion, testUniRegion, vdist, doPlot)
%[mtf_txt, acutance] = texture_MTF(tflag, vdist) 
% Image texture evaluation: Texture Modulation Transfer Function (MTF)
% and acutance computed from deadleaves test target images.
% Both input arguements are optional
% tflag  = 0 (default) Ideal input target deadleaves spectrum is computed
%        = 1 a high quality reference image of the deadleaves target is
%          selected
% vdist  = viewing distance in cm (default = 60) for acutance calculation
% mtf_txt = (n x 2) texture MTF. Col. 1 is spatial frequency in cy/pixel, 
%           col. 2 is textur MTF
% acutance = computed acutance measure
% The method is based on computing a noise-power spectrum for the 
% 'dead leaves' area of test images. This is done for an input (e.g. test
% target) image and an output image, e.g. after image processing. The 
% texture MTF is computed as the ratio square-root of the input and output
% spectra.
%
% This is an updated version of this code. The previous version required an
% image (scan) of the deadleaves target. The testure MTF can now also
% computed using a computed ideal deadleaves spectrum.
%
% The input specrum can be computed in two ways.
% 1. By computing the assumed ideal specrum (tflag = 0 default)
% 2. By directly computing the spectrum from a high-quality image of the
%    particular test target being used (tflag = 0 default). This image 
%    could be by scanning the physical test target. This method is
%    generally recommended.
% 
% The acutance is a summary measure, which provides a visually
% weighted summary measure of the image texture capture(or retained) by
% the system under test.
%
% This implementation includs the two-dimensional trend removal described
% in the reference below. It also performs the image noise subtraction
% described by McElvain, et al.(2010).
%
% For background and details on this method, please see,
% P.D.Burns, Refined Measurement of Digital Image Texture Loss, Proc.
% SPIE vol. 8653, Image Quality and System Performance X, 86530H (2013) 
%
%Needed:
% for tflag = 1 Two corresponding input and output image files for the
% system being tested. Also several supporting functions
% deadleavesNPS, radialNPS, texture_spec, rgb2lum, detrend2
%
% Peter D. Burns, pdburns@ieee.org 14 March 2024


if nargin<5 || isempty(vdist)
    vdist = 60;
end

if nargin<6
    doPlot = false;
end

% Compute the texture spec for the test image
[Rspec_sig2, freq2,~,~,~,nn] = images.internal.deadleaves.texture_spec( ...
                                            testDLRegion, testUniRegion, 1, 0 );
[nn2,nc] =size(Rspec_sig2);

% If reference image is not provided by the user, then use the default
% ideal reference.
if isempty(refDLRegion)
    [Rspec_sig1, freq1] = images.internal.deadleaves.deadleaves_ideal_spec(nn, freq2);
else
    [Rspec_sig1, freq1,~,~,~] = images.internal.deadleaves.texture_spec( ...
                                                refDLRegion, refUniRegion, 1, 0 );
end

[nn1,nc2] = size(Rspec_sig1);

if nc2<nc
   temp = [Rspec_sig1, Rspec_sig1, Rspec_sig1, Rspec_sig1];
   temp = reshape(temp, nn1,nc);
   Rspec_sig1 = temp;
end
if nn2~=nn1
    temp = zeros(numel(freq2), nc);
    for jj = 1:nc
      % temp = interp1(freq2, Rspec_sig2(:,jj), freq1, 'spline');
      temp(:, jj) = interp1(freq1, Rspec_sig1(:,jj), freq2, 'spline');
    end
    Rspec_sig1 = temp;
end

MTF = zeros(nn2,nc);
for jj = 1:nc
    % Scale input (target or ideal) spectrum
    % Low-frequency normalization (scaling) at a frequency = 0.04 cy/pixel
    ii = find(abs(freq2-0.04) == min(abs(freq2-0.04)));
    K = Rspec_sig2(ii,jj)/Rspec_sig1(ii,jj);
    Rspec_sig1 = K*Rspec_sig1;
    % Compute the texture MTF as square root of ratio of the spectra
    MTF(:,jj) = Rspec_sig2(:,jj)./Rspec_sig1(:,jj);
    MTF(1,jj)=1;
    MTF(:,jj) = sqrt(abs(MTF(:,jj)));
end

% Acutance Measurement
dx = 2.54/100;  % assumed 100 ppi display
csf = images.internal.deadleaves.csf1(freq2, vdist, dx);
csf = csf(:);
acut = sum(MTF(:,end).*csf)/sum(csf); 

if doPlot
    set(0, 'DefaultTextInterpreter', 'tex')
    pos = centerfig(10,4,0.8);
    figure('Position',pos);
    
    subplot(1,2,1)
    semilogy(freq2, Rspec_sig1(:,1),'LineWidth',1.5), hold on
    for jj = 1:nc
        semilogy(freq2, Rspec_sig2(:,jj),'--','LineWidth',1.5)
    end
    hold off
    mmax = 1.05*max(Rspec_sig1(:));
    mmin = mmax*1e-6;
    axis([0 .7 mmin mmax])
    xlabel('Frquency, cy/pixel')
    ylabel('Power Spectrum')
    if nc==1
        legend('Input (scaled)','Output')
    else
        legend('Input (scaled)','Out R','Out G','Out B','Out Lum')
    end
    
    subplot(1,2,2)
    for jj = 1:nc
    plot(freq2, MTF(:,jj),'LineWidth',1.5), hold on
    end
    xlabel('Frquency, cy/pixel')
    ylabel('MTF_{txt}')
    title(['Acutance: ',num2str(acut,3)],'HorizontalAlignment','right')
    axis([0 .7 0 1.4])
    if nc~=1
        legend('R','G','B','Lum')
    end
end
