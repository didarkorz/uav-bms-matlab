%% 00_project_setup.m
% Create folders, add paths, check MATLAB version, and create cfg.

clc;

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
addpath(fullfile(projectRoot, "config"));
addpath(fullfile(projectRoot, "functions"));
addpath(fullfile(projectRoot, "scripts"));
addpath(fullfile(projectRoot, "simulink"));

cfg = bms_project_setup_impl();
assignin("base", "cfg", cfg);

fprintf("Project setup complete.\n");
fprintf("MATLAB version: %s %s\n", cfg.environment.matlab_version, cfg.environment.matlab_release);
fprintf("Project root: %s\n", cfg.paths.projectRoot);
fprintf("Configuration saved to: %s\n", cfg.files.cfg);
