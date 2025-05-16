-- 共通ユーティリティ関数

local utils = {}

-- モジュールの読み込みを処理する関数
function utils.loadModule(name)
    local status, module = pcall(require, name)
    if status then
        return module
    else
        print("モジュール読み込みエラー: " .. name .. " - " .. module)
        return nil
    end
end

-- テーブルのキー数を数える関数
function utils.countTableKeys(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- コマンド実行ラッパー
function utils.executeCommand(cmd, logger)
    -- 空のコマンドをチェック
    if cmd == nil or cmd == "" or cmd:match("^%s*$") then
        if logger then logger("空のコマンドが渡されました: " .. (cmd or "nil")) end
        return false, "空のコマンド"
    end
    
    if logger then logger("コマンド実行: " .. cmd) end
    
    -- コマンド実行
    local exitCode = os.execute(cmd)
    
    -- 実行結果を取得（可能な場合）
    local result = ""
    local resultFile = io.popen(cmd .. " 2>&1", "r")
    if resultFile then
        result = resultFile:read("*a")
        resultFile:close()
    end
    
    if logger then 
        logger("実行結果: exitCode=" .. tostring(exitCode) .. 
               ", 出力長さ=" .. #result .. 
               (result ~= "" and "\n" .. result:sub(1, 100) .. "..." or ""))
    end
    
    -- 成功判定
    local success = (exitCode == 0 or exitCode == true)
    return success, result
end

-- ファイルの存在確認
function utils.fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

return utils 