% 2-D correlation of A and B, computed using FFTs.
%
% Optional output arguments shift_x and shift_y are vectors containing
% relative shift of B with respect to A corresponding to each column and
% row of C. The length of shift_x is the same as the number of columns of
% C. The zero-valued element of shift_x identifies the column of C where
% the first column of A and the first column of B coincide in the
% correlation computation. Similarly, the zero-valued element of shift_y
% identifies the row of C where the first row of A and the first row of B
% coincide in the correlation computation. The element of C where shift_x
% and shift_y are both zero can be regarded as the "center" of the
% correlation output. This value of C is computed by aligning the (1,1)
% elements of A and B.
%
% Here is a concrete example of how shift_x and shift_y are determined.
%
%         A = [ ...
%               8 1 6
%               3 5 7 ]
%
%         B = [ ...
%              16 2  3 13
%              5 11 10  8
%              9  7  6 12]
%
% Imagine laying matrix B over matrix A so that their upper-left corners
% are aligned. In other words, the 16 from B is on top of the 8 from A. If
% you slide B to the left by 3, the right-most column of B overlaps the
% left-most column of A. If you slide B to the right by 2, the left-most
% column of B overlaps the right-most column of A. That's how the shift_x
% range of -3:2 is determined.
%
% Similarly, if you slide B up by 2, the bottom-most row of B overlaps the
% top-most column of A. If you slide B down by 1, the top-most row of B
% overlaps the bottom-most row of A. That's how the shift_y range of -2:1
% is determined.
%
% Note that correlation is not commutative. This function computes the
% correlation where the B matrix is being shifted.
%
% The named argument Type can be "normal" or "phase". The "phase" type is
% used for phase correlation.

function [C,shift_x,shift_y] = fftCorrelation2D(A,B)
    arguments
        % A and B must also be 2-D, but there is currently no validator for
        % that. 
        A   {mustBeFloat, mustBeNonempty}
        B   {mustBeFloat, mustBeNonempty}
    end

    [Ma,Na] = size(A);
    [Mb,Nb] = size(B);

    shift_x = -(Nb-1):(Na-1);
    shift_y = -(Mb-1):(Ma-1);    

    Mc = Ma + Mb - 1;
    Nc = Na + Nb - 1;

    Mcp = images.registration.internal.fftPadSize(Mc);
    Ncp = images.registration.internal.fftPadSize(Nc);

    ABConj = fft2(A,Mcp,Ncp) .* conj(fft2(B,Mcp,Ncp));
    C = ifft2(ABConj);

    % Compensate for the circular shift resulting from the use of FFTs and
    % undo the extra padding from fftPadSize.
    % Conceptually, this is:
    %
    %   C = circshift(C,[Mb-1 Nb-1]);
    %   C = C(1:Mc,1:Nc);
    %
    % Optimized implementation for increased speed and reduced memory use:
    ii = (1:size(C,1))';
    ii = circshift(ii,Mb-1);
    jj = (1:size(C,2))';
    jj = circshift(jj,Nb-1);
    C = C(ii(1:Mc),jj(1:Nc));
end

% Copyright 2023-2024 The MathWorks, Inc.