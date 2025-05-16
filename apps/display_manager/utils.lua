-- ディスプレイマネージャー用ユーティリティ関数

local displayUtils = {}

-- 外部モニターUUIDキー生成
function displayUtils.getExternalKey()
    local uuids = {}
    for _, s in ipairs(hs.screen.allScreens()) do
        if s ~= hs.screen.primaryScreen() then
            table.insert(uuids, s:getUUID())
        end
    end
    table.sort(uuids)
    return table.concat(uuids, ",")
end

-- 共通のコマンド抽出関数
function displayUtils.extractDisplayplacerCommand(input, logger)
    -- NULL対策
    if input == nil then
        if logger then logger("入力がnilです") end
        return ""
    end
    
    -- 入力をトリミング
    input = input:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- まずは入力をそのまま使用（引用符がすでに付いているケース）
    if input:match("^displayplacer%s+\"id:[^\"]+") then
        if logger then logger("コマンドをそのまま使用: " .. input:sub(1, 50) .. "...") end
        return input
    end
    
    -- Execute the command below の後の行を探す（最も正確）
    local executePattern = "Execute the command below.-\n\n(displayplacer[^\n]+)"
    local executeCmd = input:match(executePattern)
    if executeCmd then
        if logger then logger("Execute後のコマンド抽出: " .. executeCmd:sub(1, 50) .. "...") end
        return executeCmd
    end
    
    -- 行単位で探す
    for line in input:gmatch("[^\r\n]+") do
        if line:match("^displayplacer%s+") and not line:match("example") and not line:match("degree:90") then
            if logger then logger("行単位抽出: " .. line:sub(1, 50) .. "...") end
            
            -- 引用符の確認
            if line:match("\"id:[^\"]+") then
                -- すでに引用符があるので、そのまま返す
                return line
            else
                -- 引用符がない場合は追加する
                local result = "displayplacer"
                for id, config in line:gmatch("id:([^%s]+)%s+([^i][^d]:.+?degree:[0-9]+)") do
                    result = result .. string.format(" \"id:%s %s\"", id, config)
                end
                
                -- 抽出に成功した場合
                if result ~= "displayplacer" then
                    if logger then logger("引用符追加: " .. result:sub(1, 50) .. "...") end
                    return result
                end
                
                -- 通常の正規表現だけでは抽出できない場合は、別のアプローチを試す
                local modifiedLine = line:gsub("^displayplacer%s+", "")
                local parts = {}
                
                -- 各モニター設定を取得
                for part in modifiedLine:gmatch("id:[^%s]+%s+[^i][^d]:.+?degree:[0-9]+") do
                    table.insert(parts, "\"" .. part .. "\"")
                end
                
                if #parts > 0 then
                    result = "displayplacer " .. table.concat(parts, " ")
                    if logger then logger("代替抽出方法: " .. result:sub(1, 50) .. "...") end
                    return result
                end
                
                -- それでも抽出できない場合は、元の行を返す
                return line
            end
        end
    end
    
    -- 引用符なしで始まる場合の処理
    if input:match("^displayplacer%s+id:") then
        local result = "displayplacer"
        local foundAny = false
        
        -- 各モニター設定を取得して引用符で囲む
        for part in input:gsub("^displayplacer%s+", ""):gmatch("id:[^%s]+%s+[^i][^d]:.+?degree:[0-9]+") do
            result = result .. " \"" .. part .. "\""
            foundAny = true
        end
        
        if foundAny then
            if logger then logger("引用符なしコマンド修正: " .. result:sub(1, 50) .. "...") end
            return result
        end
    end
    
    -- そのまま返す
    if input:match("^displayplacer") then
        if logger then logger("そのまま返す: " .. input:sub(1, 50) .. "...") end
        return input
    end
    
    -- 何も見つからなかった場合
    if logger then logger("コマンド抽出失敗") end
    return ""
end

-- モニター設定を抽出する共通関数
function displayUtils.extractMonitorConfigs(cmd, logger)
    local monitors = {}
    -- 必要なパターンだけを抽出（引用符があってもなくても対応）
    
    -- 引用符を一時的に削除して処理しやすくする
    local cleanCmd = cmd:gsub("\"", ""):gsub("'", "")
    
    -- 各モニターの詳細情報を抽出
    for id, fullConfig in cleanCmd:gmatch("id:([^%s]+)%s+([^i][^d]:.+?degree:[0-9]+)") do
        -- 重要な位置情報だけを抽出
        local origin = fullConfig:match("origin:%(([^%)]+)%)")
        local resolution = fullConfig:match("res:([^%s]+)")
        local scaling = fullConfig:match("scaling:([^%s]+)")
        
        if origin then
            -- モニターIDをキーとして位置情報を保存
            monitors[id] = {
                origin = origin,
                resolution = resolution,
                scaling = scaling,
                -- 詳細設定も残す（必要に応じて）
                config = fullConfig
            }
            if logger then
                logger("モニター抽出: " .. id .. " 位置: " .. origin .. 
                      " 解像度: " .. (resolution or "不明") .. 
                      " スケーリング: " .. (scaling or "不明"))
            end
        end
    end
    
    return monitors
end

-- 全てのモニターが一致するか確認する関数
function displayUtils.allMonitorsMatch(currentMonitors, savedMonitors, logger)
    -- 両方のキー配列を取得
    local currentKeys = {}
    local savedKeys = {}
    
    for k, _ in pairs(currentMonitors) do
        table.insert(currentKeys, k)
    end
    
    for k, _ in pairs(savedMonitors) do
        table.insert(savedKeys, k)
    end
    
    -- キー数が異なる場合はfalse
    if #currentKeys ~= #savedKeys then
        if logger then 
            logger("モニター数が異なります: 現在=" .. #currentKeys .. " 保存済=" .. #savedKeys) 
        end
        return false
    end
    
    -- すべてのキーが存在するか確認
    for _, id in ipairs(currentKeys) do
        if not savedMonitors[id] then
            if logger then logger("保存済み構成にモニター " .. id .. " がありません") end
            return false
        end
    end
    
    for _, id in ipairs(savedKeys) do
        if not currentMonitors[id] then
            if logger then logger("現在の構成にモニター " .. id .. " がありません") end
            return false
        end
    end
    
    if logger then logger("すべてのモニターが一致しています") end
    return true
end

-- ディスプレイ設定が異なるか確認
function displayUtils.isLayoutDifferent(currentLayout, savedLayout, logger)
    -- デバッグのために完全なレイアウト情報を記録
    if logger then
        logger("現在のレイアウト: " .. currentLayout:sub(1, 150) .. "...")
        logger("保存済みレイアウト: " .. savedLayout:sub(1, 150) .. "...")
    end
    
    -- 保存されたレイアウトと現在のレイアウトからコマンドを抽出
    local savedCmd = displayUtils.extractDisplayplacerCommand(savedLayout, logger)
    if savedCmd == "" then
        if logger then logger("保存された構成からコマンドを抽出できません") end
        return true
    end
    
    local currentCmd = displayUtils.extractDisplayplacerCommand(currentLayout, logger)
    if currentCmd == "" then
        if logger then logger("現在の構成からコマンドを抽出できません") end
        return true
    end
    
    -- 完全一致チェック（デバッグ用）
    if savedCmd == currentCmd then
        if logger then logger("コマンド文字列が完全一致") end
    else
        if logger then logger("コマンド文字列が異なる") end
    end
    
    -- 両方のコマンドから各モニター設定を抽出して正規化
    local savedMonitors = displayUtils.extractMonitorConfigs(savedCmd, logger)
    local currentMonitors = displayUtils.extractMonitorConfigs(currentCmd, logger)
    
    -- モニター構成が変わっているか確認
    local isDifferent = false
    
    -- 1. saved設定に存在するが現在と異なる場合
    for id, info in pairs(savedMonitors) do
        if not currentMonitors[id] then
            if logger then logger("モニター " .. id .. " は現在接続されていない") end
            isDifferent = true
            break
        elseif currentMonitors[id].origin ~= info.origin then
            if logger then 
                logger("モニター " .. id .. " の位置が異なる: 保存=" .. info.origin .. 
                      " 現在=" .. (currentMonitors[id].origin or "なし"))
            end
            isDifferent = true
            break
        elseif currentMonitors[id].resolution ~= info.resolution then
            if logger then
                logger("モニター " .. id .. " の解像度が異なる: 保存=" .. (info.resolution or "不明") .. 
                       " 現在=" .. (currentMonitors[id].resolution or "不明"))
            end
            isDifferent = true
            break
        elseif currentMonitors[id].scaling ~= info.scaling then
            if logger then
                logger("モニター " .. id .. " のスケーリングが異なる: 保存=" .. (info.scaling or "不明") .. 
                       " 現在=" .. (currentMonitors[id].scaling or "不明"))
            end
            isDifferent = true
            break
        end
    end
    
    -- 2. current設定にあるが保存設定にないモニターがある場合
    if not isDifferent then
        for id, _ in pairs(currentMonitors) do
            if not savedMonitors[id] then
                if logger then logger("新しいモニター " .. id .. " が検出されました") end
                isDifferent = true
                break
            end
        end
    end
    
    -- 何らかの理由で判定できない場合のフォールバック
    if not isDifferent and #savedCmd > 20 and #currentCmd > 20 then
        -- 直接コマンド文字列を比較（緊急対策）
        if savedCmd ~= currentCmd then
            if logger then logger("直接比較でコマンドが異なる") end
            isDifferent = true
        end
    end
    
    if logger then logger("構成比較: " .. (isDifferent and "異なる" or "同じ")) end
    return isDifferent
end

-- 現在の画面構成取得
function displayUtils.getCurrentLayout(logger)
    -- キャッシュを強制的にクリア
    hs.screen.primaryScreen():currentMode() -- これは単なるダミー呼び出しでキャッシュを更新
    
    local cmd = "/opt/homebrew/bin/displayplacer list"
    local fullResult = hs.execute(cmd)
    if logger then logger("現在のレイアウト取得: " .. cmd .. "\n結果長さ: " .. #fullResult) end
    
    -- displayplacer list結果からコマンド行を抽出
    
    -- 方法1: "Execute the command below" の後ろを探す（最も確実）
    local executePattern = "Execute the command below.-\n\n(displayplacer[^\n]+)"
    local executeCmd = fullResult:match(executePattern)
    if executeCmd and executeCmd:match("\"id:[^\"]+") then
        if logger then logger("Execute後のコマンド抽出: " .. executeCmd:sub(1, 50) .. "...") end
        return executeCmd
    end
    
    -- 方法2: 行単位で "displayplacer" で始まって引用符が含まれる行を探す
    for line in fullResult:gmatch("[^\r\n]+") do
        if line:match("^displayplacer%s+\"id:[^\"]+") and not line:match("example") then
            if logger then logger("引用符付きコマンド行抽出: " .. line:sub(1, 50) .. "...") end
            return line
        end
    end
    
    -- 方法3: 一致する行が見つからなかった場合は、抽出関数を使用して整形
    for line in fullResult:gmatch("[^\r\n]+") do
        if line:match("^displayplacer%s+id:") and not line:match("example") then
            local extractedCmd = displayUtils.extractDisplayplacerCommand(line, logger)
            if extractedCmd and extractedCmd ~= "" then
                if logger then logger("抽出関数による整形: " .. extractedCmd:sub(1, 50) .. "...") end
                return extractedCmd
            end
        end
    end
    
    -- 方法4: 何も見つからなかった場合、現在の設定を構築
    if logger then logger("コマンド行が見つからないため、現在の設定を構築します") end
    local screens = hs.screen.allScreens()
    if #screens > 0 then
        local displayplacerCmd = "displayplacer"
        for _, screen in ipairs(screens) do
            local frame = screen:frame()
            local mode = screen:currentMode()
            local uuid = screen:getUUID()
            local scaling = "off"
            
            -- モード情報からスケーリングを推測
            if mode and mode.scale then
                scaling = mode.scale > 1 and "on" or "off"
            end
            
            -- hz情報の取得
            local hz = (mode and mode.freq) and mode.freq or 60
            
            -- 基本的な設定を構築
            local screenConfig = string.format(" \"id:%s res:%dx%d hz:%d color_depth:8 enabled:true scaling:%s origin:(%d,%d) degree:0\"",
                uuid, frame.w, frame.h, hz, scaling, frame.x, frame.y)
            
            displayplacerCmd = displayplacerCmd .. screenConfig
        end
        
        if logger then logger("構築したコマンド: " .. displayplacerCmd:sub(1, 50) .. "...") end
        return displayplacerCmd
    end
    
    -- 何も見つからなかった場合
    if logger then logger("コマンド抽出失敗、空を返す") end
    return ""
end

-- モニター情報を詳細に記録
function displayUtils.logScreenDetails(logger)
    local screens = hs.screen.allScreens()
    local log = "現在のモニター状況:\n"
    
    for i, screen in ipairs(screens) do
        local f = screen:frame()
        local mode = screen:currentMode()
        local name = screen:name() or "不明"
        local primary = (screen == hs.screen.primaryScreen()) and "プライマリ" or "セカンダリ"
        
        log = log .. string.format("モニター %d: %s (%s)\n", i, name, primary)
        log = log .. string.format("  UUID: %s\n", screen:getUUID())
        log = log .. string.format("  フレーム: x=%d, y=%d, w=%d, h=%d\n", f.x, f.y, f.w, f.h)
        
        if mode then
            log = log .. string.format("  解像度: %dx%d\n", mode.w, mode.h)
            if mode.scale then
                log = log .. string.format("  スケール: %s\n", mode.scale)
            end
            if mode.freq then
                log = log .. string.format("  リフレッシュレート: %d Hz\n", mode.freq)
            end
        end
    end
    
    if logger then logger(log) end
    return log
end

return displayUtils 