function detrended_phase_realization = get_phase_realization(norm_phase_sdf, D_mu, nfft, seed)
% get_phase_realization
%
% Syntax:
%   detrended_phase_realization = get_phase_realization(norm_phase_sdf, D_mu, nfft, seed)
%
% Description:
%   Generate a statistically-equivalent (refractive) phase realization by
%   imposing the desired phase SDF P(mu) on white noise, following the
%   discrete synthesis approach described in [Phase screen realizations and 
%   wave propagation, 3].
%
% Inputs:
%   norm_phase_sdf - Phase SDF samples P(mu) on a uniform mu grid.
%                    IMPORTANT: mu is Carrano's *angular* normalized wavenumber,
%                    i.e., it carries an explicit 2*pi when mapped from temporal frequency.
%   D_mu           - Mu grid spacing Δμ.
%   nfft           - DFT length (number of samples).
%   seed           - RNG seed for reproducibility.
%
% Outputs:
%   detrended_phase_realization - Real-valued phase realization after linear detrend.
%
% Notes:
%   - Discrete synthesis [Eq. (8), 3]:
%       φ_m = Σ_n sqrt( P(μ_n) * Δμ / (2π) ) * η_n * exp{-j 2π n m / N}
%     where η_n is complex white noise.
%
%   - The factor (Δμ / 2π) is not an arbitrary scaling: it comes from the
%     inverse-Fourier normalization used when μ is an *angular* variable
%     (radians).
%
%   - To obtain a real-valued phase realization, the DFT-domain coefficients must
%     be Hermitian (conjugate symmetric). This implementation enforces Hermitian
%     symmetry so the IFFT produces a real sequence (up to numerical noise),
%     instead of taking real(...) of a complex output.
%
%   - MATLAB's `ifft` includes a 1/N factor. The synthesis above is commonly
%     written without it, so we multiply the IFFT output by N.
%
% Example:
%   norm_phase_sdf = rand(1, 256);
%   D_mu = 0.1;
%   nfft = 256;
%   seed = 12345;
%   phase_realization = get_phase_realization(norm_phase_sdf, D_mu, nfft, seed);
%
% References:
% [1] Rino C, Breitsch B, Morton Y, Jiao Y, Xu D, Carrano C. A compact 
%     multi-frequency GNSS scintillation model. NAVIGATION. 2018; 65: 
%     563–569. https://doi.org/10.1002/navi.263
% [2] C. S. Carrano and C. L. Rino, “A theory of scintillation for 
%     two‐component power law irregularity spectra: Overview and 
%     numerical results,” Radio Science, vol. 51, no. 6, pp. 789–813, 
%     June 2016, https://doi.org/10.1002/2015RS005903.
% [3] Y. Jiao, C. Rino, and Y. T. Morton, “Ionospheric Scintillation 
%     Simulation on Equatorial GPS Signals for Dynamic Platforms”, 
%     J Inst Navig, vol. 65, no. 2, pp. 263–274, 
%     June 2018, https://doi.org/10.1002/navi.231.
%
% Author: Rodrigo de Lima Florindo
% ORCID: https://orcid.org/0000-0003-0412-5583
% Email: rdlfresearch@gmail.com

    rng(seed);

    % Compute the square-root weighting applied to white noise.
    %
    % Here, `norm_phase_sdf` is Carrano/Rino's phase SDF P(mu), expressed as a
    % function of the *angular* normalized wavenumber mu (radians).
    %
    % A statistically-equivalent phase realization can be synthesized by
    % imposing the desired spectrum on white noise. In discrete form [Eq. 8, 3],
    % each spectral bin contributes with amplitude:
    %   sqrt( P(n * mu) * Δμ / (2π) )
    root_norm_phase_sdf = sqrt(norm_phase_sdf * D_mu / (2*pi));

    % Generate Hermitian complex white noise in FFT bin order (unit variance),
    % so the IFFT result is real-valued (up to numerical noise).
    xi_fft = hermitian_complex_white_noise(nfft);

    % `root_norm_phase_sdf` is provided on a centered (`fftshift`) μ grid (-..0..+).
    % Convert it to FFT bin order before applying the IFFT.
    phase_spectrum_fft = ifftshift(root_norm_phase_sdf) .* xi_fft;

    % Inverse transform (IFFT) from μ-domain coefficients to the phase realization.
    % Multiply by N to match Carrano's un-normalized DFT synthesis convention.
    phase_realization = real(fftshift(ifft(phase_spectrum_fft))) * nfft;

    %Remove linear trend to force segment too segment continuity
    % NOTE (Rodrigo): I've let this part the same as it is done in the
    % CPSSM original code:
    % https://github.com/cu-sense-lab/gnss-scintillation-simulator_2-param/blob/master/Libraries/GenScintFieldRealization/GenScintFieldRealization.m
    linear_trend = linex( ...
        1:nfft, ...
        1, ...
        nfft, ...
        phase_realization(1), ...
        phase_realization(nfft));
    detrended_phase_realization = phase_realization - linear_trend;
end

function xi_fft = hermitian_complex_white_noise(nfft)
% Build Hermitian-symmetric complex white noise in FFT bin order.
%
% This ensures `ifft(...)` is real-valued (up to numerical noise).
% We use unit-variance complex Gaussian noise: E[|z|^2] = 1.

    xi_fft = complex(zeros(1, nfft));

    % Set DC bin as real.
    xi_fft(1) = randn(1, 1);

    if mod(nfft, 2) == 0
        % Even length: Nyquist bin exists and must be real.
        xi_fft(nfft/2 + 1) = randn(1, 1);
        % k_max is the Nyquist bin index.
        k_max = nfft/2;
        neg_start = k_max + 2; % skip Nyquist
    else
        k_max = (nfft + 1) / 2;
        neg_start = k_max + 1;
    end
    
    num_bins = k_max - 1;
    re = randn(1, num_bins);
    im = randn(1, num_bins);
    z = complex(re, im) / sqrt(2); % unit complex variance
    xi_fft(2:k_max) = z;

    % Conjugate symmetry for negative-frequency bins.
    xi_fft(nfft:-1:neg_start) = conj(z);
end
