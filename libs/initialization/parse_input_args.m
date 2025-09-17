function [parsed_input_args, log] = parse_input_args(cspsm_root_dir, all_constellation, varargin)

%% Define default values
default_rx_origin       = [-23.2198 -45.8916  59.6780];         % [latitude (deg); longitude (deg); altitude (m)] -> São José dos Campos
default_rx_vel_ned      = [0 0 0];                              % [v1, v2, v3] where: v1 = west-east, v2 = south-north, v3 = up-down velocity
default_datetime        = datetime([2021 06 24 23 00 00]);      % datetime
default_rinex_filename  = "BRDM00DLR_R_20170500000_01D_MN.rnx"; % RINEX file name.
default_is_down_rinex   = false;                                % by default, do not download a RINEX file and use either the user-defined or default RINEX file
default_svids           = "";                                   % SVIDs. Empty string means that it should be defined interactively
default_constellations  = "";                                   % Constellations. Empty string means that it should be defined interactively
default_multiconst_sats = false;                                % Multiconstellation sats: All sats transmit at all considered frequencies
default_frequencies     = "all";                                % Default frequency. Empty string means that it should be defined interactively
default_log_lvl         = "DEBUG";                              % Default log level
default_sim_time        = 300;                                  % total simulation time in seconds
default_t_samp          = 10e-3;                                % sampling time in seconds
default_ipp_altitude    = 350e3;                                % IPP altitude in meters
default_drift_vel_ned   = [0 125 0];                            % Ionosphere drift velocity [vdx, vdy, vdz] in m/s
default_severity        = "strong";                             % Ionospheric scintllation severity
default_is_plot         = false;                                % Whether plot the ionospheric scintillation realization
default_is_play         = false;                                % Whether play an animation of the receiver and satellite geometry
default_seed            = 1;                                    % Default seed

%% Parsing phase 0: resolve the logging before anything else

p0 = inputParser;
% p.Unmatched will contain all key-values that are not parsed in this step
p0.KeepUnmatched = true;

% Add log_lvl parameter: must be either a either a nonfractional scalar, or
% a scalar string or a char array that belongs to {"DEBUG", "INFO", "WARN",
% "ERROR"}
addParameter(p0, 'log_lvl',   default_log_lvl, ...
    @(lvl) ((ischar(lvl) || (isstring(lvl) && isscalar(lvl))) && ...
    ismember(upper(string(lvl)),["DEBUG", "INFO", "WARN","ERROR"]) || ...
    (isscalar(lvl) && isnumeric(lvl) && (mod(lvl,1) == 0))) );

% parse it
parse(p0, varargin{:});

% get log
log = Logger(p0.Results.log_lvl);

% rebuilt `varargin` without `log_lvl` and its value (if they were passed)
unmatched_keys = fieldnames(p0.Unmatched);                 % e.g. {'rx_origin';'constellation';…}
unmatched_vals  = struct2cell(p0.Unmatched);                          % corresponding values
varargin = reshape([unmatched_keys unmatched_vals]',1,[]); % interleave into 1×(2*M) cell

%% Parse phase 1: parse the other the input arguments
p = inputParser;
% p.Unmatched will contain all key-values that are not parsed in this step
p.KeepUnmatched = true;
% Add download_rinex parameter: must be a logical scalar
addParameter(p, 'download_rinex',   default_is_down_rinex, ...
    @(x) isscalar(x) && islogical(x));
% Add plot parameter: must be a logical scalar
addParameter(p, 'plot',   default_is_plot, ...
    @(x) isscalar(x) && islogical(x));
% Add play parameter: must be a logical scalar
addParameter(p, 'play',   default_is_play, ...
    @(x) isscalar(x) && islogical(x));
% Add seed parameter: must be an integer scalar
addParameter(p, 'seed',   default_seed, ...
    @(x) isscalar(x) && (mod(x,1) == 0));
% Add rx_origin parameter: must be a numeric 3-element vector
addParameter(p, 'rx_origin',   default_rx_origin, ...
    @(x) isnumeric(x) && isvector(x) && numel(x)==3);
% Add rx_vel parameter: must be a numeric 3-element vector
addParameter(p, 'rx_vel_ned',      default_rx_vel_ned, ...
    @(x) isnumeric(x) && isvector(x) && numel(x)==3);
% Add sim_time parameter: must be a positive numeric scalar
addParameter(p, 'sim_time', default_sim_time, ...
    @(x) isnumeric(x) && isscalar(x) && x>0);
% Add t_samp parameter: must be a positive numeric scalar
addParameter(p, 't_samp',          default_t_samp, ...
    @(x) isnumeric(x) && isscalar(x) && x>0);
% Add ipp_altitude parameter: must be a positive numeric scalar
addParameter(p, 'ipp_altitude',  default_ipp_altitude, ...
    @(x) isnumeric(x) && isscalar(x) && x>0);
% Add drift_vel parameter: must be a numeric 3-element vector.
addParameter(p, 'drift_vel_ned',   default_drift_vel_ned, ...
    @(x) isnumeric(x) && isvector(x) && numel(x)==3);
% add constellation parameter: it must be one of the valid strings
addParameter(p, 'constellation', default_constellations, ...
    @(x) validate_constellation(log, all_constellation, x));
% add multiconst_sats parameter: it must be a logical scalar
addParameter(p, 'multiconst_sats', default_multiconst_sats, ...
    @(x) isscalar(x) && islogical(x));
% add rinex_filename parameter: must be a an empty string or a
% string containing a valid RINEX file
addParameter(p, 'rinex_filename', default_rinex_filename, ...
    @(rinex_filename) validade_rinex_filename(log, cspsm_root_dir, ...
    p.Results.download_rinex, rinex_filename));
% Add frequency parameter: valid strings depend on the set constellation
addParameter(p, 'frequency', default_frequencies, ...
    @(x) validate_frequency(log, p.Results.constellation, x));
% Add svid parameter: valid strings depend on the set constellation
addParameter(p, 'svid',       default_svids, ...
    @(x) validate_svid(log, p.Results.constellation, x));
% Add datetime parameter: must be datetime object and `rinex_filename` must be
% empty
addParameter(p, 'datetime',    default_datetime, ...
    @(x) validate_datetime(log, p.Results.download_rinex, ...
    p.Results.rinex_filename, x));
% Add severity parameter: must be "weak", "moderate", or "strong"
addParameter(p, 'severity',    default_severity, ...
    @(x) isscalar(string(x)) && ismember(x, ["weak", "moderate", "strong"]));

% parse it
parse(p, varargin{:});

%% Handle unmatched key-values inputs
unknown_keys = fieldnames(p.Unmatched);
if ~isempty(unknown_keys)
    % Join them into a comma‑separated list
    list = strjoin(unknown_keys, ', ');
    log.warning('', 'Ignored unknown key(s): %s', list);
end

%% Build the general_parameters struct from user input

% Parameters that may be overridden by the user:
parsed_input_args.rx_origin           = p.Results.rx_origin;                    % rx origin
parsed_input_args.rx_vel_ned          = p.Results.rx_vel_ned;                   % rx velocity
parsed_input_args.drift_vel_ned       = p.Results.drift_vel_ned;                % ionosphere drift velocity (m/s)
parsed_input_args.is_download_rinex   = p.Results.download_rinex;               % whether one should download the RINEX file
parsed_input_args.svids               = string(p.Results.svid);                 % satellite SVIDs
parsed_input_args.sim_time            = p.Results.sim_time;                     % total simulation time (s)
parsed_input_args.t_samp              = p.Results.t_samp;                       % sampling time (s)
parsed_input_args.ipp_altitude        = p.Results.ipp_altitude;                 % IPP altitude in meters
parsed_input_args.rinex_filename      = string(p.Results.rinex_filename);       % RINEX file path
parsed_input_args.datetime            = p.Results.datetime;                     % datetime
parsed_input_args.constellations      = lower(string(p.Results.constellation)); % constellations
parsed_input_args.is_multiconst_sats  = p.Results.multiconst_sats;              % multiconstellation sat mode
parsed_input_args.frequencies         = string(p.Results.frequency);            % frequencies
parsed_input_args.severity            = string(p.Results.severity);             % severity
parsed_input_args.is_plot             = p.Results.plot;                         % whether plot the ionospheric scintillation realization
parsed_input_args.is_play             = p.Results.play;                         % whether play an animation of the receiver and satellite geometry
parsed_input_args.seed                = p.Results.seed;                         % simulation seed

end

% -------------------------------------------------------------------------

function validade_rinex_filename(log, cspsm_root_dir, ...
    is_down_rinex, rinex_filename)
if ~ischar(rinex_filename) && ~(isstring(rinex_filename) && isscalar(rinex_filename))
    log.error('rinex_filename must be a char or string');
end

if is_down_rinex
    log.error('', [ ...
        'You must either set `download_rinex` to true to ' ...
        'download a RINEX file from CDDIS, or provide a ' ...
        'local RINEX file name.'
        ]);
end

try
    rinexinfo(fullfile(cspsm_root_dir, 'cache', rinex_filename));
catch ME
    switch ME.identifier
        case 'nav_positioning:rinexInternal:FileNotFound'
            % Build your custom text
            log.error( ...
              ME.identifier, ...
              ['Failed to read RINEX file "%s".\n', ...
               'Please check that it exists and is readable.\n', ...
               'Original error was:\n%s'], ...
              fullfile(cspsm_root_dir, 'cache', rinex_filename), ...
              ME.message ...
            );
    end
end

end

function validate_constellation(log, all_constellations, constellations)
if ~ischar(constellations) && ~isstring(constellations)
    log.error('', ['You must pass a char array, a scalar string, or a string array ' ...
        'for the desired frequencies.']);
end
constellations = lower(string(constellations));

% handle special values: "all" or ""
% if it is the scalar string "all" or ""
if isscalar(constellations) && (constellations == "all" ||  constellations == "")
    % NOTE: contellation set to `"all"` or `""` is always valid
    return
% if it isn't the scalar string "all" or "" but contains either in this
% array
elseif any(ismember(["all", ""], constellations))
    log.error('', ['You cannot pass "%s" along with other values. Either pass it solely,\n' ...
        'valid constellation values']);
end

% handle contellation names
idx = ismember(constellations,all_constellations);
if all(idx)
    % all inputs are valid constellation values
    return
else
    log.error('', 'The value(s) %s are not recognized as valid contellation name(s).', ...
        join(constellations(~idx), ','))
end
end

function validate_datetime(log, is_down_rinex, rinex_filename, datetime)
if ~isdatetime(datetime)
    log.error('datetime must be a datetime object.');
end

if year(datetime) < 2016
    log.error('', [ ...
        'You must must input a datetime with year 2016' ...
        'or later in order to download a RINEX file v3.04' ...
        ])
end

if ~is_down_rinex
    log.info([ ...
        'You have passed a datetime but have not set to\n' ...
        'download a RINEX file from CDDIS. In this case, only the minute and hour\n' ...
        'of the datetime will be used. The year, month, and day will be those\n' ...
        'defined in %s. If you intended to use\n' ...
        'the datetime to download from that year, month, and day, set download_rinex\n' ...
        'to true.\n'], rinex_filename);
end
end

function validate_svid(log, constellation, svid)
% validateSVID Returns true if `svid` is valid for the given constellation.
%
%  - If constellation is empty ("" or ''), only an empty SVID is allowed.
%  - For 'gps':   SVID must be 'Gxx' where xx ∈ [1,32].
%  - For 'galileo': SVID must be 'Exx' where xx ∈ [1,36].
%  - For 'glonass': SVID must be 'Rxx' where xx ∈ [1,24].
%  - For 'beidou':  SVID must be 'Cxx' where xx ∈ [1,37].
%  - For 'all':     SVID may be any of the above.
%
% Ranges from EU GNSS glossary: GPS 1–32, Galileo 1–36,
% GLONASS 1–24, BeiDou 1–37 :contentReference[oaicite:0]{index=0}.

% Must be char or string
if ~(ischar(svid) || isstring(svid))
    log.error('', 'SVID must be a string or char object.');
end

% when constellation is empty, the SVID can only be empty as well
if isempty(char(constellation)) && ~isempty(char(svid))
    log.error('', 'If you have not set a constellation, you cannot set a SVID.');
end

svid = strtrim(char(svid));        % convert to char and trim whitespace
if numel(svid) < 2
    log.error('A valid SVID must contain at least three characters.')
end

prefix = upper(svid(1));          % first letter
numpart = svid(2:end);            % the digits
% if the numpart (e.g., 17 in G17) is not a number, return as not valid
if ~all(isstrprop(numpart,'digit'))
    log.error("The two last SVID's characters must be numbers.")
end
numpart = str2double(numpart);

% Define valid ranges
switch lower(constellation)
    case 'gps'
        if ~((prefix=='G') && (numpart>=1 && numpart<=32))
            log.error('This SVID is not valid for GSP.')
        end
    case 'galileo'
        if ~((prefix=='E') && (numpart>=1 && numpart<=36))
            log.error('This SVID is not valid for Galileo.')
        end
    case 'glonass'
        if ~((prefix=='R') && (numpart>=1 && numpart<=24))
            log.error('This SVID is not valid for GLONASS.')
        end
    case 'beidou'
        if ~((prefix=='C') && (numpart>=1 && numpart<=37))
            log.error('This SVID is not valid for Beidou')
        end
    case 'all'
        if ~( (prefix=='G' && numpart<=32) || ...
                (prefix=='E' && numpart<=36) || ...
                (prefix=='R' && numpart<=24) || ...
                (prefix=='C' && numpart<=37) )
            log.error('There is no constellation in which this SVID is valid');
        end
end
end

function validate_frequency(log, constellations, freq)
%% chekc if it is char or string
if ~ischar(freq) && ~isstring(freq)
    log.error('', ['You must pass a char, string, or string array ' ...
        'for the desired frequencies.']);
end
% normalize inputs
constellations = lower(string(constellations));
freq           = string(freq);

%% handle special frequency value: `"all"`
% if it is the scalar string `"all"`
if isscalar(freq) && freq == "all"
    % NOTE: frequency set as "all" is always valid
    return
% if it isn't the scalar string `"all"` but contains it in this array
elseif any(ismember("all", freq))
    log.error('', ['You cannot pass "all" along with other values. Either pass it solely or pass\n' ...
        'valid frquency values']);
end

%% since `freq` to set to anything other than `"all"` `constellations` cannot be `""`
if constellations == ""
    log.error('', ['You cannot pass frequencies if you have not ' ...
        'defined a contellation.']);
end

%% define valid frequency labels for each used constellation
all_freq_names.gps     = ["L1", "L2", "L5"];
all_freq_names.galileo = ["E1", "E5a", "E5b", "E6"];
all_freq_names.glonass = ["G1", "G2", "G3"];
all_freq_names.beidou  = ["B1", "B2", "B3"];
% TODO: add ZQSS and NavIC
% for `constellations=="all"`, allow the union of the above
all_freq_names.all = unique([all_freq_names.gps, all_freq_names.galileo, ...
    all_freq_names.glonass, all_freq_names.beidou]);
% remove not used constellations
nonused_constellations = setxor(fieldnames(all_freq_names), constellations);
valid_freq_names = rmfield(all_freq_names, nonused_constellations);
valid_freq_names = struct2array(valid_freq_names);

%% Check that freq is a string or character vector and is among the allowed ones
if any(~ismember(freq, valid_freq_names))
    log.error('', ['You have passed frequency(ies) that are not valid ' ...
        'for the considered constellation(s).'])
end
%% check if there are constellations with no frequencies
for constellation=constellations
    if ~any(ismember(freq,all_freq_names.(constellation)))
        log.error('', ['You have passed have passed a constellation that doesn''t contain\n' ...
            'any frequency for it.'])
    end
end

end