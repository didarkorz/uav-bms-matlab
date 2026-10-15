function files = bms_find_dataset_files(rootCandidates, patterns)
%BMS_FIND_DATASET_FILES Search multiple roots and glob patterns.

if ischar(rootCandidates) || isstring(rootCandidates)
    rootCandidates = cellstr(rootCandidates);
end
if ischar(patterns) || isstring(patterns)
    patterns = cellstr(patterns);
end

files = struct("name", {}, "folder", {}, "date", {}, "bytes", {}, "isdir", {}, "datenum", {});
seen = containers.Map("KeyType", "char", "ValueType", "logical");

for rootIdx = 1:numel(rootCandidates)
    rootPath = rootCandidates{rootIdx};
    if ~exist(rootPath, "dir")
        continue;
    end

    for patternIdx = 1:numel(patterns)
        searchSets = {
            dir(fullfile(rootPath, patterns{patternIdx}))
            dir(fullfile(rootPath, "**", patterns{patternIdx}))
            };

        for setIdx = 1:numel(searchSets)
            current = searchSets{setIdx};
            for fileIdx = 1:numel(current)
                entry = current(fileIdx);
                fullPath = fullfile(entry.folder, entry.name);
                if entry.isdir || contains(fullPath, "__MACOSX")
                    continue;
                end
                key = lower(fullPath);
                if ~isKey(seen, key)
                    seen(key) = true;
                    files(end + 1, 1) = entry; %#ok<AGROW>
                end
            end
        end
    end
end
end
