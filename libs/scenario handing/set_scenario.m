function sim_params = set_scenario(log, cpssm_root_dir, ...
    sim_params, parsed_argins)
%GET_SCENARIO Summary of this function goes here
%   Detailed explanation goes here

%% get RINEX file
[sim_params.temporal_support, rinex] = get_rinex(cpssm_root_dir, parsed_argins);

persistent scenario_cache
if isempty(scenario_cache)
    scenario_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
cache_key = get_scenario_cache_key(parsed_argins, sim_params);
use_cache = false;
if isKey(scenario_cache, cache_key)
    cached = scenario_cache(cache_key);
    sat_scen = cached.satelliteScenario;
    if isvalid(sat_scen)
        los_sats_params = cached.los_sats_params;
        use_cache = true;
        log.debug('Reusing cached satellite scenario for receiver [%s %s %s].', ...
            num2str(parsed_argins.rx_origin(1)), num2str(parsed_argins.rx_origin(2)), num2str(parsed_argins.rx_origin(3)));
    else
        remove(scenario_cache, cache_key);
    end
end

%% Get line-of-sight (LOS) satellites

if ~use_cache
    % create a satellite scenario
    sat_scen = satelliteScenario(sim_params.temporal_support(1), ...
        sim_params.temporal_support(end), sim_params.t_samp_geo);

    % add all satellites from the RINEX ephemerides in the scenario
    satellite(sat_scen, rinex);

    % FIXME: It is not clear to me how the velocity is defined or, at least,
    % FIXME: maintained constant. `geoTrajectory()` seems to require a starting and
    % FIXME: ending position, as well as the travel duration to compute the
    % FIXME: trajectory. It has some ways to add velocity (or speed) information, but
    % FIXME: it doesn't seem straightforward to set a constant velocity. It is because
    % FIXME: the velocity seems to have a strong dependence on the ending position and
    % FIXME: simulation time: A distant path seems to make the body accelerate during
    % FIXME: the trajectory. In other words, it seems to have a dynamic velocity. For
    % FIXME: the sake of first try, the receiver is being here to be static
    % SEE: https://www.mathworks.com/help/satcom/ref/geotrajectory-system-object.html
    rx_traj = geoTrajectory( ...
        [parsed_argins.rx_origin; parsed_argins.rx_origin], ...
        [0 sim_params.sim_time], ...
        'SampleRate', sim_params.t_samp_geo);

    % add receiver in the scenario as a moving platform
    platform(sat_scen, rx_traj, 'Receiver');

    % get parameters of the satellites in LOS with the receiver
    ac = access(sat_scen.Satellites, sat_scen.Platforms(1));
    los_sats_params = ac.accessIntervals;
end

% set the simulation parameters' frequencies and constellations based on
% the LOS satellites' parameters and user input arguments
sim_params = set_constellation_freq_svid(log, sim_params, ...
    parsed_argins, los_sats_params);

% get user-filtered LOS sats IDS (filtered by constellation and SV IDS)
filtered_los_sats_params = get_filtered_los_sat_params(log, sim_params, ...
    los_sats_params);

% get only the satellites in line-of-sight with the receiver
is_los_sat = ismember(sat_scen.Satellites.Name, filtered_los_sats_params.Source);
delete(sat_scen.Satellites(~is_los_sat))
% define 3D model of the satellite object
model_file = which("SmallSat.glb");
if ~isempty(model_file)
    for k = 1:numel(sat_scen.Satellites)
        sat_scen.Satellites(k).Visual3DModel      = model_file;    % GLB model
        sat_scen.Satellites(k).Visual3DModelScale = 5e5;          % scale up to 100 km so it’s visible
        sat_scen.Satellites(k).MarkerSize         = 0.1;          % hide the blue dot
    end
end
% set scenario
sim_params.satelliteScenario = sat_scen;

if ~use_cache
    scenario_cache(cache_key) = struct( ...
        'satelliteScenario', sat_scen, ...
        'los_sats_params', los_sats_params);
end
end

function cache_key = get_scenario_cache_key(parsed_argins, sim_params)
% Build a reproducible cache key for the satellite scenario.
    if isnat(parsed_argins.datetime)
        dt_str = 'NaT';
    else
        dt_str = datestr(parsed_argins.datetime, 'yyyy-mm-dd HH:MM:SS');
    end
    cache_key = jsonencode(struct( ...
        'rx_origin', round(parsed_argins.rx_origin(:), 6), ...
        'datetime', dt_str, ...
        'sim_time', parsed_argins.sim_time, ...
        't_samp_geo', sim_params.t_samp_geo, ...
        'constellations', sort(string(parsed_argins.constellations)), ...
        'frequencies', sort(string(parsed_argins.frequencies)), ...
        'svids', sort(string(parsed_argins.svids)), ...
        'rinex_file', parsed_argins.rinex_filename, ...
        'download', logical(parsed_argins.is_download_rinex)));
end
