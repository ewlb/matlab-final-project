function [csf, fregdeg, fac] = csf1(freq, vd, dx)
%[csf, fregdeg, ffac] = csf1(freq, vd, dx)   CSF for CPIQ texture acutance
% CSF is the (humam visual) Contrast Sensitivity Function.
% This is the luminance CSF, CSFa, as described in,
% D.Baxter, F.Cao, H.Eliasson, J.Phillips, Development of the I3A CPIQ
% spatial metrics, Image Quality and System Performance IX, Proc. SPIE
% vol. 8293, 2012.
%
% freq = vector of spatial frequencies at the display
% vd   = viewing distance in cm
% dx   = sampling interval for display
% csf  = CSF vector
% freqdeg = frequency vector for the computed CSF.
% fac = factor for conversion between display cy/pixels and cy/degree
%
%Example: to compute the CSF for the default viewing conditions
% vd = 60 cm, dx = 0.01 inch (for 100 ppi display)
%
% f = 0:.1:4;
% vd = 30;
% dx = 2.54/100;  % 100 ppi display
% [csf, fregdeg] = csf1(f, vd, dx);
% plot(f, csf)
% xlabel('Frequency, cy/mm')
% ylabel('CSF')
% title(['Viewing dist.= ',num2str(vd),', Display res.= ',num2str(dx,3)])
%
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015

if nargin<3
   dx = 2.54/100;  % 100 ppi display
end
if nargin<2
   vd = 60; %cm     % viewing distance
end
fac=pi*vd/(180*dx);

a=1;
b=0.2;
c=0.8;
K=1;
fregdeg = fac*freq;
csf = (a*(fregdeg.^c).*exp(-b*fregdeg))/K;
mmax = max(csf);
csf=csf/mmax;
