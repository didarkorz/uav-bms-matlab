%% 06_estimate_cell_parameters.m
% Estimate nominal parameters and create four virtual cells for the 4S pack.

cfg = bms_load_cfg();

if ~exist(cfg.files.nasa, "file")
    run(fullfile(cfg.paths.scripts, "step01_import_nasa.m"));
end
if ~exist(cfg.files.oxford, "file")
    run(fullfile(cfg.paths.scripts, "step02_import_oxford.m"));
end
if ~exist(cfg.files.stanford, "file")
    run(fullfile(cfg.paths.scripts, "step04_import_stanford.m"));
end

Qn_est_Ah = cfg.pack.nominalCellCapacity_Ah;
R0_est_Ohm = mean(cfg.cells.R0_Ohm);
Cth_est_J_per_C = mean(cfg.cells.Cth_J_per_C);
hA_est_W_per_C = mean(cfg.cells.hA_W_per_C);

if exist(cfg.files.nasa, "file")
    S = load(cfg.files.nasa);
    if isfield(S, "nasaTable") && ~isempty(S.nasaTable)
        capValid = S.nasaTable.capacity_Ah(~isnan(S.nasaTable.capacity_Ah));
        if ~isempty(capValid)
            Qn_est_Ah = max(Qn_est_Ah, min(5.2, max(capValid)));
        end
    end
end

if exist(cfg.files.stanford, "file")
    S = load(cfg.files.stanford);
    if isfield(S, "stanfordSummary") && ~isempty(S.stanfordSummary)
        irValid = S.stanfordSummary.internal_resistance_Ohm(~isnan(S.stanfordSummary.internal_resistance_Ohm));
        if ~isempty(irValid)
            R0_est_Ohm = max(0.012, min(0.030, mean(irValid, "omitnan")));
        end
        chargeTimes = S.stanfordSummary.charge_time_s(~isnan(S.stanfordSummary.charge_time_s));
        if ~isempty(chargeTimes)
            hA_est_W_per_C = max(0.60, min(1.00, 3600 / max(mean(chargeTimes), 1)));
        end
    end
end

cell_id = (1:cfg.pack.numCells).';
capacity_Ah = cfg.cells.capacity_Ah(:);
R0_Ohm = cfg.cells.R0_Ohm(:);
initial_soc = cfg.cells.initialSoC(:);
initial_temp_C = cfg.cells.initialTemp_C(:);
R1_Ohm = cfg.cells.R1_Ohm(:);
C1_F = cfg.cells.C1_F(:);
Cth_J_per_C = cfg.cells.Cth_J_per_C(:);
hA_W_per_C = cfg.cells.hA_W_per_C(:);
eta_charge = cfg.cells.eta_charge(:);

virtualCells = table( ...
    cell_id, capacity_Ah, R0_Ohm, initial_soc, initial_temp_C, ...
    R1_Ohm, C1_F, Cth_J_per_C, hA_W_per_C, eta_charge, ...
    'VariableNames', {'cell_id', 'capacity_Ah', 'R0_Ohm', 'initial_soc', 'initial_temp_C', 'R1_Ohm', 'C1_F', 'Cth_J_per_C', 'hA_W_per_C', 'eta_charge'});

estimates = struct();
estimates.Qn_est_Ah = Qn_est_Ah;
estimates.R0_est_Ohm = R0_est_Ohm;
estimates.Cth_est_J_per_C = Cth_est_J_per_C;
estimates.hA_est_W_per_C = hA_est_W_per_C;
estimates.virtualCells = virtualCells;

save(cfg.files.cellParameters, "estimates");
writetable(virtualCells, fullfile(cfg.paths.results, "identified_cell_parameters.csv"));

fprintf("Estimated nominal capacity Qn: %.3f Ah\n", Qn_est_Ah);
fprintf("Estimated average R0: %.4f Ohm\n", R0_est_Ohm);
fprintf("Saved virtual cell parameters to %s\n", fullfile(cfg.paths.results, "identified_cell_parameters.csv"));
