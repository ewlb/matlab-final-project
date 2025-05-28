function [Rspec_sig, freq, Rspec, Ispec,v2, nnn] = texture_spec(dat2, dat3, dflag, mmax)
%[Rspec_sig, freq, Rspec, Ispec,v2, nn]=texture_spec(fname,dflag, mmax) deadleaves NPS
% Computes Dead Leaves noise-power spectrum from image file for deal leaves
% test chart WITH NOISE CORRECTION. The following operations are included,
% ROI selection, 2D NPS estimation, radial NPS integration.
%
% fname = path for image file name OR array of (nxn) image pixel data.
%         If a color image is chosen, a luminance color report will be
%         computed and used.
% dflag = 0 no 2D detrending of data array before NPS estimation
%       = 1 detrend
% mnax  = (optional)size of data array used (mmax, mmax) used for NPS
%         estimation, default = 256
% Rspec_sig = 1D (radial) signal spectrum, corrected for noise spectrum
% freq  = spatial frequencies (vector) for sampling of Rspec_sig
% Rspec =  1D (redial) signal spectrum, NOT corrected for noise spectrum
% Ispec =  2D uncorrected noise-power spectrum
% v2 = variance computed fron NPS, (used for debugging spectrum estimates)
% nn = size of the (nn x nn) image array used for the analysis
%Needs: imageread, getroi, detrend2, deadleavesNPS
%
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015, updated 27 Feb. 2024

if nargin<4
    mmax = 256;
end

if nargin<3
    dflag = 0;
end

dat2 = double(dat2);

[nlin, npix, nc] = size(dat2);
if mmax~=0
    % Simple optional data cropping
    nlin = min(nlin,mmax);
    npix = min(npix,mmax);
    dat2 = dat2(1:nlin,1:npix,:);
end
if nc ~=1
    temp = images.internal.deadleaves.rgb2lum(dat2);
    [nn, mm, nc] = size(dat2);
    temp2 = zeros(nn,mm,nc+1);
    temp2(:,:,1:3) = dat2;
    temp2(:,:,4) = temp;
    nc = 4;
    dat2 = temp2;
    clear temp temp2;       
end
[~, ~, nc] = size(dat2);
Rspec2 = zeros(200,3);
for jj = 1:nc
    if dflag==1
      % Simple 2D linear (a plane) subtraction 
      dat2(:,:,jj) = images.internal.deadleaves.detrend2(dat2(:,:,jj), 1, 1, 0);
      % disp('detrending signal')
    end
    [Rspec, freq, Ispec, v2, nnn] = images.internal.deadleaves.deadleavesNPS(dat2(:,:,jj), 1, 0);
    Rspec2(1:length(Rspec),jj)= Rspec;
end
clear Rspec
Rspec = Rspec2(1:length(freq),:); 
clear Rspec2

dat3 = double(dat3);

if nc ~=1
    temp = images.internal.deadleaves.rgb2lum(dat3);
    [nn, mm, nc] = size(dat3);
    temp2 = zeros(nn,mm,nc+1);
    temp2(:,:,1:3) = dat3;
    temp2(:,:,4) = temp;
    nc = 4;
    dat3 = temp2;
    clear temp temp2;       
end

Rspec2 = zeros(200,nc);
for jj = 1:nc
    if dflag==1
      dat3(:,:,jj) = images.internal.deadleaves.detrend2(dat3(:,:,jj), 1, 1, 0);
      % disp('detrending noise')
    end
    [Rspec1, freq1] = images.internal.deadleaves.deadleavesNPS(dat3(:,:,jj), 1, 0);
    Rspec2(1:length(Rspec1),jj)= Rspec1;
end
clear Rspec1
Rspec1 = Rspec2(1:length(freq1),:); 
clear Rspec2

Rspec_sig = zeros(200,nc);
for jj = 1:nc
    % Interpolate noise spectrum to same size as signal spectrum
    Rspec1int = interp1(freq1, Rspec1(:,jj), freq, 'spline');
    Rspec1int = images.internal.deadleaves.clip(Rspec1int,eps,inf)';
    % Subtract noise spectrum
    Rspec_sig(1:length(Rspec1int),jj) = Rspec(:,jj) - Rspec1int;
    % Avoid negative spectrum values
    Rspec_sig(:,jj) = images.internal.deadleaves.clip(Rspec_sig(:,jj),eps,inf);
end
Rspec_sig = Rspec_sig(1:length(Rspec1int),:);
freq = freq(:);
