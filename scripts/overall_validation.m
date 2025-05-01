% overall_validation.m
%
% Description:
%
% This script generates plots comparing the behavior of synthetic ionospheric scintillation 
% time series produced by a newly developed algorithm based on phase screen theory. The generated 
% plots display the time series alongside key parameters characterizing them, and they compare 
% the estimated power spectral densities with the theoretical expectations. This script serves 
% as a reference for GNSS researchers analyzing scintillation models.
% 
% Script Sections:
% 
% 1. Initialization
%    - Clears the workspace and command window.
%    - Adds the required library paths for custom functions and cached data.
% 
% 2. Model Setup
%    - Retrieves general simulation parameters.
%    - Obtains the ratio between rhof and veff for the L1 frequency.
%    - Retrieves the irregularity parameters for different scintillation scenarios.
%    - Performs frequency extrapolation of the irregularity parameters using the Strong 
%      scintillation case as reference (since the rhof_veff_ratio_vector does not depend on 
%      specific irregularity parameters).
% 
% 3. Scintillation Time Series Generation
%    - Defines the scintillation scenarios (strong, moderate, weak) and frequency bands (L1, L2, L5).
%    - Initializes structures to store the time series and associated parameters.
%    - Generates synthetic scintillation time series by iterating over each scenario and frequency,
%      applying the custom algorithm.
% 
% 4. Plotting for Validation
%    - Creates a time vector based on the simulation time and time step.
%    - Generates plots to validate the simulation by comparing the generated time series with 
%      theoretical power spectral densities and visualizing amplitude and phase behaviors.
% 
% Dependencies:
%
% This script relies on the following custom functions from the developed library:
%   - get_general_parameters
%   - get_rhof_veff_ratio
%   - get_irregularity_parameters
%   - freq_extrapolate
%   - get_scintillation_time_series
%   - plot_all_amp_phase_sdfs
%   - plot_all_magnitude_phase_time_series
%   - nicefftnum
% 
% Note:
% 
% - Detailed information regarding input parameters, expected outputs, and specific assumptions 
%   is provided within each of the individual functions.
%
% Author: Rodrigo de Lima Florindo
% ORCID: https://orcid.org/0000-0003-0412-5583
% Email: rdlfresearch@gmail.com

%% Initialization
clearvars; clc;

addpath(genpath(fullfile('..','libs')));
addpath(fullfile('..','cache'));

for prn = 1:32
    %% Model Setup
    general_params = get_general_parameters('prn', prn);
    rhof_veff_ratio_L1 = get_rhof_veff_ratio(general_params);
    irr_params_set = get_irregularity_parameters();

    extrapolated_irr_params = struct('strong', [], 'moderate', [], 'weak', []);

    % Note: The `rhof_veff_ratio_vector` array do not depend on the
    % irregularity parameters U, p1, p2 and mu0. Therefore, it is sufficient to
    % extrapolate it only for one scintillation scenario, which is in this case
    % the Strong case.
    [extrapolated_irr_params.strong, rhof_veff_ratio_vector] = ...
        freq_extrapolate(irr_params_set.strong, general_params, rhof_veff_ratio_L1);
    [extrapolated_irr_params.moderate, ~] = ...
        freq_extrapolate(irr_params_set.moderate, general_params, rhof_veff_ratio_L1);
    [extrapolated_irr_params.weak, ~] = ...
        freq_extrapolate(irr_params_set.weak, general_params, rhof_veff_ratio_L1);

    % NOTE: I want to see when rhof_veff_ratio_vector is very high
    if any(rhof_veff_ratio_vector > 10)
        %% Scintillation Time Series Generation
        scenarios = fieldnames(extrapolated_irr_params);
        frequencies = {'L1', 'L2', 'L5'};

        seed = 1;

        scint_field_struct = struct();
        norm_phase_sdf_struct = struct();
        detrended_phase_realization_struct = struct();
        mu_struct = struct();
        doppler_frequency_struct = struct();
        % Generate and store scintillation time series
        for i = 1:numel(scenarios)
            scenario = scenarios{i};
            for j = 1:numel(frequencies)
                freq = frequencies{j};
                [scint_field_struct.(scenario).(freq), ...
                    norm_phase_sdf_struct.(scenario).(freq), ...
                    detrended_phase_realization_struct.(scenario).(freq), ...
                    mu_struct.(scenario).(freq), ...
                    doppler_frequency_struct.(scenario).(freq)] = ...
                    get_scintillation_time_series( ...
                    general_params, ...
                    extrapolated_irr_params.(scenario).(freq), ...
                    rhof_veff_ratio_vector(j), ...
                    seed);
            end
        end

        %% Plotting functions for validation
        % Time vector at the using the simulation_time parameter.
        % Note: The scint_field_struct data have a different size than time_vector,
        % given that its size is estimated using the helping function nicefftnum.m.
        time_vector = 0 : general_params.dt : general_params.simulation_time - general_params.dt;
        
        plot_all_amp_phase_sdfs(scint_field_struct, extrapolated_irr_params, detrended_phase_realization_struct, doppler_frequency_struct, mu_struct, rhof_veff_ratio_vector);
        plot_all_magnitude_phase_time_series(scint_field_struct, time_vector);
    end
end