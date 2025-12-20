function propagated_scint_field = get_propagated_field(mu, detrended_phase_realization)
% get_propagated_field
%
% Syntax:
%   propagated_scint_field = get_propagated_field(detrended_phase_realization, mu)
%
% Description:
%   This function computes the propagated scintillation field by applying a 
%   parabolic wave propagation factor in the frequency domain. First, an initial 
%   scintillation field is obtained by taking the exponential of the complex 
%   detrended phase realization. Then, the parabolic approximation factor 
%   (based on mu) is applied to this field in the frequency domain. 
%
% Inputs:
%   detrended_phase_realization - The phase realization after removing low-frequency 
%                                 trends or drifts
%   mu                          - Normalized spatial wavenumber axis used to 
%                                 construct the parabolic propagation factor
%
% Outputs:
%   propagated_scint_field - The scintillation field after applying the parabolic 
%                            wave propagation approximation
%
% Notes:
%   - This implementation references Equations (24) and (25) from [1].
%
% References:
% [1] Rino C, Breitsch B, Morton Y, Jiao Y, Xu D, Carrano C.
%     "A compact multi-frequency GNSS scintillation model." NAVIGATION.
%      2018; 65: 563–569. https://doi.org/10.1002/navi.263
%
% [2] Y. Jiao, C. Rino, and Y. T. Morton, “Ionospheric Scintillation 
%     Simulation on Equatorial GPS Signals for Dynamic Platforms”, 
%     J Inst Navig, vol. 65, no. 2, pp. 263–274, 
%     June 2018, https://doi.org/10.1002/navi.231.
% Author:
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com

    % Exponential of the detrended phase realization to obtain the initial field.
    initial_scint_field = exp(1j * detrended_phase_realization);

    % Apply the parabolic wave propagation factor in the frequency domain.
    %
    % IMPORTANT: mu here is the same *angular* normalized wavenumber (radians)
    % used throughout the Carrano/Rino model (mu = q*rho_F, and also
    % mu = 2*pi*f*(rho_F/v_eff) when mapping from temporal frequency).
    % The quadratic phase term exp(-j*mu^2/2) is written in this angular-mu
    % convention [Eq. 10, 2].
    propagation_factor = fftshift(exp(-1i * (mu).^2 / 2)); 
    propagated_scint_field = ifft(fft(initial_scint_field) .* propagation_factor);
end
