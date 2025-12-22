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
%   To avoid this, this wrapper always:
%     (1) runs `ispectrum` from a local temp directory; and
%     (2) on Windows, copies the executable into that temp directory so the
%         command line never references UNC paths.
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
    %% Option 1: compute S4 (and write ispectrum.dat/ispectrum.log)
    % NOTE: ispectrum's options are controlled by the number of arguments passed.
    %
    % Important: on Windows, `system()` launches `cmd.exe` with MATLAB's current
    % directory. If MATLAB is running from a UNC path, `cmd.exe` can fail before
    % it even executes our command. So we temporarily `cd` to a local temp dir.
    orig_dir = pwd;
    dir_restore = onCleanup(@() safe_cd(orig_dir));

    % Avoid referencing UNC paths on Windows by copying the executable locally.
    local_exe_path = exe_path;
    if ispc
        local_exe_path = fullfile(run_dir, ispectrum_exe);
        copyfile(exe_path, local_exe_path);
    end

    safe_cd(run_dir);
    cmd = sprintf('"%s" %s', local_exe_path, IspecParams);
    [status, cmd_output] = system(cmd);
    % Always restore the original directory before cleanup/removal.
    safe_cd(orig_dir);
    clear dir_restore;

    % Some Windows/UNC combinations may produce a nonzero exit code even when
    % ispectrum generated the expected output files. Prefer file existence.
    if status ~= 0 && (~exist(log_path, 'file') || ~exist(data_path, 'file'))
        error('Ispectrum:ExecutionFailed', 'ispectrum failed (exit code %d).\nOutput:\n%s', status, cmd_output);
    elseif status ~= 0
        warning('Ispectrum:NonZeroExit', 'ispectrum exited with code %d but produced output files; continuing.\nOutput:\n%s', status, cmd_output);
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
    if exist('orig_dir', 'var')
        safe_cd(orig_dir);
    end
    cleanup_ispectrum_files(run_dir);
    rethrow(ME);
end

cleanup_ispectrum_files(run_dir);
end

function safe_cd(target_dir)
    try
        cd(target_dir);
    catch
    end
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
