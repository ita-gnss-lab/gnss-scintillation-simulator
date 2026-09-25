function sim_params = get_const_sim_params()
%GET_CTE_SIM_PARAMS Returns constant simulation parameters for the CPSSM model.
%   sim_params = GET_CTE_SIM_PARAMS returns a struct containing fields:
%     c               - Speed of light in vacuum (m/s)
%     earth_radius    - Earth radius (m)
%     all_constellations   - Supported constellations (array of strings)
%     valid_constellations - Currently implemented constellations
%     all_svid_prefix      - Satellite ID prefixes for each constellation
%     all_freqs              - Frequency names and values for GPS, Galileo,
%                              GLONASS, and BeiDou
%     spectral             - Spectral parameters (U_ref, mu0_ref, p1, p2)
%                            for strong, moderate, and weak scintillation
%     freq_ref            - Reference frequency name and value for extrapolation
%     t_samp_geo           - Geometry sampling time step (s)
%     seed                - Default random seed for reproducibility
%
% Example:
%   sim_params = get_const_sim_params();
% 
% Author:
%   Rubem Vasconcelos Pacelli
%   ORCID: https://orcid.org/0000-0001-5933-8565
%   Email: rubem.engenharia@gmail.com
% 
%   Rodrigo de Lima Florindo
%   ORCID: https://orcid.org/0000-0003-0412-5583
%   Email: rdlfresearch@gmail.com
%% Physical parameters
sim_params.const.c = 299792458;            % Speed of light in vacuum (m/s)
sim_params.const.earth_radius = 6378.137e3; % Earth radius (m)
%% Contellation parameters
sim_params.const.all_constellations = ["gps","galileo","glonass","beidou", "zqss", "navic"];
% NOTE: at the moment, "glonass", "beidou", "zqss", "navic" are not valid constellation as
% NOTE: they are not implemented in the `satellite()` function
% SEE: https://www.mathworks.com/help/satcom/ref/satellitescenario.satellite.html
% TODO: when all constellations are available, remove `valid_constellations` and
% TODO: sitck with `all_constellations`
sim_params.const.valid_constellations = ["gps","galileo"];
% all possible constellations and their repectives IDS, shown in
% `los_sat_params.Source`
sim_params.const.all_svid_prefix = ["PRN:","GAL Sat ID:"];

% frequency
% GPS L1 (1575.42e6), L2 (1227.60e6), L5 (1176.45e6) relative to fundamental
gps_f0 = 10.23e6; % GPS fundamental frequency
sim_params.const.all_freqs.name.gps     = ["L1", "L2", "L5"];
sim_params.const.all_freqs.value.gps     = [154*gps_f0, 120*gps_f0, 115*gps_f0];
% Galileo E1, E5a, E5b, E6
sim_params.const.all_freqs.name.galileo = ["E1", "E5a", "E5b", "E6"];
sim_params.const.all_freqs.value.galileo = [1575.42e6, 1176.45e6, 1207.14e6, 1278.75e6];
% GLONASS G1, G2, G3
sim_params.const.all_freqs.name.glonass = ["G1", "G2", "G3"];
sim_params.const.all_freqs.value.glonass = [1602e6, 1246e6, 1202.025e6];
% BeiDou B1, B2, B3
sim_params.const.all_freqs.value.beidou  = [1561.098e6,1207.14e6, 1268.52e6];
sim_params.const.all_freqs.name.beidou  = ["B1", "B2", "B3"];

%% spectral(AKA irregularity) parameters (U, p₁, p₂, μ₀) used as references for frequency extrapolation
% NOTE: These parameters are part of the extrapolation technique shown in
% NOTE: [1, eq.(15), (16), and (17)], where the spectral parameters for L1
% NOTE: (1575.42MHz) were estemated by using the IPE (iteractive parameters
% NOTE: estimation), introduced in [3] and further explained in [2, Section 4].
% NOTE: In this code, while the scaling parameter (ρF/veff) is initially computed
% NOTE: for L1 in `get_rhof_veff_ratio()`, its U and μ₀ are hardcoded as constant
% NOTE: values. Then, ρF/veff, U, and μ₀ are extrapolated from L1 to the desired
% NOTE: frequency (there is no extrapolation step for p1 and p2).

% TODO: cite ref
sim_params.const.spectral.strong.U_ref   = 2;
sim_params.const.spectral.strong.mu0_ref = 0.55;
sim_params.const.spectral.strong.p1      = 2.45;
sim_params.const.spectral.strong.p2      = 3.7;
% TODO: cite ref
sim_params.const.spectral.moderate.U_ref = 0.6;
sim_params.const.spectral.moderate.mu0_ref = 0.7;
sim_params.const.spectral.moderate.p1 = 2.7;
sim_params.const.spectral.moderate.p2 = 3.3;
% TODO: cite ref
sim_params.const.spectral.weak.U_ref   = 0.05;
sim_params.const.spectral.weak.mu0_ref = 1;
sim_params.const.spectral.weak.p1      = 3;
sim_params.const.spectral.weak.p2      = 3;
% SEE: [2, Section 4]
sim_params.const.spectral.freq_ref.name  = sim_params.const.all_freqs.name.gps(1);   % L1
sim_params.const.spectral.freq_ref.value = sim_params.const.all_freqs.value.gps(1);  % L1

%% Geometry sampling time
% NOTE: this time sampling is used to obtain the geometric simulation of
% NOTE: the receiver and satellite propagation
% TODO: At the moment, the sample time is set to one second. As it becomes
% TODO: clearer what this value should be, you must reset it as either hardcoded
% TODO: or from input argument
sim_params.t_samp_geo = 1;

end

