function [propagated_complex_field, theo_phase_psd, ...
    detrended_phase_realization, mu, postprop_amplitude, postprop_phase, ...
    intensity_psd_1sided_post, s4, preprop_phase_psd_1sided, ...
    postprop_phase_psd_1sided] ...
    = get_scintillation_realization(sim_params, out, constellation, ...
    freq_name, rhof_veff_ratio, nfft, varargin)
% get_scintillation_time_series
%
% Syntax:
%   propagated_scint_field = get_scintillation_time_series(sim_params, ...
%                                                          irr_params, ...
%                                                          rhof_veff_ratio, ...
%                                                          seed)
%
% Description:
%   Generates a time-domain scintillation field by performing the following steps:
%   1) Determines a suitable FFT length (nfft) based on the simulation time and
%      sampling interval (dt) via the helper function nicefftnum.m.
%   2) Computes a Doppler frequency axis over the range [-Nyquist, +Nyquist).
%   3) Constructs the spatial frequency axis (mu) by scaling the Doppler
%      axis with 2*pi*rhof_veff_ratio.
%   4) Obtains the normalized phase spectral density function (norm_phase_sdf)
%      from get_norm_phase_sdf, using the irregularity parameters (irr_params)
%      and mu.
%   5) Calls get_phase_realization to generate a random phase realization
%      based on norm_phase_sdf.
%   6) Propagates the resulting phase-perturbed wavefield by calling
%      get_propagated_field, yielding the final time-domain scintillation
%      field.
%
% Inputs:
%   sim_params - Struct containing simulation parameters, including:
%       .sim_time : Total simulation time (seconds)
%       .dt              : Time step (seconds)
%
%   irr_params - Struct with irregularity parameters required by
%                get_norm_phase_sdf, typically containing:
%       .U               : Turbulence strength
%       .mu0             : Break wavenumber
%       .p1, .p2         : Spectral indices
%
%   rhof_veff_ratio    - Scalar representing (rho_F / v_eff), used to scale
%                        the Doppler frequency axis into a spatial/temporal
%                        frequency axis mu.
%
% Outputs:
%   propagated_scint_field - Complex time-domain scintillation field after
%                            applying phase perturbations and parabolic wave
%                            propagation.
%
% Dependencies:
%   - nicefftnum(sim_time_ratio)
%       Calculates an FFT size based on the ratio of sim_time/dt.
%   - get_norm_phase_sdf(mu, irr_params)
%       Computes a normalized phase spectral density function given mu and
%       irregularity parameters.
%   - get_phase_realization(norm_phase_sdf, D_mu, seed)
%       Generates a random (possibly complex) phase realization using the
%       normalized phase spectral density. Requires a parameter D_mu not shown
%       in this snippet.
%   - get_propagated_field(mu, detrended_phase_realization)
%       Applies a parabolic propagation factor in the frequency domain and
%       returns the propagated scintillation field.
%
% Notes:
%   - The development of this function was inspired by the code available at:
%     https://github.com/cu-sense-lab/gnss-scintillation-simulator_2-param/blob/master/Libraries/GenScintFieldRealization/GenScintFieldRealization.m
%
% Example:
%   % Assuming sim_params, irr_params, and D_mu are already defined or loaded:
%   sim_params.sim_time = 60;  % seconds
%   t_samp = 0.01;             % time step
%   irr_params.U   = 1.5;             % turbulence strength
%   irr_params.mu0 = 0.8;             % break wavenumber
%   irr_params.p1  = 2.0;             % spectral index (low freq)
%   irr_params.p2  = 3.5;             % spectral index (high freq)
%   ratio         = 0.5;              % example (rho_F / v_eff)
%   seed_val      = 12345;            % random seed
%
%   scint_field = get_scintillation_time_series(sim_params, ...
%                                               irr_params, ...
%                                               ratio, ...
%                                               seed_val);
% References:
%   [1] C. S. Carrano and C. L. Rino, “A theory of scintillation for 
%       two‐component power law irregularity spectra: Overview and 
%       numerical results,” Radio Science, vol. 51, no. 6, pp. 789–813, 
%       June 2016, https://doi.org/10.1002/2015RS005903.
%
% Author:
%   Rubem Vasconcelos Pacelli
%   ORCID: https://orcid.org/0000-0001-5933-8565
%   Email: rubem.engenharia@gmail.com
%
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com

%% Initialization
% FIXME: This varargin should be removed as it seems not necessary anymore
p = inputParser;
addParameter(p, 'data_type', 'double', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
data_type = p.Results.data_type;

doppler_frequency = out.doppler_frequency_support;
spectral_params = out.(constellation).spectral.(freq_name);
temporal_support = sim_params.temporal_support;
seed = sim_params.seed;

% Normalized wavenumber axis (Carrano/Rino convention).
%
% We model what is observed as a *time series* resulting from scanning a
% spatial phase screen with an effective scan velocity v_eff. Carrano relates
% temporal frequency f [cycles/s] to the normalized transverse wavenumber mu
% through:
%   mu = 2*pi*f*(rho_F/v_eff)
%
% Notes:
%   - mu is an *angular* normalized wavenumber (radians), consistent with
%     Carrano's use of cos(mu*xi) / exp(j*mu*xi) and the 1/(2*pi) inverse-Fourier
%     normalization in [1].
%   - `rhof_veff_ratio` is (rho_F / v_eff). Larger values stretch the same
%     Doppler axis to larger mu.
mu = 2 * pi * doppler_frequency * rhof_veff_ratio;
D_mu = mu(2) - mu(1);

%% Two-component-based theoretical phase PSD
% Obtain the normalized phase spectral density function.
% SEE" `plot(mu, 10*log10(norm_phase_psd))`
theo_phase_psd = get_theorerical_phase_psd(mu, spectral_params);

%% Obtain the phase time series realization
% Generate the random phase time series realization
% NOTE: This is not the propagated phase and represents only the refractive
% effect on the IPP. The difractive part occurs only when we propagate a
% complex field whose phase is `detrended_phase_realization`. If you
% subtract phase of the propagated complex field by
% `detrended_phase_realization`, you get the diffractive phase
% NOTE: we call it "detrented" because there is a function called `linex()`
% which removes the linear trend of the phase realization.
detrended_phase_realization = get_phase_realization(theo_phase_psd, ...
    D_mu, nfft, seed, data_type);

%% Propagate the scintillation field, i.e., `e^(1j*detrended_phase_realization)`
propagated_complex_field = get_propagated_field(mu, detrended_phase_realization);

%% Amplitude and phase signal of the postpropagated field
% compute amplitude and phase time series of the received
% scintillation signal
postprop_amplitude = abs(propagated_complex_field);
postprop_phase = get_corrected_phase(propagated_complex_field);

%% Postpropagated PSD of the amplitude (Intensity PSD)
% SEE: `plot(mu(mu>0), 10*log10(intensity_psd_1sided_post))`
intensity_psd_1sided_post = compute_psd_1sided(postprop_amplitude.^2, ...
    nfft, doppler_frequency);
s4 = get_S4(postprop_amplitude.^2);

%% Pre- and Postpropagated PSD of the phase
% PSDs computed here are *per-Hz* (Doppler frequency domain) because the input
% is a time series and `compute_psd_1sided` normalizes by df.
%
% When comparing against Carrano/Rino theoretical SDFs (functions of angular mu),
% you have two equivalent choices:
%   (A) Convert PSD_f(f) to a per-mu PSD via df/dmu, where mu = 2*pi*f*(rho_F/v_eff).
%   (B) Convert PSD_f(f) to Carrano's SDF convention directly:
%         PSD_f(f) = (rho_F/v_eff) * P(mu(f))  =>  P_est(mu) = PSD_f / (rho_F/v_eff)
%
% The plotting code in `plot_scintillation_psd.m` uses (B) so both intensity and
% phase are shown in Carrano's I(mu) / P(mu) conventions.

% NOTE: detrended_phase_realization contains only the refractive-related
% effect of the phase disturbance at the IPP point,
% which has not been propagated to the receiver yet
% SEE: `plot(mu(mu>0), preprop_phase_psd_1sided)`
preprop_phase_psd_1sided  = compute_psd_1sided(detrended_phase_realization, ...
    nfft, doppler_frequency);

% NOTE: `phase(scint_field)` is the phase of the complex field
% after the propagation, which contains not only the refractive
% part, but also the difracted part caused by the free-space
% propagation
% SEE: `plot(mu(mu>0), postprop_phase_psd_1sided)`
postprop_phase_psd_1sided = compute_psd_1sided(get_corrected_phase(propagated_complex_field), ...
    nfft, doppler_frequency);

%% Timeseries generation (and truncation)
% NOTE: `timetable` is recommended over `timeseries`. Timetables can store
% time-stamped data of varying types and have a broad set of supporting
% functions for preprocessing, restructuring, and analysis.
% SEE: https://www.mathworks.com/help/matlab/ref/timeseries.html#d126e1490452
detrended_phase_realization = timetable(temporal_support.', ...
    detrended_phase_realization(1:numel(temporal_support)).');

propagated_complex_field = timetable(temporal_support.', ...
    propagated_complex_field(1:numel(temporal_support)).');

postprop_amplitude = timetable(temporal_support.', ...
    postprop_amplitude(1:numel(temporal_support)).');

postprop_phase = timetable(temporal_support.', ...
    postprop_phase(1:numel(temporal_support)).');

end

% -------------------------------------------------------------------------

function psd_1sided = compute_psd_1sided(real_signal, nfft, ...
    doppler_freq)
% Compute the one-sided power spectral density function (PSD)
raw_fft = abs(fft(real_signal, nfft)).^2 / nfft;
partial_psd = raw_fft(2 : (nfft/2));
df = abs(doppler_freq(2) - doppler_freq(1));
psd_1sided = partial_psd / (nfft * df);
end
