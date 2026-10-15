%% step02_import_oxford.m
% Executable Oxford import step for the full diploma pipeline.

cfg = bms_load_cfg();
[oxfordTable, oxfordOcvProfiles, importInfo] = bms_import_oxford_dataset(cfg);

if isempty(oxfordTable)
    fprintf("Dataset file not found. Place file in /data/raw/oxford\n");
end

save(cfg.files.oxford, "oxfordTable", "oxfordOcvProfiles", "importInfo", "-v7.3");
writetable(oxfordTable, fullfile(cfg.paths.processed, "oxford_standardized.csv"));
if ~isempty(oxfordOcvProfiles)
    writetable(oxfordOcvProfiles, fullfile(cfg.paths.processed, "oxford_ocv_profiles.csv"));
end

fprintf("Saved Oxford standardized table with %d rows.\n", height(oxfordTable));
fprintf("Saved Oxford OCV profile points with %d rows.\n", height(oxfordOcvProfiles));
