TTT2StatsConfigTable = {
    ["SQLiteCommitRate"] = 10
}

local function WriteConfig()
    local jsonString = util.TableToJSON(TTT2StatsConfigTable, true)
    file.Write("ttt2stats_config.json", jsonString)
end

local function LoadConfig()
    local jsonString = file.Read("ttt2stats_config.json", "DATA")
    local jsonTable = util.JSONToTable(jsonString)
    TTT2StatsConfigTable = jsonTable
end

local function GenerateOrLoadConfigFile() 
    if not file.Exists("ttt2stats_config.json", "DATA") then
        print("TTT2Stats: Config file not found, writing default config to data/config.json.")
        WriteConfig()
    else -- Validate JSON
        local jsonString = file.Read("ttt2stats_config.json", "DATA")
        local jsonTable = util.JSONToTable(jsonString)
        if jsonTable == nil then
            print("TTT2Stats: [ERROR] Config file is invalid, writing default config to data/config.json.")
            file.Delete("ttt2stats_config.json")
            WriteConfig()
        else
            local valid = true
            if jsonTable["SQLiteCommitRate"] == nil then
                valid = false
                print("TTT2Stats: [ERROR] Config file is missing SQLiteCommitRate. Using default config.")
            end
            if valid then
                print("TTT2Stats: Config file found, loading config.")
                LoadConfig()
            end
        end

    end
end

