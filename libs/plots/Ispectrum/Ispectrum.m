function [Imu, mu, S4] = Ispectrum(cpssm_root_dir, U, p1, p2, mu0, varargin)
%Ispectrum Compute the normalized intensity spectrum I(mu) using ispectrum(.exe).
%
% Uses ispectrum "option 1" (no mu-grid arguments): the executable computes S4
% via adaptive quadrature and writes I(mu) samples (at integrator-chosen mu
% points) to ispectrum.dat.
%
% Calling convention:
%   [Imu, mu, S4] = Ispectrum(cpssm_root_dir, U, p1, p2, mu0)
%
% Parameters:
%   cpssm_root_dir - Path to the CPSMM root (contains libs/plots/Ispectrum/)
%   U    - universal strength parameter
%   p1   - low-wavenumber index
%   p2   - high-wavenumber index
%   mu0  - normalized break scale (called "mub" in ispectrum.c help text)
%
% Optional name/value arguments:
%   'mu_outer' : normalized outer-scale wavenumber (default 0, omit)
%   'mu_inner' : normalized inner-scale wavenumber (default 0, omit)
%
% Outputs:
%   Imu - intensity spectrum samples I(mu)
%   mu  - mu values at which I(mu) was evaluated (non-uniform)
%   S4  - scintillation index from ispectrum.log

%% Validate required args
if ~(ischar(cpssm_root_dir) || isstring(cpssm_root_dir))
    error('Ispectrum:InvalidArgs', 'Expected cpssm_root_dir as a string/char path.');
end
cpssm_root_dir = char(cpssm_root_dir);

%% Parse optional arguments
p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'mu_outer', 0.0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'mu_inner', 0.0, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});

mu_outer = p.Results.mu_outer;
mu_inner = p.Results.mu_inner;

%% Resolve executable
if isunix
    ispectrum_exe = 'ispectrum';
elseif ispc
    ispectrum_exe = 'ispectrum.exe';
elseif ismac
    error('There is no executable for macOS. Compile Ispectrum for this operating system.');
else
    error('Unknown operating system.');
end

exe_path = fullfile(cpssm_root_dir, 'libs', 'plots', 'Ispectrum', ispectrum_exe);

IspecParams = generateIspecParams(U, p1, p2, mu0, mu_outer, mu_inner);

% Outputs (initialize)
Imu = [];
mu = [];
S4 = NaN;
cmd_output = '';

% Clean up any stale files
cleanup_ispectrum_files();

%% Option 1: compute S4
% NOTE: the options of ispectrum are controlled by the number of arguments passed.
cmd = ['"', exe_path, '" ', IspecParams];
[status, cmd_output] = system(cmd);
if status ~= 0
    error(cmd_output)
end

fid = fopen(fullfile('ispectrum.log'), 'r');
if fid < 0
    error('Ispectrum fault: ispectrum.log not found.');
end
logtxt = textscan(fid, '%s');
fclose(fid);
S4 = str2double(logtxt{1}{22});

data = importdata(fullfile('ispectrum.dat'));
[~, ndata] = size(data);
if ndata ~= 3
    cleanup_ispectrum_files();
    error('Ispectrum fault: unexpected data format in ispectrum.dat.');
end

mu = data(:, 1);
Imu = data(:, 2);

cleanup_ispectrum_files();
return

% Auxiliary function to clean up temporary files
    function cleanup_ispectrum_files()
        fclose('all');
        if exist('ispectrum.dat', 'file')
            delete(fullfile('ispectrum.dat'));
        end
        if exist('ispectrum.log', 'file')
            delete(fullfile('ispectrum.log'));
        end
    end

end
