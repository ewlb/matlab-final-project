function [status, amp, f] = radialNPS(s, df)
%[status, amp, f] = radialNPS(s) radial integration of 2D noise power spectrum
% s = input (n x n) noise power spectrum array
% df = spatial frequency interval for s (default = 1)
% status = 0 OK
% amp = radial NPS vector (1 x n)
% f = frequency vector
%
% Peter D. Burns, pdburns@ieee.org 5 Nov. 2015

status = 0;
if nargin < 2
    df = 1;
end

[rows, cols] = size(s);
if rows ~= cols
    assert(false, ' radialnps ERROR: 2D Spectrum array must be square')
    status = 1;
end

nbins = rows;
amp = zeros(1, nbins);
fcount = zeros(1, floor(rows/sqrt(1)));
[x,y] = meshgrid(1:cols,1:rows);

freq = sqrt(x.^2 + y.^2);
freq = round(freq/max(max(freq))*(nbins)) - 1;
    
for r = 1:rows
	for c = 1:cols
	    ind = freq(r,c)+1;
	    amp(ind) = amp(ind)+s(r,c);
	    fcount(ind) = fcount(ind)+1;
    end
end
% If you plan on log-log or semi-log plots, add eps to amp and f just in case 
amp = amp./fcount;
f = df*(0:nbins-1)/nbins*sqrt(.5);

% figure
% plot(f,amp), 
% axis([0, max(f), 0, 1.05*max(amp)]),
% xlabel('frequency'), ylabel('NPS');
