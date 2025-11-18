function [temporal_support, rinex] = get_rinex(cpssm_root_dir, parsed_argins)
%GET_RINEX Summary of this function goes here
%   Detailed explanation goes here

%% Initialization

% Cache parsed RINEX structures so subsequent cpssm() calls in the same
% MATLAB session (e.g., when generating many examples) do not re-read and
% re-parse the navigation file from disk. The temporal support depends on
% the same inputs, so we cache that alongside the RINEX struct.
persistent rinex_cache
if isempty(rinex_cache)
    rinex_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

is_download_rinex = parsed_argins.is_download_rinex;
dtime             = parsed_argins.datetime;
rinex_filename    = parsed_argins.rinex_filename;
sim_time          = parsed_argins.sim_time;
t_samp            = parsed_argins.t_samp;

% Use a composite cache key so different RINEX files, datetimes, or
% sampling settings do not collide.
cache_key = get_rinex_cache_key(is_download_rinex, rinex_filename, dtime, sim_time, t_samp);
if isKey(rinex_cache, cache_key)
    cached = rinex_cache(cache_key);
    temporal_support = cached.temporal_support;
    rinex = cached.rinex;
    return;
end

%% get RINEX from user inputs
if is_download_rinex
    rinex = download_rinex(cpssm_root_dir, ...
                dtime);

    % NOTE: Since the `dtime` was used to download from CDDIS, the start
    % simulation start time is totally defined in this variable
else
    rinex = rinexread(fullfile(cpssm_root_dir, ...
        'cache', ...
        rinex_filename));

    % NOTE: Since the RINEX file was not downloaded from CDDIS using
    % `dtime`, only hh:mm:ss of `dtime` carries meaning. Therefore,
    % the correct start_time should be DD/MM/YYYY from the RINEX file,
    % but hh:mm:ss from the `dtime`
    y = year(rinex.GPS.Time(1));
    m = month(rinex.GPS.Time(1));
    d = day(rinex.GPS.Time(1));
    h = hour(dtime);
    mn = minute(dtime);
    s = second(dtime);
    dtime = datetime(y, m, d, h, mn, s);
end

% define simulation temporal support for the scintillation time series
temporal_support = dtime:seconds(t_samp):dtime+seconds(sim_time);

% Memorize the newly computed outputs for the rest of this MATLAB session.
rinex_cache(cache_key) = struct( ...
    'temporal_support', temporal_support, ...
    'rinex', rinex);
end

function cache_key = get_rinex_cache_key(is_download_rinex, rinex_filename, dtime, sim_time, t_samp)
% Build a reproducible key that captures every parameter affecting the
% RINEX load/temporal support so the cache only hits for identical runs.
    if is_download_rinex
        rinex_id = sprintf('download:%s', datestr(dtime, 'yyyy-mm-dd'));
    else
        rinex_id = sprintf('local:%s', rinex_filename);
    end
    cache_key = jsonencode(struct( ...
        'rinex', rinex_id, ...
        'datetime', datestr(dtime, 'yyyy-mm-dd HH:MM:SS'), ...
        'sim_time', sim_time, ...
        't_samp', t_samp));
end
