-- ロギング機能

local logger = {}

-- ロガーを作成する関数
function logger.create(logPath)
    local logFunc = function(message)
        local f = io.open(logPath, "a")
        if f then
            f:write("\n=== " .. os.date() .. " ===\n" .. message .. "\n")
            f:close()
        else
            print("ログファイルを開けませんでした: " .. logPath)
        end
    end
    
    -- 初期化メッセージ
    logFunc("------- ロガー初期化 -------")
    
    return logFunc
end

return logger 