-- ディスプレイマネージャーのメインモジュール

local config = require("config")
local utils = require("lib.utils")
local logger = require("lib.logger").create(config.paths.hammerspoon .. "/display_log.txt")
local displayUtils = require("apps.display_manager.utils")

-- displayplacerコマンドへの完全パス
local displayplacerCmd = displayUtils.getDisplayplacerPath(logger)

-- アプリ固有の設定を読み込み
local settings = {}
local settingsPath = config.paths.apps .. "/display_manager/config/settings.lua"

local function loadSettings()
    local ok, s = pcall(dofile, settingsPath)
    if ok and type(s) == "table" then
        settings = s
        logger("設定ファイル読み込み成功: " .. settingsPath)
        return true
    else
        logger("設定ファイル読み込み失敗: " .. tostring(s))
        -- デフォルト設定
        settings = {autoSwitch = true}
        return false
    end
end

-- 設定を読み込み
loadSettings()

-- 保存済みレイアウトテーブル
local savedLayouts = {}
local savePath = config.paths.apps .. "/display_manager/data/saved_layouts.lua"

-- 設定ファイルを再読み込み
local function reloadSavedLayouts()
    logger("保存済みレイアウト再読み込み開始: " .. savePath)
    
    -- ファイルの存在確認を最初に行う
    if not utils.fileExists(savePath) then
        logger("ファイルが存在しません: " .. savePath)
        savedLayouts = {}
        return false
    end
    
    local ok, t
    -- 安全にファイルを読み込む
    local f = io.open(savePath, "r")
    if f then
        local content = f:read("*all")
        f:close()
        logger("ファイル内容読み込み: " .. #content .. " バイト")
        
        -- luaの関数としてコンテンツをロードして実行
        local loadFunc, loadErr = load("return " .. content)
        if loadFunc then
            ok, t = pcall(loadFunc)
        else
            logger("ファイル構文エラー: " .. tostring(loadErr))
            ok = false
        end
    else
        logger("ファイルを開けませんでした: " .. savePath)
        ok = false
    end
    
    -- 標準的な方法でdofileを試す（フォールバック）
    if not ok or not t then
        ok, t = pcall(dofile, savePath)
    end
    
    if ok and type(t) == "table" then
        savedLayouts = t
        logger("設定ファイル再読み込み成功: " .. savePath)
        
        -- デバッグ: 読み込まれたレイアウト情報を表示
        local count = 0
        for k, v in pairs(savedLayouts) do
            count = count + 1
            logger("読み込まれたレイアウト [" .. count .. "]: キー=" .. k .. ", 長さ=" .. #v)
        end
        logger("合計 " .. count .. " 個のレイアウトを読み込みました")
        
        return true
    else
        logger("設定ファイル再読み込み失敗: " .. tostring(t))
        
        -- ファイル内容をデバッグ用に表示
        local f = io.open(savePath, "r")
        if f then
            local content = f:read("*all")
            f:close()
            logger("ファイル内容 (最初の200バイト): " .. content:sub(1, 200))
        end
        
        savedLayouts = {}
        return false
    end
end

-- 保存データをファイルへ
local function persist()
    -- 保存ディレクトリが存在することを確認
    utils.executeCommand("mkdir -p " .. config.paths.apps .. "/display_manager/data", logger)
    
    local f = io.open(savePath, "w")
    f:write("return {\n")
    for k, v in pairs(savedLayouts) do
        f:write(string.format("  [%q] = %q,\n", k, v))
        logger("保存するレイアウト: キー=" .. k .. ", 長さ=" .. #v)
    end
    f:write("}\n")
    f:close()
    logger("設定をファイルに保存しました: " .. savePath)
    
    -- 保存後にファイルの存在と権限を確認
    if utils.fileExists(savePath) then
        local fileInfo = hs.execute("ls -la " .. savePath)
        logger("保存したファイル情報: " .. fileInfo)
    else
        logger("警告：保存後もファイルが見つかりません: " .. savePath)
    end
end

-- レイアウト適用ロジック
local function updateDisplayLayout(forceMode)
    -- エラーをキャッチして確実にログを残す
    local status, err = pcall(function()
        logger("updateDisplayLayout開始: forceMode=" .. tostring(forceMode))
        
        -- 強制モードでない場合は自動切り替え設定を確認
        if not forceMode and not settings.autoSwitch then
            logger("自動切り替えが無効なため終了")
            return
        end
        
        -- displayplacerコマンドが実行可能か確認
        local check = io.popen("which " .. displayplacerCmd)
        local cmdPath = check:read("*a")
        check:close()
        
        if cmdPath and #cmdPath > 0 then
            logger("displayplacerコマンドが見つかりました: " .. cmdPath:gsub("%s+$", ""))
        else
            logger("エラー: displayplacerコマンドが見つかりません")
            local alternativePaths = {
                "/usr/local/bin/displayplacer",
                os.getenv("HOME") .. "/.local/bin/displayplacer",
                "/opt/homebrew/bin/displayplacer"
            }
            
            -- 代替パスをチェック
            for _, path in ipairs(alternativePaths) do
                if utils.fileExists(path) then
                    logger("代替パスが見つかりました: " .. path)
                    displayplacerCmd = path
                    break
                end
            end
            
            -- それでも見つからない場合は警告を表示
            if not utils.fileExists(displayplacerCmd) then
                logger("警告: displayplacerが見つかりません。インストールされているか確認してください。")
                logger("Homebrewでインストール: brew install displayplacer")
                hs.alert.show("displayplacerが見つかりません。インストールしてください。")
                return
            end
        end
        
        reloadSavedLayouts()
        displayUtils.logScreenDetails(logger)
        local key = displayUtils.getExternalKey(logger)
        logger("現在の外部モニター構成キー: " .. key)
        
        if key ~= "" and savedLayouts[key] then
            logger("保存済みレイアウト発見: " .. key)
            logger("レイアウトデータ長さ: " .. #savedLayouts[key])
            if forceMode or settings.autoSwitch then
                local cmd = displayUtils.extractDisplayplacerCommand(savedLayouts[key], logger)
                if cmd == "" then
                    logger("有効なdisplayplacerコマンドが見つかりませんでした")
                    hs.alert.show("エラー: 有効なdisplayplacerコマンドが見つかりません")
                    return
                end
                
                -- パスが含まれていない場合は追加
                if cmd:match("^displayplacer%s+") and not cmd:match("^/") then
                    cmd = displayplacerCmd .. cmd:sub(13)  -- "displayplacer"の部分を置き換え
                    logger("完全パスを追加: " .. cmd)
                elseif not cmd:match("^/") then
                    cmd = displayplacerCmd .. " " .. cmd
                    logger("パスを先頭に追加: " .. cmd)
                end
                
                logger("実行するコマンド: " .. cmd)
                
                -- コマンド実行前に権限確認
                if not utils.fileExists(displayplacerCmd) then
                    logger("エラー: " .. displayplacerCmd .. " が存在しません")
                    hs.alert.show("エラー: displayplacerが見つかりません")
                    return
                end
                
                -- 実行権限の確認
                local execCheck = io.popen("ls -l " .. displayplacerCmd)
                local execInfo = execCheck:read("*a")
                execCheck:close()
                logger("displayplacer実行情報: " .. execInfo)
                
                -- コマンド実行（詳細なログ付き）
                local success, result, code = utils.executeCommand(cmd, logger)
                
                if success then
                    logger("コマンド実行成功: " .. tostring(result))
                    hs.alert.show("ディスプレイレイアウトを適用しました")
                else
                    logger("コマンド実行失敗 - コード: " .. tostring(code) .. ", 結果: " .. tostring(result))
                    -- 失敗時の代替コマンドを試行
                    local altCmd = "osascript -e 'tell application \"Hammerspoon\" to display dialog \"displayplacerコマンドの実行に失敗しました。\" buttons {\"OK\"} with icon caution'"
                    os.execute(altCmd)
                    hs.alert.show("エラー: レイアウト適用に失敗しました")
                end
            end
        else
            logger("保存済みレイアウトが見つかりません: " .. key)
            
            -- 保存済みレイアウトがない場合、デフォルトレイアウトを適用
            if forceMode or settings.autoSwitch then
                -- 全てのディスプレイを取得
                local screens = hs.screen.allScreens()
                local mac = hs.screen.primaryScreen()
                
                -- 外部モニターを取得
                local external = {}
                for _, s in ipairs(screens) do
                    if s ~= mac then
                        table.insert(external, s)
                    end
                end
                
                local cmd = ""
                
                -- 外部モニターの数に応じて配置
                if #external == 1 then
                    -- 外部モニター1枚の場合: Macの真上に外部モニターの底辺の真ん中が来るように
                    local e = external[1]
                    local f = e:frame()
                    local m = mac:frame()
                    
                    -- Macの中央X座標
                    local macCenterX = m.x + m.w / 2
                    
                    -- 外部モニターの左端X座標 (モニターの中央をMacの中央に合わせる)
                    local extOriginX = math.floor(macCenterX - f.w / 2)
                    
                    -- 外部モニターのY座標 (底辺をMacの上端に合わせる)
                    local extOriginY = -f.h
                    
                    cmd = string.format(
                        "%s " ..
                        "'id:%s origin:(%d,%d)' " ..  -- 外部モニター
                        "'id:%s origin:(%d,%d)'",     -- MacBook
                        displayplacerCmd,
                        e:getUUID(), extOriginX, extOriginY,
                        mac:getUUID(), 0, 0
                    )
                    
                    hs.alert.show("シングルモニター構成：Macの上に外部モニター配置")
                elseif #external == 2 then
                    local e1, e2 = external[1], external[2]
                    local f1, f2 = e1:frame(), e2:frame()
                    local m = mac:frame()
                    
                    -- Macの中央X座標
                    local macCenterX = m.x + m.w / 2
                    
                    -- １枚目の右端（＝つなぎ目）をMacの中央に合わせる
                    local ext1OriginX = math.floor(macCenterX - f1.w)
                    local ext2OriginX = ext1OriginX + f1.w  -- つなぎ目位置
                    
                    -- 下端を揃える（Y方向は各モニター高をマイナス）
                    local ext1OriginY = -f1.h
                    local ext2OriginY = -f2.h
                    
                    cmd = string.format(
                        "%s " ..
                        "'id:%s origin:(%d,%d)' " ..  -- 外部モニター1
                        "'id:%s origin:(%d,%d)' " ..  -- 外部モニター2
                        "'id:%s origin:(%d,%d)'",     -- MacBook
                        displayplacerCmd,
                        e1:getUUID(), ext1OriginX, ext1OriginY,
                        e2:getUUID(), ext2OriginX, ext2OriginY,
                        mac:getUUID(), 0, 0
                    )
                    
                    hs.alert.show("３画面構成：上段２枚のつなぎ目をMac中央に")
                else
                    if forceMode then
                        hs.alert.show("この構成用のデフォルトレイアウトがありません")
                    end
                    logger("デフォルトレイアウトが設定されていない構成: 外部モニター " .. #external .. "枚")
                    return
                end
                
                if cmd ~= "" then
                    logger("デフォルトレイアウト適用: " .. cmd)
                    utils.executeCommand(cmd, logger)
                end
            end
        end
    end)
    
    -- エラーがあればログに記録
    if not status then
        logger("updateDisplayLayout実行中にエラーが発生: " .. tostring(err))
        hs.alert.show("エラー: レイアウト適用処理中にエラーが発生しました")
    end
end

-- レイアウト保存コマンド
local function saveLayout()
    local key = displayUtils.getExternalKey(logger)
    logger("レイアウト保存: モニター構成キー = " .. key)
    
    if key == "" then
        hs.alert.show("外部モニターが見つかりません")
        logger("外部モニターが見つからないため保存できません")
        return
    end
    
    -- 現在の構成を取得
    local layout = displayUtils.getCurrentLayout(logger)
    logger("取得したレイアウトデータ長さ: " .. #layout)
    
    -- レイアウトが有効か確認
    if layout == "" then
        hs.alert.show("有効なレイアウトデータが取得できませんでした")
        logger("有効なレイアウトデータがないため保存できません")
        return
    end
    
    -- コマンドパス修正（スペルミスなどの防止）
    if layout:match("/opt/homebrew/bin/displayplacerr") then
        layout = layout:gsub("/opt/homebrew/bin/displayplacerr", "/opt/homebrew/bin/displayplacer")
        logger("コマンドパス修正: displayplacerr -> displayplacer")
    end
    
    -- 保存前の検証
    local testCmd = displayUtils.extractDisplayplacerCommand(layout, logger)
    if testCmd == "" then
        hs.alert.show("エラー: 無効なレイアウトデータです")
        logger("検証エラー: 抽出されたコマンドが空")
        return
    end
    
    -- 保存
    savedLayouts[key] = layout
    persist()
    
    hs.alert.show("レイアウトを保存しました")
    logger("レイアウト保存完了: キー = " .. key)
end

-- レイアウト削除コマンド
local function deleteLayout()
    local key = displayUtils.getExternalKey(logger)
    logger("レイアウト削除: モニター構成キー = " .. key)
    
    if key == "" then
        hs.alert.show("外部モニターが見つかりません")
        logger("外部モニターが見つからないため削除できません")
        return
    end
    
    if savedLayouts[key] then
        -- 削除前に確認
        hs.alert.show("レイアウト削除中...", 1)
        
        -- 削除実行
        savedLayouts[key] = nil
        persist()
        
        hs.alert.show("レイアウトを削除しました")
        logger("レイアウト削除完了: キー = " .. key)
    else
        hs.alert.show("削除する保存済みレイアウトがありません")
        logger("保存済みレイアウトが見つかりません: " .. key)
    end
end

-- 自動切り替え切り替え
local function toggleAutoSwitch()
    settings.autoSwitch = not settings.autoSwitch
    logger("自動切り替え状態変更: " .. (settings.autoSwitch and "ON" or "OFF"))
    hs.alert.show("AutoSwitch: " .. (settings.autoSwitch and "ON" or "OFF"))
end

-- ヘルプと使い方の表示
local function showHelp()
    local helpText = [[
ディスプレイマネージャー 使い方ガイド

■ ショートカットキー
⌃⌥⌘S = 現在の画面レイアウトを保存
⌃⌥⌘R または ⌃⌥⌘Return = 保存したレイアウトを適用
⌃⌥⌘X = 現在の構成のレイアウトを削除
⌃⌥⌘D = 自動切り替え ON/OFF
⌃⌥⌘I = 現在の画面構成情報を表示
⌃⌥⌘H = このヘルプを表示

■ 代替方法
1. メニューバーの📺アイコンから操作
2. Hammerspoonコンソールから「_G.applyDisplayLayout()」を実行
3. Returnキーが使えない場合はRキーを使用

■ 使い方
1. モニターを希望の配置に手動で設定
2. ⌃⌥⌘S で現在のレイアウトを保存
3. 次回同じモニター構成を検出したら自動適用

■ 注意点
・モニターは名前とUUIDで識別されます
・自動切り替えが有効な場合のみ自動適用
・問題が発生した場合はログを確認：
  ~/.hammerspoon/display_log.txt
]]

    hs.dialog.alert(0, 0, "ディスプレイマネージャー ヘルプ", helpText, "閉じる")
    logger("ヘルプを表示しました")
end

-- 現在の画面状態を表示
local function showCurrentLayout()
    local screens = hs.screen.allScreens()
    local info = "現在の画面構成:\n"
    info = info .. "画面数: " .. #screens .. "台\n\n"
    
    for i, screen in ipairs(screens) do
        local f = screen:frame()
        local name = screen:name() or "不明"
        local primary = (screen == hs.screen.primaryScreen()) and "プライマリ" or "セカンダリ"
        local resolution = ""
        
        local mode = screen:currentMode()
        if mode then
            resolution = mode.w .. "x" .. mode.h
            if mode.freq then
                resolution = resolution .. " " .. mode.freq .. "Hz"
            end
        end
        
        info = info .. i .. ": " .. name .. " (" .. primary .. ")\n"
        info = info .. "   位置: (" .. f.x .. "," .. f.y .. ") サイズ: " .. f.w .. "x" .. f.h .. "\n"
        info = info .. "   解像度: " .. resolution .. "\n"
    end
    
    -- 保存済みレイアウト情報
    local key = displayUtils.getExternalKey(logger)
    info = info .. "\n現在の構成キー: " .. key .. "\n"
    
    if key ~= "" and savedLayouts[key] then
        info = info .. "この構成用の保存済みレイアウトがあります"
    else
        info = info .. "この構成用の保存済みレイアウトはありません"
    end
    
    hs.dialog.alert(0, 0, "画面情報", info, "OK")
    logger("画面情報を表示: " .. info)
end

-- ホットキー設定
hs.hotkey.bind({"ctrl","alt","cmd"}, "S", saveLayout)
hs.hotkey.bind({"ctrl","alt","cmd"}, "D", toggleAutoSwitch)
hs.hotkey.bind({"ctrl","alt","cmd"}, "X", deleteLayout)
hs.hotkey.bind({"ctrl","alt","cmd"}, "I", showCurrentLayout)  -- 情報表示用
hs.hotkey.bind({"ctrl","alt","cmd"}, "H", showHelp)  -- ヘルプ表示

-- Returnキーに関する問題を根本的に解決
-- 既存のReturnキーバインディングはすべて解除
local existingReturnHotkeys = {}
for _, hotkey in ipairs(hs.hotkey.getHotkeys()) do
    local mods = hotkey.idx:match("^(.+):return$")
    if mods and mods:match("cmd") and mods:match("alt") and mods:match("ctrl") then
        table.insert(existingReturnHotkeys, hotkey)
        logger("既存のreturnホットキーを検出: " .. hotkey.idx)
    end
end

-- 既存のホットキーを解除
for _, hotkey in ipairs(existingReturnHotkeys) do
    hotkey:delete()
    logger("既存のreturnホットキーを解除: " .. hotkey.idx)
end

-- 問題のあるホットキー設定を以下のシンプルなバージョンに置き換え
-- returnキーは単純に文字列指定（最も確実な方法）
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "return", function()
    logger("ホットキー実行: Ctrl+Alt+Cmd+Return")
    updateDisplayLayout(true)
    hs.alert.show("ディスプレイレイアウトを強制適用しました (Return)")
end)

-- 最も確実な代替方法として「R」キーを追加（これは確実に動作する）
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "R", function()
    logger("ホットキー実行: Ctrl+Alt+Cmd+R (確実な代替)")
    updateDisplayLayout(true)
    hs.alert.show("ディスプレイレイアウトを強制適用しました (R)")
end)

-- メニューからの呼び出しとグローバル関数も用意
_G.applyDisplayLayout = function()
    logger("グローバル関数applyDisplayLayoutから呼び出し")
    updateDisplayLayout(true)
end

-- ホットキー以外の方法も提供（メニューバー）
local menubar = hs.menubar.new()
if menubar then
    menubar:setTitle("📺")
    
    menubar:setMenu(function()
        -- 現在の構成に保存済みレイアウトがあるかを確認
        local key = displayUtils.getExternalKey(logger)
        local hasLayout = (key ~= "" and savedLayouts[key]) and true or false
        
        local menu = {
            { title = "モニターレイアウト保存（⌃⌥⌘S）", fn = saveLayout },
            { title = hasLayout and "モニターレイアウト適用（⌃⌥⌘R/Return）" or "モニターレイアウト適用（未保存）", 
              fn = function() updateDisplayLayout(true) end, 
              disabled = not hasLayout },
            { title = hasLayout and "モニターレイアウト削除（⌃⌥⌘X）" or "モニターレイアウト削除（未保存）", 
              fn = deleteLayout, 
              disabled = not hasLayout },
            { title = "-" },
            { title = "画面構成情報を表示（⌃⌥⌘I）", fn = showCurrentLayout },
            { title = "-" },
            { title = "自動切替: " .. (settings.autoSwitch and "ON ✓" or "OFF"), fn = toggleAutoSwitch },
            { title = "-" },
            { title = "ヘルプを表示（⌃⌥⌘H）", fn = showHelp },
            { title = "Hammerspoonリロード", fn = hs.reload }
        }
        return menu
    end)

    logger("ディスプレイマネージャーのメニューバーアイコンを設定しました")
end

-- 初期化
reloadSavedLayouts()

-- 保存済みレイアウトを検証・修復
local needsRepair = false
for key, layout in pairs(savedLayouts) do
    -- スペルミスなどの一般的な問題を修正
    if layout:match("displayplacerr") then
        savedLayouts[key] = layout:gsub("displayplacerr", "displayplacer")
        logger("レイアウト修復: displayplacerr -> displayplacer (キー: " .. key .. ")")
        needsRepair = true
    end
    
    -- 他の潜在的な問題をチェック
    local testCmd = displayUtils.extractDisplayplacerCommand(savedLayouts[key], logger)
    if testCmd == "" then
        logger("警告: キー " .. key .. " のレイアウトデータが無効です")
    end
end

-- 修復が必要な場合、ファイルを更新
if needsRepair then
    logger("保存済みレイアウトファイルの修復を実行します")
    persist()
end

updateDisplayLayout(true)

return {
    updateDisplayLayout = updateDisplayLayout,
    saveLayout = saveLayout,
    toggleAutoSwitch = toggleAutoSwitch,
    deleteLayout = deleteLayout,
    showCurrentLayout = showCurrentLayout,
    showHelp = showHelp
} 