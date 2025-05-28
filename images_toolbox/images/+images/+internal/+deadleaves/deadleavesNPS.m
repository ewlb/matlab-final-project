function [Rspec, f, Ispec, var2, nn] = deadleavesNPS(dat2, dx, pflag)
% [Rspec, freq] = deadleavesNPS(dat, dx, pflag) dead-leaves signal spectrum
% estimation
% dat = input 2D data array
% dx = sampling interval for data, default = 1 pixel
% pflag = 0 (default) no plotting of results
%      = 1 plot results
% Rspec = output radially integrated noise-power spectrum
% f     = spatial frequency vector in cy/pixel
% Ispec = two-dimensional noise-power spectrum, based on a single 2-D data
%         block
% dvar = variance extimate computed from noise-power spectrum. Useful for
%        understanding NPS scaling and debugging.
% Needs: radialNPS, spec2rms
%
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015, 14 March 2024

if nargin<3
    pflag = 0;
end
if nargin<2
    dx = 1;
end

[nlin,npix,nc] = size(dat2);
if nc==3
    dat2 = dat2(:,:,2);
end
nn = min(nlin,npix);
% if nn<256
%     %beep
%     error(['* Data array should be at least 256 x 256 pixels, ',num2str(nn)])
%     pause(0.5);
% end
dat2 = double(dat2(1:nn,1:nn));
dmean = mean(dat2(:));
dvar = var(dat2(:));

% FFT magnitude
Imod = abs(fft2(dat2));
% Suppression of zero-frequency value
Imod(1,1) = (Imod(1,2)+Imod(2,2)+Imod(2,1))/3;
% Crop to first frequency quadrant
nmax = round((nn+1)/2);
Imod = Imod(1:nmax,1:nmax);

% Compute Signal spectrum (Noise-Power Spectrum)
df = 1/(dx*nn);             % Frequency sampling of NPS
Ispec = df*df*Imod.^2;   

% Compute signal variance from integration of the NPS
rms2 = images.internal.deadleaves.spec2rms(Ispec, 1);
var2 = rms2^2;

% Compute radial averaged spectrum
[~, Rspec, f] = images.internal.deadleaves.radialNPS(Ispec, 1);

 % Plotting
if pflag ~=0
    figure;
    subplot(2,1,1)
    loglog(f,Rspec,'LineWidth',1.4), hold on
    hold off

    xlabel('Frequency, cy/pixel')
    ylabel('Power Spectrum')

    subplot(2,1,2)
    plot(f,Rspec,'LineWidth',1.4), hold on
    xlabel('Frequency, cy/pixel')
    ylabel('Power Spectrum')

end



