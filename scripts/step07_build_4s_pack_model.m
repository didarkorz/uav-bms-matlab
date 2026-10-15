%% 07_build_4s_pack_model.m
% Build the MATLAB-only 4S battery pack model structure.

cfg = bms_load_cfg();

if ~exist(cfg.files.ocvLookup, "file")
    run(fullfile(cfg.paths.scripts, "step05_build_ocv_soc_table.m"));
end
if ~exist(cfg.files.cellParameters, "file")
    run(fullfile(cfg.paths.scripts, "step06_estimate_cell_parameters.m"));
end

lookupData = load(cfg.files.ocvLookup, "lookup");
parameterData = load(cfg.files.cellParameters, "estimates");

lookup = lookupData.lookup;
virtualCells = parameterData.estimates.virtualCells;

cells = struct([]);
for idx = 1:height(virtualCells)
    cells(idx).name = "Cell_" + idx;
    cells(idx).capacity_Ah = virtualCells.capacity_Ah(idx);
    cells(idx).R0_Ohm = virtualCells.R0_Ohm(idx);
    cells(idx).R1_Ohm = virtualCells.R1_Ohm(idx);
    cells(idx).C1_F = virtualCells.C1_F(idx);
    cells(idx).initial_soc = virtualCells.initial_soc(idx);
    cells(idx).initial_temp_C = virtualCells.initial_temp_C(idx);
    cells(idx).Cth_J_per_C = virtualCells.Cth_J_per_C(idx);
    cells(idx).hA_W_per_C = virtualCells.hA_W_per_C(idx);
    cells(idx).eta_charge = virtualCells.eta_charge(idx);
end

packModel = struct();
packModel.name = "UAV_4S_LiPo_ECM";
packModel.created_on = datestr(now, 31);
packModel.pack = cfg.pack;
packModel.ocv_lookup = lookup;
packModel.cells = cells;
packModel.notes = {
    'Each cell uses OCV(SOC,T) + R0 + one RC polarization state.'
    'SoC is propagated by Coulomb counting with optional OCV correction in the scenario runner.'
    'Temperature is a first-order lumped thermal state per cell.'
    };

save(cfg.files.packModel, "packModel");
writetable(virtualCells, fullfile(cfg.paths.results, "pack_model_cells.csv"));

fprintf("Saved 4S pack model to %s\n", cfg.files.packModel);
