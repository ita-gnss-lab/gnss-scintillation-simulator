function plot_scintillation_psd(cpssm_root_dir, out)
% plot_all_amp_phase_psds
%
% Syntax:
%   plot_all_amp_phase_psds(scint_field_struct, irr_params, doppler_frequency_struct, mu_struct, rhof_veff_ratio_vector)
%
% Description:
%   Generates **2x3 subplots** for each scintillation intensity level (Severe, Moderate, Weak).
%   - **Columns**: L1, L2, L5 frequency bands.
%   - **Rows**: Intensity PSD (top) and Phase PSD (bottom).
%
%   The intensity PSD of the post-propagation scintillation field is
%   compared with the theoretical intensity spectrum from `Ispectrum.m`.
%
%   The phase PSDs compare:
%   - Pre-propagation phase realization (`detrended_phase_realization`)
%   - Post-propagation phase (`phase(scint_field)`)
%   - Theoretical phase PSD (`norm_phase_psd`)
%
% Inputs:
%   scint_field_struct - Struct containing scintillation realizations for each scenario:
%       .Severe.L1, .Severe.L2, .Severe.L5
%       .Moderate.L1, .Moderate.L2, .Moderate.L5
%       .Weak.L1, .Weak.L2, .Weak.L5
%
%   irr_params - Struct with spectral parameters (.U, .p1, .p2, .mu0) for each scenario.
%   doppler_frequency_struct - Struct with Doppler frequency arrays for each scenario & freq.
%   mu_struct - Struct with the normalized wavenumber arrays for each scenario & freq.
%   rhof_veff_ratio_vector - 1x3 array containing (rho_F / v_eff) ratios for L1, L2, L5.
%
%
% Outputs:
%   None (generates multiple figures, one for each intensity level).
%
% Notes:
%   - This code is an adaptation of [1] and [2]
%
% References:
%   [1] "GenerateGPSPhaseScreenRealization.m" from the GNSS Scintillation
%       Simulator examples, available at
%       https://github.com/cu-sense-lab/gnss-scintillation-simulator/blob/master/examples/GenerateGPSPhaseScreenRealization.m
%       [Accessed: 10-02-2025].
%
%   [2] "Display_SpectraModel.m" from the GNSS Scintillation Simulator
%       examples, available at
%       https://github.com/cu-sense-lab/gnss-scintillation-simulator/blob/master/examples/Display_SpectraModel.m
%       [Accessed: 10-02-2025].
%
% Example:
%   plot_all_amp_phase_psds(scint_field_struct, irr_params_set, doppler_frequency_struct, mu_struct, rhof_veff_ratio_vector);
%
% Author:
%   Rubem Vasconcelos Pacelli
%   ORCID: https://orcid.org/0000-0001-5933-8565
%   Email: rubem.engenharia@gmail.com
%
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com

%% Initalize
severity = out.severity;
frequency_support = out.doppler_frequency_support;

%% PSD of amplitude and phase of the ionospheric scintllation
% all constellation names
constellations = setxor(string(fieldnames(out)).', ...
    ["doppler_frequency_support", "satelliteScenario", "severity"]);
for constellation = constellations
    % Frequency names for this constellation
    freq_names = string(fieldnames(out.(constellation).spectral)).';
    % for all rx-sat scenario
    for i = 1:numel(out.(constellation).scenario)
        % Create new figure for each scenario
        fig = figure('Name', sprintf('%s Scintillation - Intensity & Phase PSDs', severity), 'Position',[50,50,1400,550]);
        try
            set(fig, 'WindowState', 'maximized');
        catch
            % Fallback for older MATLAB releases without WindowState support
            set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        end
        set(fig, 'DefaultTextFontName', 'Helvetica');
        tiledlayout(2, numel(freq_names), "TileSpacing", "compact");
        sgtitle(sprintf('Scintillation PSD Analysis: Intensity & Phase (%s) for %s satellite %s', ...
            severity, upper(out.(constellation).scenario(i).sat.OrbitPropagator), ...
            out.(constellation).scenario(i).sat.Name), 'FontSize', 30, ...
            'FontName', 'Helvetica');
        for j = 1:numel(freq_names)
            % get parameters
            freq_name = freq_names(j);
            spectral_params = out.(constellation).spectral.(freq_name);
            rhof_veff_ratio = out.(constellation).scenario(i).(freq_name).rhof_veff_ratio;
            intensity_psd_1sided_post = out.(constellation).scenario(i).(freq_name).amplitude.psd_postprop;
            preprop_phase_psd_1sided = out.(constellation).scenario(i).(freq_name).phase.psd.preprop_1sided;
            postprop_phase_psd_1sided = out.(constellation).scenario(i).(freq_name).phase.psd.postprop_1sided;
            phase_psd_1sided_theory = out.(constellation).scenario(i).(freq_name).phase.psd.theo_phase;
            s4 = out.(constellation).scenario(i).(freq_name).S4;

            % Compute theoretical intensity spectrum I(mu) on a controlled mu-grid
            % (interpolated from ispectrum's adaptive mu samples).
            f_pos = frequency_support(frequency_support > 0);
            mu_pos = 2 * pi * f_pos * rhof_veff_ratio;

            [Imu, muAxis, theoretical_s4_val] = Ispectrum(cpssm_root_dir, ...
                spectral_params.U, spectral_params.p1, spectral_params.p2, ...
                spectral_params.mu0);

            Imu_safe = max(Imu, 1e-300);
            logImu_interp = interp1(log10(muAxis), log10(Imu_safe), log10(mu_pos), 'pchip', 'extrap');
            Imu_interp = 10.^logImu_interp;
            % Convert I(mu) to a PSD vs Hz for comparison with FFT-based PSDs.
            % With mu = 2*pi*f*(rho_F/v_eff) and S4^2 = (1/2*pi)*∫ I(mu) dmu, we have:
            % S4^2 = ∫ [(rho_F/v_eff) * I(mu(f))] df.
            Imu_interp = rhof_veff_ratio * Imu_interp;

            % Plot Simulated Intensity PSD
            nexttile(j);
            hold on;
            plot(f_pos, 10*log10(intensity_psd_1sided_post), 'LineWidth', 1.2);
            plot(f_pos, 10*log10(Imu_interp), 'r--', 'LineWidth', 1.2);
            set(gca, 'XScale', 'log', 'FontName', 'Helvetica', 'FontSize', 20);
            xlabel('Doppler Frequency (Hz)', 'FontName', 'Helvetica', 'FontSize', 20);
            ylabel('Intensity PSD [dB]', 'FontName', 'Helvetica', 'FontSize', 20);
            title(sprintf('%s %s | S_4: Th. %.3f, Exp. %.3f | ρ_F/v_{eff} = %.2f', severity, freq_name, theoretical_s4_val, s4, rhof_veff_ratio), 'FontSize', 20, 'FontName', 'Helvetica');
            legend( ...
                'Post-Propagation PSD', ...
                'Theoretical Model', ...
                'Location', 'best', ...
                'FontName', 'Helvetica', ...
                'FontSize', 15);
            grid on;
            grid minor;
            hold off;

            % Plot Phase PSD
            nexttile(j + numel(freq_names));
            hold on;
            plot(frequency_support(frequency_support>0), ...
            10*log10(preprop_phase_psd_1sided), 'LineWidth', 1.2);
            plot(frequency_support(frequency_support>0), ...
                10*log10(postprop_phase_psd_1sided), 'LineWidth', 1.2);
            plot(frequency_support(frequency_support>0), ...
                10*log10(phase_psd_1sided_theory(frequency_support>0)), 'LineWidth', 1.2);
            set(gca, 'XScale', 'log', 'FontName', 'Helvetica', 'FontSize', 20);
            xlabel('Doppler Frequency (Hz)', 'FontName', 'Helvetica', 'FontSize', 20);
            ylabel('Phase PSD [dB]', 'FontName', 'Helvetica', 'FontSize', 20);
            title(sprintf('%s %s Phase PSD | ρ_F/v_{eff} = %.2f', severity, freq_name, rhof_veff_ratio), ...
                'FontSize', 20, 'FontName', 'Helvetica');
            legend('Pre-Propagation PSD', 'Post-Propagation PSD', ...
                'Theoretical Model', 'Location', 'best', 'FontName', ...
                'Helvetica', 'FontSize', 20);
            grid on;
            grid minor;
            hold off;
        end
    end
end

end
