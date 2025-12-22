function plot_scintillation_psd(cpssm_root_dir, out)
% plot_all_amp_phase_psds
%
% Syntax:
%   plot_all_amp_phase_psds(scint_field_struct, irr_params, doppler_frequency_struct, mu_struct, rhof_veff_ratio_vector)
%
% Description:
%   Generates **2x3 subplots** for each scintillation intensity level (Severe, Moderate, Weak).
%   - **Columns**: L1, L2, L5 frequency bands.
%   - **Rows**: Intensity PSD (top) and Phase PSD (bottom), plotted vs normalized
%     wavenumber \mu (mapped from the Doppler axis).
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
%   - This code is an adaptation of [1] and [2].
%   - The intensity subplot is shown in Carrano's I(mu) convention.
%     From Carrano's definition, S4^2 = (1/(2*pi)) * integral I(mu) dmu - 1.
%     With mu = 2*pi*f*(rho_F/v_eff), the estimated (one-sided) PSD_f relates
%     to I(mu) via: PSD_f(f) = (rho_F/v_eff) * I(mu(f)).
%   - The phase subplot is shown in Carrano's P(mu) convention, where:
%       Var(phi) = (1/(2*pi)) * integral P(mu) dmu
%     This relationship becomes clear from the generation of the phase 
%     realization in `get_phase_realization.m`, which uses P(mu)/2*pi. 
%     Therefore, the estimated PSD_f relates to P(mu) via:
%       PSD_f(f) = (rho_F/v_eff) * P(mu(f)).
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
%   [3] C. S. Carrano and C. L. Rino, “A theory of scintillation for 
%       two‐component power law irregularity spectra: Overview and 
%       numerical results,” Radio Science, vol. 51, no. 6, pp. 789–813, 
%       June 2016, https://doi.org/10.1002/2015RS005903.
%
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
screen_dpi = get(0, 'ScreenPixelsPerInch');
font_scale = max(0.75, min(1.0, screen_dpi / 120));
font_axis = round(14 * font_scale);
font_label = round(15 * font_scale);
font_title = round(16 * font_scale);
font_legend = round(13 * font_scale);
font_sgtitle = round(18 * font_scale);

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
	        fig = figure( ...
	            'Name', sprintf('%s Scintillation - Intensity & Phase PSDs', severity), ...
	            'Units', 'pixels', ...
	            'Position', [100, 100, 1200, 650]);
	        set(fig, 'PaperPositionMode', 'auto');
	        set(fig, 'DefaultTextFontName', 'Helvetica');
	        tiledlayout(2, numel(freq_names), "TileSpacing", "compact", "Padding", "compact");
	        sgtitle(sprintf('Scintillation PSD Analysis: Intensity & Phase (%s) for %s satellite %s', ...
	            severity, upper(out.(constellation).scenario(i).sat.OrbitPropagator), ...
	            out.(constellation).scenario(i).sat.Name), 'FontSize', font_sgtitle, ...
	            'FontName', 'Helvetica', 'Interpreter', 'none');
        for j = 1:numel(freq_names)
            % get parameters
            freq_name = freq_names(j);
            freq_name_char = char(freq_name);
            spectral_params = out.(constellation).spectral.(freq_name);
            rhof_veff_ratio = out.(constellation).scenario(i).(freq_name).rhof_veff_ratio;
            if rhof_veff_ratio <= 0
                error('Invalid rhof_veff_ratio (expected > 0): %g', rhof_veff_ratio);
            end
            intensity_psd_1sided_post = out.(constellation).scenario(i).(freq_name).amplitude.psd_postprop;
            preprop_phase_psd_1sided = out.(constellation).scenario(i).(freq_name).phase.psd.preprop_1sided;
            postprop_phase_psd_1sided = out.(constellation).scenario(i).(freq_name).phase.psd.postprop_1sided;
            phase_psd_1sided_theory = out.(constellation).scenario(i).(freq_name).phase.psd.theo_phase;
            s4 = out.(constellation).scenario(i).(freq_name).S4;

            %% Compute theoretical intensity spectrum I(mu) from ispectrum's
            % adaptive mu samples and interpolate onto the simulated mu grid.
            idx_pos = frequency_support > 0;
            f_pos = frequency_support(idx_pos);
            % Map temporal frequency f [cycles/s] to Carrano's *angular* normalized
            % wavenumber mu [rad] via:
            %   mu = 2*pi*f*(rho_F/v_eff)
            % This is why mu carries an explicit 2*pi factor.
            mu_pos = 2 * pi * f_pos * rhof_veff_ratio;
            mu_min = min(mu_pos);
            mu_max = max(mu_pos);
            xlim_mu = [mu_min / 1.2, mu_max * 1.2];

            [Imu, muAxis, theoretical_s4_val] = Ispectrum(cpssm_root_dir, ...
                spectral_params.U, spectral_params.p1, spectral_params.p2, ...
                spectral_params.mu0);

            valid_mu = muAxis > 0 & Imu > 0;
            if ~any(valid_mu)
                error('Ispectrum returned no positive mu samples for interpolation.');
            end
            muAxis_pos = muAxis(valid_mu);
            Imu_safe = Imu(valid_mu);
            logImu_interp = interp1(log10(muAxis_pos), log10(Imu_safe), log10(mu_pos), 'pchip', 'extrap');
            Imu_theory = 10.^logImu_interp;

            % Carrano convention (intensity):
            % ispectrum returns I(mu) directly, where mu is an *angular* normalized
            % wavenumber (radians).
            %
            % Derivation of the mapping between our FFT-based estimate (per Hz) and
            % Carrano's I(mu):
            %
            % 1) Carrano's model uses the inverse-Fourier normalization (see his
            %    correlation function expression, [Eq. (15), 3]):
            %       R_I(xi) = ∫ I(mu) cos(mu*xi) dmu/(2*pi)
            %    so at xi = 0:
            %       R_I(0) = ∫ I(mu) dmu/(2*pi)
            %    and the intensity-variance term is proportional to this integral.
            %
            % 2) In practice we estimate a one-sided PSD in the *temporal* domain:
            %       Var(I) = ∫ PSD_f(f) df
            %
            % 3) Carrano relates temporal frequency f [cycles/s] to mu [rad] by:
            %       mu = 2*pi*f*(rho_F/v_eff)  =>  dmu = 2*pi*(rho_F/v_eff) df
            %
            % 4) Substitute dmu into Carrano's integral:
            %       ∫ I(mu) dmu/(2*pi)
            %       = ∫ I(mu(f)) * 2*pi*(rho_F/v_eff) df/(2*pi)
            %       = ∫ (rho_F/v_eff) * I(mu(f)) df
            %
            % 5) Comparing integrands with Var(I) = ∫ PSD_f(f) df gives:
            %       PSD_f(f) = (rho_F/v_eff) * I(mu(f))
            %    therefore the "Carrano-style" estimated intensity SDF is:
            %       I_est(mu) = PSD_f / (rho_F/v_eff)
            %
            % Note: we work with one-sided (f>0) spectra and plot mu>0; as long as
            % theory and estimate use the same one-/two-sided convention, no extra
            % factor of 2 is needed here.
            Imu_est = intensity_psd_1sided_post / rhof_veff_ratio;

            % Plot intensity in Carrano convention
            nexttile(j);
            hold on;
            h_int_est = plot(mu_pos, 10*log10(Imu_est), 'LineWidth', 1.2);
            h_int_theory = plot(mu_pos, 10*log10(Imu_theory), 'r--', 'LineWidth', 1.2);
            h_int_mu0 = xline(spectral_params.mu0, '--', 'LineWidth', 1.0, ...
                'Color', [0.85 0.85 0.85]);
            set(gca, 'XScale', 'log', 'FontName', 'Helvetica', 'FontSize', font_axis);
            xlim(xlim_mu);
            y_int_db = [10*log10(Imu_est(:)); 10*log10(Imu_theory(:))];
            y_int_db = y_int_db(isfinite(y_int_db));
            if ~isempty(y_int_db)
                % Use a robust lower bound (ignore deep spikes), but never clip
                % the top of the curves (use max for the upper bound).
                ylo = floor(prctile(y_int_db, 1) / 5) * 5 - 20;
                yhi = ceil(max(y_int_db) / 5) * 5 + 5;
                if ylo >= yhi
                    ylo = min(y_int_db) - 5;
                    yhi = max(y_int_db) + 5;
                end
                ylim([ylo, yhi]);
            end
            xlabel('Normalized wavenumber $\mu$', 'FontName', 'Helvetica', 'FontSize', font_label, 'Interpreter', 'latex');
            ylabel('Intensity SDF $I(\mu)$ [dB]', 'FontName', 'Helvetica', 'FontSize', font_label, 'Interpreter', 'latex');
            % NOTE: use double backslashes inside sprintf() so the final string
            % contains single backslashes for the LaTeX interpreter (and avoids
            % sprintf escapes like '\r' for carriage return).
            title(sprintf(['%s %s | U=%.2f, $p_1$=%.2f, $p_2$=%.2f, ', ...
                '$\\mu_0$=%.2f | $S_4$: Th. %.3f, Exp. %.3f | $\\rho_F/v_{\\mathrm{eff}}$=%.2f'], ...
                severity, freq_name_char, spectral_params.U, spectral_params.p1, spectral_params.p2, ...
                spectral_params.mu0, theoretical_s4_val, s4, rhof_veff_ratio), ...
                'FontSize', font_title, 'FontName', 'Helvetica', 'Interpreter', 'latex');
            legend([h_int_est, h_int_theory, h_int_mu0], ...
                'Estimated $I(\mu)$', ...
                'Theoretical $I(\mu)$', ...
                'Spectral break $\mu_0$', ...
                'Location', 'best', ...
                'FontName', 'Helvetica', ...
                'FontSize', font_legend, ...
                'Interpreter', 'latex');
            grid on;
            grid minor;
            hold off;

            % Plot phase in Carrano convention
            nexttile(j + numel(freq_names));
            hold on;
            % Carrano phase SDF P(mu) is used directly to synthesize the phase
            % realization. 
            % SEE: `get_phase_realization.m`, which uses Δμ/(2π).
            %
            % Therefore, to compare the FFT-estimated phase spectra (per Hz) to the
            % theoretical P(mu), we use the same conversion as the intensity case:
            %   PSD_f(f) = (rho_F/v_eff) * P(mu(f))  =>  P_est(mu) = PSD_f / (rho_F/v_eff)
            phase_P_est_refractive = preprop_phase_psd_1sided / rhof_veff_ratio;
            phase_P_est_total = postprop_phase_psd_1sided / rhof_veff_ratio;
            phase_P_theory = phase_psd_1sided_theory(idx_pos);
            h_phase_refr = plot(mu_pos, 10*log10(phase_P_est_refractive), 'LineWidth', 1.2);
            h_phase_total = plot(mu_pos, 10*log10(phase_P_est_total), 'LineWidth', 1.2);
            h_phase_theory = plot(mu_pos, 10*log10(phase_P_theory), 'LineWidth', 1.2);
            h_phase_mu0 = xline(spectral_params.mu0, '--', 'LineWidth', 1.0, ...
                'Color', [0.85 0.85 0.85]);
            set(gca, 'XScale', 'log', 'FontName', 'Helvetica', 'FontSize', font_axis);
            xlim(xlim_mu);
            y_phase_db = [10*log10(phase_P_est_refractive(:)); 10*log10(phase_P_est_total(:)); 10*log10(phase_P_theory(:))];
            y_phase_db = y_phase_db(isfinite(y_phase_db));
            if ~isempty(y_phase_db)
                % Same idea: robust lower bound, but keep the true maximum visible.
                ylo = floor(prctile(y_phase_db, 1) / 5) * 5 - 20;
                yhi = ceil(max(y_phase_db) / 5) * 5 + 5;
                if ylo >= yhi
                    ylo = min(y_phase_db) - 5;
                    yhi = max(y_phase_db) + 5;
                end
                ylim([ylo, yhi]);
            end
            xlabel('Normalized wavenumber $\mu$', 'FontName', 'Helvetica', 'FontSize', font_label, 'Interpreter', 'latex');
            ylabel('Phase SDF $P(\mu)$ [dB]', 'FontName', 'Helvetica', 'FontSize', font_label, 'Interpreter', 'latex');
            title(sprintf(['%s %s Phase SDF | U=%.2f, $p_1$=%.2f, $p_2$=%.2f, ', ...
                '$\\mu_0$=%.2f | $\\rho_F/v_{\\mathrm{eff}}$=%.2f'], ...
                severity, freq_name_char, spectral_params.U, spectral_params.p1, spectral_params.p2, ...
                spectral_params.mu0, rhof_veff_ratio), ...
                'FontSize', font_title, 'FontName', 'Helvetica', 'Interpreter', 'latex');
            legend([h_phase_refr, h_phase_total, h_phase_theory, h_phase_mu0], ...
                'Estimated refractive $P(\mu)$', ...
                'Estimated total $P(\mu)$', ...
                'Theoretical $P(\mu)$', ...
                'Spectral break $\mu_0$', ...
                'Location', 'best', ...
                'FontName', 'Helvetica', ...
                'FontSize', font_legend, ...
                'Interpreter', 'latex');
            grid on;
            grid minor;
            hold off;
        end
    end
end

end
