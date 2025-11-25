function sim_params = set_sim_params_from_argin(sim_params, parsed_argin)
%SET_SIM_PARAMS_FROM_ARGIN Update simulation parameters based on input arguments.
%   sim_params = SET_SIM_PARAMS_FROM_ARGIN(sim_params, parsed_argin) takes
%   the sim_params struct and add fields using values from
%   parsed_argin. The following parameters are set:
%     - drift_vel_ned: Drift velocity in NED frame (m/s)
%     - ipp_altitude:  Ionospheric Pierce Point altitude (m)
%     - severity:      Scintillation severity level ('strong','moderate','weak')
%     - sim_time:      Total simulation time (s)
%     - t_samp:        Sampling interval for scintillation time series (s)
%
%   Inputs:
%     sim_params   - Struct with default simulation parameters.
%     parsed_argin - Struct containing user-specified arguments:
%                    drift_vel_ned, rx_vel_ned, ipp_altitude,
%                    severity, sim_time, t_samp.
%
%   Output:
%     sim_params   - Updated simulation parameters struct.   
%
%   Example:
%     parsed_argin.drift_vel_ned = [0,0,0];
%     parsed_argin.rx_vel_ned    = [0,0,0];
%     parsed_argin.ipp_altitude  = 450e3;
%     parsed_argin.severity      = 'strong';
%     parsed_argin.sim_time      = 100;
%     parsed_argin.t_samp        = 1e-3;
%   sim_params = set_sim_params_from_argin(sim_params, parsed_argin);
%
% Author:
%   Rubem Vasconcelos Pacelli
%   ORCID: https://orcid.org/0000-0001-5933-8565
%   Email: rubem.engenharia@gmail.com
%
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com

%% User-defined or dafaulted parameters

%% drift velocity
sim_params.drift_vel_ned = parsed_argin.drift_vel_ned;

%% IPP altitude
sim_params.ipp_altitude = parsed_argin.ipp_altitude;

%% Severity
sim_params.severity = parsed_argin.severity;

% If user provided custom spectral parameters, attach them to sim_params.const.spectral.custom
if isfield(parsed_argin, 'spectral') && ~isempty(parsed_argin.spectral) && sim_params.severity == "custom"
	% expect parsed_argin.spectral already validated by parse_input_args
	sim_params.const.spectral.custom = parsed_argin.spectral;
end

%% Simulation time
sim_params.sim_time = parsed_argin.sim_time;

%% Seed
sim_params.seed = parsed_argin.seed;

%% Multiconstellation sats
sim_params.is_multiconst_sats = parsed_argin.is_multiconst_sats;

%% Elevation mask (deg)
sim_params.elevation_mask_deg = parsed_argin.elevation_mask_deg;

%% Scintillation sampling time
% NOTE: this sampling time is the value used to obtain the scintillation
% time series realization as well as its intensity and phase PSD
sim_params.t_samp = parsed_argin.t_samp;
end
