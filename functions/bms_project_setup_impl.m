function cfg = bms_project_setup_impl()
%BMS_PROJECT_SETUP_IMPL Create folders, add paths, and save cfg.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
folders = {
    fullfile(projectRoot, "data")
    fullfile(projectRoot, "data", "raw")
    fullfile(projectRoot, "data", "raw", "nasa")
    fullfile(projectRoot, "data", "raw", "oxford")
    fullfile(projectRoot, "data", "raw", "calce")
    fullfile(projectRoot, "data", "raw", "stanford")
    fullfile(projectRoot, "data", "processed")
    fullfile(projectRoot, "results")
    fullfile(projectRoot, "reports")
    };

for idx = 1:numel(folders)
    if ~exist(folders{idx}, "dir")
        mkdir(folders{idx});
    end
end

addpath(projectRoot);
addpath(fullfile(projectRoot, "config"));
addpath(fullfile(projectRoot, "functions"));
addpath(fullfile(projectRoot, "scripts"));
addpath(fullfile(projectRoot, "simulink"));

cfg = bms_default_cfg(projectRoot);
cfg.environment.matlab_version = version;

matlabInfo = ver("MATLAB");
if ~isempty(matlabInfo)
    cfg.environment.matlab_release = matlabInfo.Release;
else
    cfg.environment.matlab_release = "unknown";
end

save(cfg.files.cfg, "cfg");
save(fullfile(cfg.paths.processed, "cfg_snapshot.mat"), "cfg");
end
