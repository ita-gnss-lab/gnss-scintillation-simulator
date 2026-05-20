function filtered_los_sat_params = get_filtered_los_sat_params(log, sim_params, los_sats_params, sat_scen)
    %GET_LOS_SATS Summary of this function goes here
    %   Detailed explanation goes here
    %% Initialization
    all_constellations = sim_params.const.all_constellations;
    % sim_params_svids = sim_params.svids;
    % TODO: remove this when GLONASS, Beidou, ZQSS, or NavIC become available
    idx = ismember(sim_params.constellations, ["glonass", "beidou", "zqss", "navic"]);
    sim_params_constellations = sim_params.constellations(~idx);
    all_svid_prefix = sim_params.const.all_svid_prefix;
    time_start = sim_params.temporal_support(1);
    time_end = sim_params.temporal_support(end);
    
    %% Get constellation-filtered LOS satellites
    filtered_ids = all_svid_prefix(ismember(all_constellations, sim_params_constellations));
    
    filtered_los_sat_params = los_sats_params(contains(los_sats_params.Source, filtered_ids), :);
    time_start.Format = 'HH:mm:ss';
    time_end.Format = 'HH:mm:ss';
    
    if any(filtered_los_sat_params.Duration < seconds(time_end - time_start))
        discarted_sats = filtered_los_sat_params(filtered_los_sat_params.Duration < seconds(time_end - time_start), :);
        for i = height(discarted_sats)
            log.info('The satellite %s was in LOS with the receiver, but its observation window of did not include the whole interval [%s, %s] and was therefore discarded.', discarted_sats(i,:).Source, time_start, time_end);
        end
        filtered_los_sat_params = filtered_los_sat_params(filtered_los_sat_params.Duration == seconds(time_end - time_start), :);
    end
    
    %% Get SVID-filtered LOS satellites
    requested_svids = string(sim_params.svids);
    if ~isempty(requested_svids) && ~(isscalar(requested_svids) && (requested_svids == "" || lower(requested_svids) == "all"))
        source_svids = arrayfun(@source_to_svid, filtered_los_sat_params.Source);
        keep_svid = ismember(source_svids, upper(requested_svids));
        filtered_los_sat_params = filtered_los_sat_params(keep_svid, :);
    end
    
    %% Apply elevation mask
    mask_deg = sim_params.elevation_mask_deg;
    rx = sat_scen.Platforms(1);
    sats = sat_scen.Satellites;
    sat_names = arrayfun(@(s) strtrim(string(s.Name)), sats); % normalize scenario satellite names once
    keep = true(height(filtered_los_sat_params), 1);
    for i = 1:height(filtered_los_sat_params)
        sat_name = strtrim(string(filtered_los_sat_params.Source(i)));
        sat_idx = find(sat_names == sat_name, 1);
        sat_obj = sats(sat_idx);
        try
            [~, elev_deg, ~] = aer(rx, sat_obj);
            keep(i) = ~isempty(elev_deg) && min(elev_deg) >= mask_deg;
        catch
            keep(i) = false;
        end
        if ~keep(i)
            log.info('Discarding %s: elevation below %.1f deg mask.', sat_name, mask_deg);
        end
    end
    filtered_los_sat_params = filtered_los_sat_params(keep, :);
    if height(filtered_los_sat_params) > sim_params.max_sats
        filtered_los_sat_params = filtered_los_sat_params(1:sim_params.max_sats, :); % enforce cap to avoid simulating unused sats
    end
end

function svid = source_to_svid(source)
    source = char(strtrim(string(source)));
    tokens = regexp(source, '(\d+)', 'tokens', 'once');
    if isempty(tokens)
        svid = "";
        return;
    end
    if contains(source, 'PRN:')
        svid = "G" + string(sprintf('%02d', str2double(tokens{1})));
    elseif contains(source, 'GAL Sat ID:')
        svid = "E" + string(sprintf('%02d', str2double(tokens{1})));
    else
        svid = string(source);
    end
end
