% 2-D normalized gradient correlation of I1 and I2.
%
% Optional output arguments shift_x and shift_y are vectors containing
% relative shift of I1 with respect to I2 corresponding to each column and
% row of NGC. The length of shift_x is the same as the number of columns of
% NGC. The zero-valued element of shift_x identifies the column of NGC
% where the first column of I1 and the first column of I2 coincide in the
% correlation computation. Similarly, the zero-valued element of shift_y
% identifies the row of NGC where the first row of I1 and the first row of
% I2 coincide in the correlation computation. The element of NGC where
% shift_x and shift_y are both zero can be regarded as the "center" of the
% correlation output. This value of NGC is computed by aligning the (1,1)
% elements of I1 and I2.
%
% Note that correlation is not commutative. This function computes the
% correlation where the I1 matrix is being shifted.
%
% Normalized gradient correlation is mostly based on Tzimiropoulos et al.,
% "Robust FFT-Based Scale-Invariant Image Registration with Image
% Gradients," IEEE Transactions on Pattern Analysis and Machine
% Intelligence, vol. 32, no. 10, October 2010, pp. 1899-1906.
%
% Variable names I1, I2, G1, and G2 are based on the equations appearing in
% that paper.
%
% Equation 20:
%
%   GC = F^{-1} { \hat{G_1} \hat{G_2^\ast} }
%
% where \hat{G_i} is the Fourier transform of the complex gradient image,
% G_i. 
% 
% Equation 28 of the paper, which defines the normalization, is incorrect,
% resulting in values that do not have the desired properties. Instead, a
% modified normalization scheme is used here that results in values in the
% range [0,1].

function [NGC,shift_x,shift_y] = normalizedGradientCorrelation(I1,I2)%#codegen
    
    G1 = images.internal.coder.complexGradientImage(I1);
    G2 = images.internal.coder.complexGradientImage(I2);
    
    lenG1 = numel(G1);
    lenG2 = numel(G2);
    G1_bars = sum(G1);
    G2_bars = sum(G2);
    G1_barf = sum(G1_bars);
    G2_barf = sum(G2_bars);
    G1_bar = G1_barf/lenG1;
    G2_bar = G2_barf/lenG2;
    
    % Compute the unnormalized gradient correlation of the mean-subtracted
    % complex gradient images. Reverse the order of arguments to match the
    % interface of fftCorrelation2D.
    
    G1bar = G1 - G1_bar;
    G2bar = G2 - G2_bar;
    [NGC_numerator,shift_x,shift_y] = images.internal.coder.fftCorrelation2D(...
        G2bar, G1bar);
    

    % Normalize the gradient correlation.
    
    lenG1 = coder.internal.indexInt(numel(G1bar));
    lenG2 = coder.internal.indexInt(numel(G2bar));
    NGC_powG1 = zeros(size(G1bar),'like',G1bar);
    NGC_powG2 = zeros(size(G2bar),'like',G2bar);
    parfor i = 1:lenG1
        NGC_powG1(i) = abs(G1bar(i))^2; 
    end
    
    sumOneG1 = sum(NGC_powG1);
    sumTwoG1 = sum(sumOneG1);
    
    parfor i = 1:lenG2
        NGC_powG2(i) = abs(G2bar(i))^2; 
    end
    sumOneG2 = sum(NGC_powG2);
    sumTwoG2 = sum(sumOneG2);
    prodG1G2 = sumTwoG1 * sumTwoG2;
    NGC_denominator = sqrt(prodG1G2);

    NGC = NGC_numerator ./ NGC_denominator;
    
    % Arbitrarily set terms resulting from divisions by 0 to 0 so they will
    % not be selected as the maximum value.
      
    parfor i = 1 : coder.internal.indexInt(numel(NGC))
        flag = ~isfinite(NGC(i));
        if(flag)
            NGC(i) = 0;
        end

    end
    
    % Return the real part of NGC.
    %
    % Explanation:
    % 
    % When I_1(x,y) and I_2(x,y) are defined over the entire plane, and
    % when they are related by a pure translation, I_1(x,y) =
    % I_2(x-x_0,y-y_0), then Tzimiroupolos 2010 claims that the correlation
    % of the complex-valued functions G_1 (x,y) and G_2 (x,y) is purely
    % real. A nonzero imaginary term is introduced when the input images
    % are defined over finite domains and have nonoverlapping portions. The
    % paper says that this imaginary part can be ignored in practice.
    %
    % In assessment experiments performed during development, this worked
    % well.
    
    NGC = real(NGC);
    
end

% Copyright 2024 The MathWorks, Inc.