%% init_bms_project.m
% Diploma thesis project initialization for a 4S LiPo battery management
% system charging model. This script keeps the project startup simple:
% it adds the required folders to the MATLAB path and loads one centralized
% parameter structure used by both MATLAB scripts and the Simulink model.

clearvars;
close all;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
addpath(fullfile(projectRoot, "config"));
addpath(fullfile(projectRoot, "functions"));
addpath(fullfile(projectRoot, "scripts"));
addpath(fullfile(projectRoot, "simulink"));

cfg = battery_parameter_setup();

disp("BMS thesis project initialized.");
disp("Parameter structure available as variable: cfg");
disp("Run scripts/run_bms_simulation.m for the MATLAB-only simulation.");
disp("Run simulink/build_bms_simulink_model.m to create the Simulink scaffold.");
