function [Imu, mu, S4] = Ispectrum(cpssm_root_dir, U, p1, p2, mu0, varargin)
%Ispectrum Compute the normalized intensity spectrum I(mu) using ispectrum(.exe).
%
% Uses ispectrum "option 1" (no mu-grid arguments): the executable computes S4
% via adaptive quadrature and writes I(mu) samples (at integrator-chosen mu
% points) to ispectrum.dat.
%
% Note (Windows + WSL/UNC paths):
%   On Windows, MATLAB's `system()` uses `cmd.exe`, which does not support
%   UNC paths (e.g., \\wsl.localhost\...). If MATLAB's current folder is a
%   UNC path, `cmd.exe` will fall back to a Windows folder and `ispectrum`
%   may fail to write ispectrum.dat/ispectrum.log (or write them elsewhere).
%   To avoid this, this wrapper always runs `ispectrum` in a local temp
%   directory and reads outputs from there.
%
% Calling convention:
%   [Imu, mu, S4] = Ispectrum(cpssm_root_dir, U, p1, p2, mu0)
%
% Parameters:
%   cpssm_root_dir - Path to the CPSMM root (contains libs/plots/Ispectrum/)
%   U    - universal strength parameter
%   p1   - low-wavenumber index
%   p2   - high-wavenumber index
%   mu0  - normalized break scale (called "mub" in ispectrum.c docstring)
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
if ~exist(exe_path, 'file')
    error('Ispectrum:ExecutableNotFound', 'ispectrum executable not found: %s', exe_path);
end

IspecParams = generateIspecParams(U, p1, p2, mu0, mu_outer, mu_inner);

% Outputs (initialize)
Imu = [];
mu = [];
S4 = NaN;
cmd_output = '';

% Always run in a local temp directory so ispectrum can write its output files.
% Use a unique temp directory to avoid collisions between calls.
run_dir = tempname;
mkdir(run_dir);
data_path = fullfile(run_dir, 'ispectrum.dat');
log_path = fullfile(run_dir, 'ispectrum.log');

try
    %% Option 1: compute S4
    % NOTE: the options of ispectrum are controlled by the number of arguments passed.
    if ispc
        cmd = sprintf('cd /d "%s" && "%s" %s', run_dir, exe_path, IspecParams);
    else
        cmd = sprintf('cd "%s" && "%s" %s', run_dir, exe_path, IspecParams);
    end
    [status, cmd_output] = system(cmd);
    if status ~= 0
        error(cmd_output);
    end
    
    if ~exist(log_path, 'file')
        error('Ispectrum fault: ispectrum.log not found. Output:\n%s', cmd_output);
    end
    
    % Prefer numeric parsing of ispectrum.log (more robust than token indexing).
    try
        params = readmatrix(log_path, 'NumHeaderLines', 1);
        if isempty(params)
            params = readmatrix(log_path);
        end
        if size(params, 2) < 9
            error('Unexpected ispectrum.log format.');
        end
        S4 = params(1, 9);
    catch
        % Fallback for older MATLAB versions / unexpected formats.
        fid = fopen(log_path, 'r');
        if fid < 0
            error('Ispectrum fault: failed to open ispectrum.log.');
        end
        logtxt = textscan(fid, '%s');
        fclose(fid);
        if numel(logtxt{1}) < 22
            error('Ispectrum fault: unexpected token count in ispectrum.log.');
        end
        S4 = str2double(logtxt{1}{22});
    end
    
    if ~exist(data_path, 'file')
        error('Ispectrum fault: ispectrum.dat not found. Output:\n%s', cmd_output);
    end
    
    data = importdata(data_path);
    [~, ndata] = size(data);
    if ndata ~= 3
        error('Ispectrum fault: unexpected data format in ispectrum.dat.');
    end
    
    mu = data(:, 1);
    Imu = data(:, 2);
catch ME
    cleanup_ispectrum_files(run_dir);
    rethrow(ME);
end

cleanup_ispectrum_files(run_dir);
end

% Auxiliary function to clean up temporary files
function cleanup_ispectrum_files(dir_path)
    dat = fullfile(dir_path, 'ispectrum.dat');
    logf = fullfile(dir_path, 'ispectrum.log');
    if exist(dat, 'file')
        delete(dat);
    end
    if exist(logf, 'file')
        delete(logf);
    end
    if exist(dir_path, 'dir')
        try
            rmdir(dir_path, 's');
        catch
        end
    end
end
