-- ディスプレイマネージャー用ユーティリティ関数

local displayUtils = {}

-- キャッシュされたdisplayplacerへのパス
local cachedDisplayplacerPath = nil

-- displayplacerへのパスを取得
function displayUtils.getDisplayplacerPath(logger)
    -- キャッシュされた値があれば返す
    if cachedDisplayplacerPath then
        return cachedDisplayplacerPath
    end
    
    -- 標準的なパス
    local standardPath = "/opt/homebrew/bin/displayplacer"
    
    -- whichコマンドで確認
    local check = io.popen("which displayplacer")
    local cmdPath = check:read("*a")
    check:close()
    
    if cmdPath and #cmdPath > 0 then
        cmdPath = cmdPath:gsub("%s+$", "")
        if logger then logger("displayplacerコマンドが見つかりました: " .. cmdPath) end
        cachedDisplayplacerPath = cmdPath
        return cmdPath
    end
    
    -- 標準パスが存在するか確認
    local f = io.open(standardPath, "r")
    if f then
        f:close()
        if logger then logger("標準パスでdisplayplacerが見つかりました: " .. standardPath) end
        cachedDisplayplacerPath = standardPath
        return standardPath
    end
    
    -- 代替パスをチェック
    local alternativePaths = {
        "/usr/local/bin/displayplacer",
        os.getenv("HOME") .. "/.local/bin/displayplacer"
    }
    
    for _, path in ipairs(alternativePaths) do
        local f = io.open(path, "r")
        if f then
            f:close()
            if logger then logger("代替パスでdisplayplacerが見つかりました: " .. path) end
            cachedDisplayplacerPath = path
            return path
        end
    end
    
    -- 見つからなかった場合、標準パスを返す
    if logger then logger("displayplacerが見つかりませんでした。デフォルトパスを返します: " .. standardPath) end
    return standardPath
end

-- 外部モニターUUIDキー生成
function displayUtils.getExternalKey(logger)
    local uuids = {}
    local screens = hs.screen.allScreens()
    local primary = hs.screen.primaryScreen()
    local primaryUUID = primary and primary:getUUID() or "不明"
    
    -- デバッグ情報: 全ディスプレイの情報収集
    local logInfo = "検出したディスプレイ情報:\n"
    logInfo = logInfo .. string.format("- プライマリー: %s (UUID: %s)\n", 
                                        primary and primary:name() or "不明", 
                                        primaryUUID)
    
    -- 外部モニター情報の収集
    local foundExternals = 0
    for i, s in ipairs(screens) do
        local uuid = s:getUUID()
        local name = s:name() or "不明"
        local isExternal = (s ~= primary)
        
        -- フレーム情報を追加
        local frame = s:frame()
        local frameInfo = string.format("x=%d,y=%d,w=%d,h=%d", frame.x, frame.y, frame.w, frame.h)
        
        -- モード情報を追加
        local mode = s:currentMode()
        local modeInfo = "不明"
        if mode then
            modeInfo = string.format("%dx%d", mode.w, mode.h)
            if mode.scale then
                modeInfo = modeInfo .. " scale:" .. mode.scale
            end
            if mode.freq then
                modeInfo = modeInfo .. " freq:" .. mode.freq
            end
        end
        
        logInfo = logInfo .. string.format("- ディスプレイ %d: %s (UUID: %s, 外部: %s, フレーム: %s, モード: %s)\n", 
                                           i, name, uuid, isExternal and "はい" or "いいえ", frameInfo, modeInfo)
        
        if isExternal then
            foundExternals = foundExternals + 1
            -- 名前とUUIDを組み合わせた安定キーのためのデータ
            -- できるだけ多くの情報を含めて一意性を高める
            table.insert(uuids, {
                uuid = uuid, 
                name = name, 
                idx = i,
                resolution = mode and string.format("%dx%d", mode.w, mode.h) or "unknown",
                refreshRate = mode and mode.freq or 60
            })
        end
    end
    
    -- 外部ディスプレイが見つかった場合の処理
    if #uuids > 0 then
        -- まず名前（製造元/モデル）でソート、次に解像度、最後にインデックスでソート
        table.sort(uuids, function(a, b)
            if a.name ~= b.name then
                return a.name < b.name
            end
            if a.resolution ~= b.resolution then
                return a.resolution < b.resolution
            end
            return a.idx < b.idx
        end)
        
        -- ソートした結果をログとキー生成に使用
        local sortedUuids = {}
        for i, item in ipairs(uuids) do
            logInfo = logInfo .. string.format("  > 外部モニター順序 %d: %s %s %dHz (UUID: %s)\n", 
                                              i, item.name, item.resolution, item.refreshRate, item.uuid)
            table.insert(sortedUuids, item.uuid)
        end
        
        -- 安定したキーを生成（UUIDのみ）
        local key = table.concat(sortedUuids, ",")
        logInfo = logInfo .. "生成されたキー: " .. key .. " (外部モニター " .. #sortedUuids .. "台)"
        
        -- ロギング関数があれば使用
        if logger then logger(logInfo) end
        
        return key
    else
        logInfo = logInfo .. "外部モニターは検出されませんでした"
        if logger then logger(logInfo) end
        return ""
    end
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
    
    -- 入力が短すぎる場合は無効と判断
    if #input < 20 then
        if logger then logger("入力が短すぎます: " .. input) end
        return ""
    end
    
    -- デバッグ情報
    if logger then logger("コマンド抽出処理開始: 入力長=" .. #input) end
    
    -- 一般的な誤りを修正
    input = input:gsub("/opt/homebrew/bin/displayplacerr", "/opt/homebrew/bin/displayplacer")
    input = input:gsub("displayplacerr", "displayplacer")
    
    -- まずは入力をそのまま使用（引用符がすでに付いているケース）
    if input:match("^displayplacer%s+\"id:[^\"]+") then
        if logger then logger("引用符付きdisplayplacerコマンド検出: " .. input:sub(1, 50) .. "...") end
        return input
    end
    
    -- 引用符付きパスを含むコマンド
    if input:match("^/opt/homebrew/bin/displayplacer%s+\"id:[^\"]+") then
        if logger then logger("パス付き引用符付きコマンド検出: " .. input:sub(1, 50) .. "...") end
        return input
    end
    
    -- Execute the command below の後の行を探す（最も正確）
    local executePattern = "Execute the command below.-\n\n(displayplacer[^\n]+)"
    local executeCmd = input:match(executePattern)
    if executeCmd then
        if logger then logger("Execute後のコマンド抽出: " .. executeCmd:sub(1, 50) .. "...") end
        -- 引用符チェックと追加
        if not executeCmd:match("\"id:[^\"]+") and executeCmd:match("id:[^%s]+") then
            executeCmd = displayUtils.addQuotesToDisplayplacerCommand(executeCmd, logger)
        end
        return executeCmd
    end
    
    -- 行単位で探す
    for line in input:gmatch("[^\r\n]+") do
        if (line:match("^displayplacer%s+") or line:match("^/opt/homebrew/bin/displayplacer%s+")) 
           and not line:match("example") and not line:match("degree:90") then
            if logger then logger("行単位抽出候補: " .. line:sub(1, 50) .. "...") end
            
            -- 引用符の確認
            if line:match("\"id:[^\"]+") then
                -- すでに引用符があるので、そのまま返す
                return line
            else
                -- 引用符がない場合は追加する
                return displayUtils.addQuotesToDisplayplacerCommand(line, logger)
            end
        end
    end
    
    -- 何も見つからなかった場合
    if logger then logger("コマンド抽出失敗") end
    return ""
end

-- displayplacerコマンドに引用符を追加する補助関数
function displayUtils.addQuotesToDisplayplacerCommand(cmd, logger)
    if logger then logger("引用符追加処理を開始: " .. cmd:sub(1, 50) .. "...") end
    
    -- displayplacerコマンドの完全パス
    local displayplacerCmd = displayUtils.getDisplayplacerPath(logger)
    
    -- コマンド部分（displayplacer）とオプション部分を分離
    local cmdPart = cmd:match("^(/opt/homebrew/bin/displayplacer)")
    if not cmdPart then
        cmdPart = cmd:match("^(displayplacer)")
    end
    
    if not cmdPart then
        if logger then logger("コマンド部分が見つかりません") end
        return cmd
    end
    
    -- displayplacerの標準パスに置き換え
    if cmdPart == "displayplacer" then
        cmdPart = displayplacerCmd
    end
    
    -- オプション部分を抽出
    local optionsPart = cmd:sub(#(cmd:match("^(/opt/homebrew/bin/displayplacer)") or cmd:match("^(displayplacer)") or "") + 1):gsub("^%s+", "")
    
    -- 結果コマンド
    local result = cmdPart
    local foundAny = false
    
    -- モニター設定部分を抽出して引用符で囲む
    for part in optionsPart:gmatch("id:[^%s]+%s+[^i][^d][^:]?.-degree:[0-9]+") do
        result = result .. " \"" .. part .. "\""
        foundAny = true
        if logger then logger("モニター設定を抽出: " .. part) end
    end
    
    if foundAny then
        if logger then logger("引用符追加結果: " .. result:sub(1, 50) .. "...") end
        return result
    end
    
    -- 別の抽出方法を試す
    result = cmdPart
    foundAny = false
    
    -- より緩いパターンで抽出
    for part in optionsPart:gmatch("id:[^%s]+.-degree:[0-9]+") do
        result = result .. " \"" .. part .. "\""
        foundAny = true
        if logger then logger("代替パターンで抽出: " .. part) end
    end
    
    if foundAny then
        if logger then logger("代替抽出結果: " .. result:sub(1, 50) .. "...") end
        return result
    end
    
    -- それでも抽出できない場合は、元のコマンドを返す
    if logger then logger("引用符追加失敗、元のコマンドを返します") end
    return cmd
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
    
    -- displayplacerコマンドの完全パス
    local displayplacerCmd = displayUtils.getDisplayplacerPath(logger)
    
    local cmd = displayplacerCmd .. " list"
    local fullResult = hs.execute(cmd)
    if logger then logger("現在のレイアウト取得: " .. cmd .. "\n結果長さ: " .. #fullResult) end
    
    -- displayplacer list結果からコマンド行を抽出
    
    -- 方法1: "Execute the command below" の後ろを探す（最も確実）
    local executePattern = "Execute the command below.-\n\n(displayplacer[^\n]+)"
    local executeCmd = fullResult:match(executePattern)
    if executeCmd and executeCmd:match("\"id:[^\"]+") then
        if logger then logger("Execute後のコマンド抽出: " .. executeCmd:sub(1, 50) .. "...") end
        -- 正規表現に一致したコマンドにパスを追加
        if executeCmd:match("^displayplacer%s+") and not executeCmd:match("^/") then
            executeCmd = displayplacerCmd .. executeCmd:sub(13)  -- "displayplacer"の部分を置き換え
            if logger then logger("完全パスを追加: " .. executeCmd:sub(1, 50) .. "...") end
        end
        return executeCmd
    end
    
    -- 方法2: 行単位で "displayplacer" で始まって引用符が含まれる行を探す
    for line in fullResult:gmatch("[^\r\n]+") do
        if line:match("^displayplacer%s+\"id:[^\"]+") and not line:match("example") then
            if logger then logger("引用符付きコマンド行抽出: " .. line:sub(1, 50) .. "...") end
            -- コマンドにパスを追加
            if line:match("^displayplacer%s+") and not line:match("^/") then
                line = displayplacerCmd .. line:sub(13)  -- "displayplacer"の部分を置き換え
                if logger then logger("完全パスを追加: " .. line:sub(1, 50) .. "...") end
            end
            return line
        end
    end
    
    -- 方法3: 一致する行が見つからなかった場合は、抽出関数を使用して整形
    for line in fullResult:gmatch("[^\r\n]+") do
        if line:match("^displayplacer%s+id:") and not line:match("example") then
            local extractedCmd = displayUtils.extractDisplayplacerCommand(line, logger)
            if extractedCmd and extractedCmd ~= "" then
                if logger then logger("抽出関数による整形: " .. extractedCmd:sub(1, 50) .. "...") end
                -- コマンドにパスを追加
                if extractedCmd:match("^displayplacer%s+") and not extractedCmd:match("^/") then
                    extractedCmd = displayplacerCmd .. extractedCmd:sub(13)  -- "displayplacer"の部分を置き換え
                    if logger then logger("完全パスを追加: " .. extractedCmd:sub(1, 50) .. "...") end
                end
                return extractedCmd
            end
        end
    end
    
    -- 方法4: 何も見つからなかった場合、現在の設定を構築
    if logger then logger("コマンド行が見つからないため、現在の設定を構築します") end
    local screens = hs.screen.allScreens()
    if #screens > 0 then
        local displayplacerCmdOnly = displayplacerCmd
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
            
            displayplacerCmdOnly = displayplacerCmdOnly .. screenConfig
        end
        
        if logger then logger("構築したコマンド: " .. displayplacerCmdOnly:sub(1, 50) .. "...") end
        return displayplacerCmdOnly
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