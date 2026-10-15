function cfg = bms_load_cfg()
%BMS_LOAD_CFG Load cfg or create it on demand.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
cfgFile = fullfile(projectRoot, "results", "cfg.mat");

if exist(cfgFile, "file")
    S = load(cfgFile, "cfg");
    cfg = S.cfg;
else
    cfg = bms_project_setup_impl();
end
end
