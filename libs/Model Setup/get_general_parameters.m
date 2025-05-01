function general_parameters = get_general_parameters(varargin)
% get_general_parameters Returns a struct with general simulation parameters.
%
% Syntax:
%   general_parameters = get_general_parameters()
%   general_parameters = get_general_parameters('rx_pos', value, 'rx_vel', value, ...
%                           'date_time', value, 'prn', value, ...
%                           'simulation_time', value, 'dt', value, ...
%                           'ipp_height', value, 'drift_velocity', value)
%
% Description:
%   Returns a struct containing various simulation parameters. If the user
%   supplies values for 'rx_pos', 'rx_vel', 'date_time', 'prn', 'simulation_time',
%   'dt', 'ipp_height', or 'drift_velocity' via name-value pairs, those values will
%   be used; otherwise, the default values are applied.
%
% Inputs (optional, as name-value pairs):
%   'rx_pos'          - Receiver position as a 3x1 vector:
%                           [latitude (radians); longitude (radians); height (meters)].
%                       Default: [0.3876; 1.9942; 59.6780].
%
%   'rx_vel'          - Receiver velocity as a 3x1 vector [v1; v2; v3], where:
%                           v1 = east-west velocity on the earth arc (m/s, eastward +),
%                           v2 = north-south velocity on the earth arc (m/s, northward +),
%                           v3 = up-down velocity (m/s, up +).
%                       Default: [0; 0; 0].
%
%   'date_time'       - Date and time as a vector [YYYY MM DD hh mm ss] or a datetime object.
%                       Default: [2014 01 02 10 00 00].
%
%   'prn'             - Satellite PRN number (an integer). Must be within [0, 32].
%                       Default: 18.
%
%   'simulation_time' - Total simulation time in seconds.
%                       Default: 300.
%
%   'dt'              - Sampling time in seconds.
%                       Default: 0.01.
%
%   'ipp_height'      - Ionospheric piercing point (IPP) height in meters.
%                       Default: 350000.
%
%   'drift_velocity'  - Ionosphere drift velocity as a 3x1 vector:
%                           [vdx, vdy, vdz] in m/s.
%                       Default: [0; 100; 0].
%
% Outputs:
%   general_parameters - A struct containing the following fields:
%       c               - Speed of light in vacuum (m/s).
%       gps_bands       - Frequencies for GPS bands [L1, L2, L5] in Hz.
%       rx_pos          - Receiver position.
%       rx_vel          - Receiver velocity.
%       date_time       - Date and time for the simulation.
%       prn             - Satellite PRN.
%       simulation_time - Total simulation time (s).
%       dt              - Sampling time (s).
%       ipp_height      - IPP height in meters.
%       drift_velocity  - Ionosphere drift velocity in m/s.
%
% Example:
%   % Use default parameters:
%   params = get_general_parameters();
%
%   % Override rx_pos, prn, simulation time, and dt:
%   params = get_general_parameters('rx_pos', [0.5; 2.1; 60], 'prn', 12, ...
%                                   'simulation_time', 600, 'dt', 0.005);
%
% Author:
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com

    %% Define default values
    default_rx_pos          = [0.3876; 1.9942; 59.6780];   % [latitude (rad); longitude (rad); height (m)]
    default_rx_vel          = [0; 0; 0];                   % [v1, v2, v3] where: v1 = east-west, v2 = north-south, v3 = up-down velocity
    default_date_time       = [2014 01 02 10 00 00];       % Date/time as [YYYY MM DD hh mm ss]; consider converting to datetime in future versions.
    default_prn             = 1;                           % Satellite PRN (must be within [0, 32])
    default_simulation_time = 300;                         % Total simulation time in seconds
    default_dt              = 0.01;                        % Sampling time in seconds
    default_ipp_height      = 350000;                      % IPP height in meters
    default_drift_velocity  = [0; 125; 0];                 % Ionosphere drift velocity [vdx, vdy, vdz] in m/s

    %% Create input parser and add parameters
    p = inputParser;
    
    % Add rx_pos parameter with validation: must be a numeric 3-element vector.
    addParameter(p, 'rx_pos', default_rx_pos, ...
        @(x) isnumeric(x) && isvector(x) && numel(x) == 3);
    
    % Add rx_vel parameter with validation: must be a numeric 3-element vector.
    addParameter(p, 'rx_vel', default_rx_vel, ...
        @(x) isnumeric(x) && isvector(x) && numel(x) == 3);
    
    % Add date_time parameter: accepts either a numeric vector of 6 elements or a datetime object.
    addParameter(p, 'date_time', default_date_time, ...
        @(x) (isnumeric(x) && numel(x) == 6) || isdatetime(x));
    
    % Add prn parameter with validation: must be a numeric scalar within the range [0, 32].
    addParameter(p, 'prn', default_prn, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 32);
    
    % Add simulation_time parameter: must be a positive numeric scalar.
    addParameter(p, 'simulation_time', default_simulation_time, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);
    
    % Add dt parameter: must be a positive numeric scalar.
    addParameter(p, 'dt', default_dt, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);
    
    % Add ipp_height parameter: must be a positive numeric scalar.
    addParameter(p, 'ipp_height', default_ipp_height, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);
    
    % Add drift_velocity parameter: must be a numeric 3-element vector.
    addParameter(p, 'drift_velocity', default_drift_velocity, ...
        @(x) isnumeric(x) && isvector(x) && numel(x) == 3);
    
    % Parse the inputs provided by the user.
    parse(p, varargin{:});
    
    %% Build the general_parameters struct
    general_parameters = struct();
    
    % Constant simulation parameters:
    general_parameters.c = 299792458;  % Speed of light in vacuum (m/s)
    
    % GPS frequencies: defined as multiples of the 10.23 MHz fundamental frequency.
    general_parameters.gps_bands = [154*10.23e6, ...  % L1 frequency in Hz
                                    120*10.23e6, ...  % L2 frequency in Hz
                                    115*10.23e6];     % L5 frequency in Hz
    
    % Parameters that may be overridden by the user:
    general_parameters.rx_pos          = p.Results.rx_pos;           % [latitude (rad); longitude (rad); height (m)]
    general_parameters.rx_vel          = p.Results.rx_vel;           % [v1, v2, v3] with: v1 = east-west, v2 = north-south, v3 = up-down velocity
    general_parameters.date_time       = p.Results.date_time;        % Simulation start date and time
    general_parameters.prn             = p.Results.prn;              % Satellite PRN (0 to 32)
    general_parameters.simulation_time = p.Results.simulation_time;  % Total simulation time (s)
    general_parameters.dt              = p.Results.dt;               % Sampling time (s)
    general_parameters.ipp_height      = p.Results.ipp_height;       % IPP height in meters
    general_parameters.drift_velocity  = p.Results.drift_velocity;   % Ionosphere drift velocity (m/s)
end
