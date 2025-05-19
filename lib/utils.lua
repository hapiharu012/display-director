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
        return false, "空のコマンド", -1
    end
    
    if logger then logger("コマンド実行: " .. cmd) end
    
    -- コマンド実行
    local success, exitCode, _, stdout, stderr = os.execute(cmd .. " 2>&1")
    
    -- 詳細な実行結果を取得
    local resultDetails = ""
    local resultFile = io.popen(cmd .. " 2>&1", "r")
    if resultFile then
        local fullResult = resultFile:read("*a")
        resultFile:close()
        resultDetails = fullResult
    end
    
    -- より詳細なログ出力
    if logger then
        logger("コマンド実行結果:")
        logger("- 成功: " .. tostring(success))
        logger("- 終了コード: " .. tostring(exitCode))
        
        if #resultDetails > 0 then
            if #resultDetails > 800 then
                -- 長い出力は先頭と末尾を表示
                logger("- 出力 (長いため一部のみ表示):")
                logger("--- 先頭 400 バイト ---")
                logger(resultDetails:sub(1, 400))
                logger("--- 末尾 400 バイト ---")
                logger(resultDetails:sub(-400))
            else
                logger("- 出力:\n" .. resultDetails)
            end
        else
            logger("- 出力: なし")
        end
        
        -- displayplacerコマンドの場合は特別な処理
        if cmd:match("displayplacer") then
            -- 現在のディスプレイ状態を確認
            logger("--- コマンド実行後のディスプレイ状態確認 ---")
            local displayInfo = hs.execute("/opt/homebrew/bin/displayplacer list 2>&1")
            if #displayInfo > 800 then
                logger("displayplacer list 結果 (一部):\n" .. displayInfo:sub(1, 800) .. "...")
            else
                logger("displayplacer list 結果:\n" .. displayInfo)
            end
        end
    end
    
    -- 成功判定と詳細な戻り値
    return success, resultDetails, exitCode
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