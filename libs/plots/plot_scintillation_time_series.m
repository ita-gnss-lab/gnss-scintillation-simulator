function plot_scintillation_time_series(out)
% plot_all_magnitude_phase
%
% Syntax:
%   plot_all_magnitude_phase(scint_field_struct, time_vector)
%
% Description:
%   Generates a **2x1 subplot** for each scintillation intensity level (Severe, Moderate, Weak).
%   - **First row**: Magnitude values (10*log10(abs(scint).^2)) for L1, L2, L5.
%   - **Second row**: Phase values (phase(scint)) for L1, L2, L5.
%   - **Titles include computed S4 values** for each frequency band.
%
% Inputs:
%   scint_field_struct - Struct containing scintillation realizations for each scenario:
%       .Severe.L1, .Severe.L2, .Severe.L5
%       .Moderate.L1, .Moderate.L2, .Moderate.L5
%       .Weak.L1, .Weak.L2, .Weak.L5
%
%   time_vector - 1D array containing the time values (same for all scenarios & frequencies).
%
% Outputs:
%   None (generates multiple figures and saves them as PDFs).
%
% Example:
%   plot_all_magnitude_phase(scint_field_struct, time_vector);
%
% Author:
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com

%% Initialization
severities = out.severity;

%% Plot
constellations = setxor(string(fieldnames(out)).', ...
    ["doppler_frequency_support", "satelliteScenario", "severity"]);
% for all constellation
for constellation = constellations
    % Frequency names for this constellation
    freq_names = string(fieldnames(out.(constellation).spectral)).';
    % for all rx-sat scenario
    for i = 1:numel(out.(constellation).scenario)
        for severity = severities
            % Create figure and set Helvetica as default font
            fig = figure('Name', sprintf('%s Magnitude & Phase ', severity), ...
                'Position', [50, 50, 1400, 550], 'Color', 'w');
            try
                set(fig, 'WindowState', 'maximized');
            catch
                % Fallback for older MATLAB releases without WindowState support
                set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
            end
            set(fig, 'DefaultTextFontName', 'Helvetica');
            tiledlayout(2, 1, "TileSpacing", "compact");

            % Initialize storage for legend labels and S4 values
            legend_labels = cell(1, numel(freq_names));
            s4_values = zeros(1, numel(freq_names));

            % Plot Magnitude (Row 1)
            nexttile;
            hold on;
            for j = 1:numel(freq_names)
                freq_name = freq_names(j);
                scint_field = out.(constellation).scenario(i).(freq_name).complex_field_postprop;
                % Compute S4
                s4_values(j) = get_S4(abs(scint_field.Variables).^2);

                mag_timeseries_dB = varfun(@(x) 10*log10(abs(x).^2), scint_field);
                plot(mag_timeseries_dB.Time, mag_timeseries_dB.Fun_Var1, 'LineWidth', 2.4);
                set(gca, 'FontName', 'Helvetica', 'FontSize', 20);
                legend_labels{j} = sprintf('%s (S_4=%.3f)', freq_name, s4_values(j));
            end
            xlabel('Time (s)', 'FontName', 'Helvetica', 'FontSize', 20);
            ylabel('Magnitude [dB]', 'FontName', 'Helvetica', 'FontSize', 20);
            title(sprintf('%s - Magnitude (Power in dB)', severity), 'FontSize', 30, 'FontName', 'Helvetica');
            legend(legend_labels, 'Location', 'best', 'FontName', 'Helvetica', 'FontSize', 15);
            grid on;
            hold off;

            % Plot Phase (Row 2)
            nexttile;
            hold on;
            for j = 1:numel(freq_names)
                freq_name = freq_names(j);
                scint_field = out.(constellation).scenario(i).(freq_name).complex_field_postprop;
                phase_time_series = get_corrected_phase(scint_field.Var1);
                plot(scint_field.Time, phase_time_series, 'LineWidth', 2.4);
            end
            set(gca, 'FontName', 'Helvetica', 'FontSize', 20);
            xlabel('Time (s)', 'FontName', 'Helvetica', 'FontSize', 20);
            ylabel('Phase [rad]', 'FontName', 'Helvetica', 'FontSize', 20);
            title(sprintf('%s - Phase Evolution', severity), 'FontSize', 30, 'FontName', 'Helvetica');
            legend(freq_names, 'Location', 'best', 'FontName', 'Helvetica', 'FontSize', 15);
            grid on;
            hold off;

            sgtitle(sprintf('Magnitude & Phase Analysis: %s | %s satellite %s', ...
                severity, ...
                upper(out.(constellation).scenario(i).sat.OrbitPropagator), ...
                out.(constellation).scenario(i).sat.Name), 'FontSize', 45, ...
                'FontName', 'Helvetica');

            % Adjust figure paper size to match figure aspect ratio
            set(fig, 'PaperUnits', 'centimeters');
            fig_pos = get(fig, 'Position');
            fig_width_cm = fig_pos(3) * 2.54 / 96;
            fig_height_cm = fig_pos(4) * 2.54 / 96;
            set(fig, 'PaperSize', [fig_width_cm fig_height_cm]);
            set(fig, 'PaperPosition', [0 0 fig_width_cm fig_height_cm]);
        end
    end
end
end
