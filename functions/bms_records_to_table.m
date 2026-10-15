function T = bms_records_to_table(records, datasetId, sourceFile)
%BMS_RECORDS_TO_TABLE Convert recursive MAT records into the standard table.

T = table();
for idx = 1:numel(records)
    rec = records{idx};
    part = bms_standardize_timeseries( ...
        rec.time_s, rec.voltage_V, rec.current_A, rec.temp_C, ...
        rec.capacity_Ah, datasetId, rec.cell_id, rec.cycle_id);
    part.source_file = repmat(string(sourceFile), height(part), 1);
    part.record_path = repmat(rec.path, height(part), 1);
    T = [T; part]; %#ok<AGROW>
end
end
