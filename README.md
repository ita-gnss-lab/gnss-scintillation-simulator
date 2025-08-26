# GNSS Scintillation Simulator

This document provides a guide to the Compact Phase-screen-based Scintillation Model (CPSSM), a MATLAB-based tool for simulating ionospheric scintillation effects on GNSS signals. This software is a refactored and enhanced version of the original simulator developed by the CU SENSE Lab.

## 1. What this software is about

The GNSS Scintillation Simulator is a powerful tool for researchers and engineers working with Global Navigation Satellite Systems (GNSS). It simulates the effects of ionospheric scintillation, which are rapid fluctuations in the amplitude and phase of GNSS signals caused by irregularities in the ionosphere. These simulations are crucial for developing and testing robust GNSS receivers and algorithms that can mitigate the impact of scintillation on positioning accuracy and reliability.

This simulator is based on the phase-screen method, which models the ionosphere as a thin, turbulent layer that introduces phase and amplitude distortions to the traversing GNSS signals. The software is highly configurable, allowing users to specify various parameters related to the receiver, satellite, and ionospheric conditions.

## 2. Main features

The GNSS Scintillation Simulator offers a wide range of features, including:

*   **Multi-Constellation Support**: Simulates scintillation effects for multiple GNSS constellations, including GPS, Galileo, GLONASS, and BeiDou.
*   **Flexible Configuration**: Allows users to customize various simulation parameters, such as receiver position and velocity, simulation time, and ionospheric conditions.
*   **Automatic RINEX Data Handling**: Can automatically download and process RINEX files for ephemeris data.
*   **Modular and Extensible Design**: The code is organized into a modular structure, making it easy to understand, modify, and extend.
*   **Advanced Scintillation Modeling**: Implements a compact phase-screen-based scintillation model that can simulate weak, moderate, and strong scintillation conditions.
*   **Comprehensive Output**: Generates a variety of outputs, including time series of amplitude and phase, detrended phase, and normalized Power Spectral Density (PSD).

## 3. How to install and add to default MATLAB path on Linux and Windows

To use the GNSS Scintillation Simulator, you need to have MATLAB installed on your system. The installation process is straightforward and involves cloning the repository and adding the necessary folders to the MATLAB path.

### Installation

1.  **Clone the repository**:

    ```bash
    git clone https://github.com/ita-gnss-lab/gnss-scintillation-simulator.git
    ```

2.  **Add to MATLAB path**:

    You can add the simulator to the MATLAB path either temporarily for the current session or permanently.

    **Temporary (for the current session)**:

    In the MATLAB command window, navigate to the cloned repository's root folder and run the following command:

    ```matlab
    addpath(genpath(pwd));
    ```

    **Permanent**:

    You can use permanently add `gnss-scintillation-simulator` by adding it to `$HOME/Documents/MATLAB/startup.m` (on Linux) or `%USERPROFILE%\Documents\MATLAB\startup.m` (on Windows). The following script shows an example to automatically add all directories found in `${XDG_DATA_HOME:-$HOME/.local/share}/matlab` (for Linux systems):
    ```matlab
    %% Add path
    if isunix
      xdg_data_home_path = getenv('XDG_DATA_HOME');
      % if `xdg_data_home_path` is empty, fallback to the default
      % `XDG_DATA_HOME` path
      if isempty(xdg_data_home_path)
          xdg_data_home_path = [ '/home/' getenv('USER') '/.local/share' ];
      end

      matlab_path = [xdg_data_home_path '/matlab'];
      if isfolder(matlab_path)
          addpath(genpath(matlab_path));
          disp(['Welcome to MATLAB! The directory ' ...
              matlab_path ' has been added to the MATLAB path.']);
      else
          error('There is no path %s to the added', matlab_path);
      end
      clear matlab_path xdg_data_home_path
    elseif ispc
        error('There is no default paths for Windows.');
    elseif ismac
        error('There is no default paths for macOS.');
    else
        error('Unknown operating system.');
    end
    ```
    You can extend this for other operating systems. Then, `cpssm` should be called from the command window.

## 4. How to use (some MWE commands) and how to get help

The main function of the simulator is `cpssm()`. You can use it with various name-value pair arguments to configure the simulation.

### Minimal Working Example (MWE)

Here is a simple example of how to use the `cpssm()` function:

```matlab
% Run a simulation with default parameters
out = cpssm();

% Run a simulation with custom parameters
out = cpssm('constellation', 'gps', 'frequency', 'L1', 'sim_time', 600);
```

### Getting Help

To get help on the `cpssm()` function and its parameters, you can use the `help` command in MATLAB:

```matlab
help cpssm
```

This will display the function's documentation, including a detailed description of all the available parameters.

## 5. Authors
This refactored version of the GNSS Scintillation Simulator was developed by:

*   **Rubem Vasconcelos Pacelli**
    *   ORCID: [https://orcid.org/0000-0003-0412-5583](https://github.com/tapyu)
    *   Email: [rubem.engenharia@gmail.com](mailto:rubem.engenharia@gmail.com)
*   **Rodrigo de Lima Florindo**
    *   ORCID: [https://orcid.org/0000-0003-0412-5583](https://orcid.org/0000-0003-0412-5583)
    *   Email: [rdlfresearch@gmail.com](mailto:rdlfresearch@gmail.com)

## 6. Forking acknowledge from cu-sense-lab/gnss-scintillation-simulator

This project is a fork of the original GNSS Scintillation Simulator developed by the CU SENSE Lab at the University of Colorado.

The original repository can be found at: [https://github.com/cu-sense-lab/gnss-scintillation-simulator](https://github.com/cu-sense-lab/gnss-scintillation-simulator)

We acknowledge the significant contributions of the original authors and their pioneering work in this field.

