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

-- 自動切り替え切り替え
local function toggleAutoSwitch()
    settings.autoSwitch = not settings.autoSwitch
    logger("自動切り替え状態変更: " .. (settings.autoSwitch and "ON" or "OFF"))
    hs.alert.show("AutoSwitch: " .. (settings.autoSwitch and "ON" or "OFF"))
end

-- ホットキー設定
hs.hotkey.bind({"ctrl","alt","cmd"}, "S", saveLayout)
hs.hotkey.bind({"ctrl","alt","cmd"}, "D", toggleAutoSwitch)

-- Returnキーに関する問題を解決するために複数の代替バインディングを提供
-- Returnキーのバリエーション（各環境で異なる名前で認識される可能性がある）
local returnKeys = {"return", "Return", "⏎", "↩", "⌤", "⏎", "↵", "⎆", "⎘"}

-- すべてのReturnキーのバリエーションにバインドを試みる
for _, key in ipairs(returnKeys) do
    local ok, err = pcall(function()
        hs.hotkey.bind({"ctrl","alt","cmd"}, key, function()
            logger("ホットキー実行: Ctrl+Alt+Cmd+" .. key)
            updateDisplayLayout(true)
            hs.alert.show("ディスプレイレイアウトを強制適用しました")
        end)
    end)
    
    if not ok then
        logger("Return代替キー " .. key .. " のバインドに失敗: " .. tostring(err))
    else
        logger("Return代替キー " .. key .. " をバインドしました")
    end
end

-- 最も確実なRキーを追加
hs.hotkey.bind({"ctrl","alt","cmd"}, "R", function() 
    logger("ホットキー実行: Ctrl+Alt+Cmd+R（Returnの確実な代替）")
    updateDisplayLayout(true) 
    hs.alert.show("ディスプレイレイアウトを強制適用しました（R）") 
end)

-- ホットキー以外の方法も提供（メニューバー）
local menubar = hs.menubar.new()
if menubar then
    menubar:setTitle("📺")
    
    menubar:setMenu(function()
        local menu = {
            { title = "モニターレイアウト保存（⌃⌥⌘S）", fn = saveLayout },
            { title = "モニターレイアウト適用（⌃⌥⌘R）", fn = function() updateDisplayLayout(true) end },
            { title = "-" },
            { title = "自動切替: " .. (settings.autoSwitch and "ON" or "OFF"), fn = toggleAutoSwitch },
            { title = "-" },
            { title = "Hammerspoonリロード", fn = hs.reload }
        }
        return menu
    end)

    logger("ディスプレイマネージャーのメニューバーアイコンを設定しました")
end

-- グローバル関数に登録（コンソールからデバッグ呼び出しできるように）
_G.displayManagerApply = function()
    logger("グローバル関数から呼び出し")
    updateDisplayLayout(true)
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
    toggleAutoSwitch = toggleAutoSwitch
} 