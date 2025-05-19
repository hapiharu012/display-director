-- Hammerspoon 起動スクリプト

-- パッケージパスの設定（モジュール読み込みのため）
package.path = package.path .. 
               ";/Users/morishige/.hammerspoon/?.lua" .. 
               ";/Users/morishige/.hammerspoon/?/init.lua" ..
               ";/Users/morishige/.hammerspoon/apps/?.lua" ..
               ";/Users/morishige/.hammerspoon/apps/?/init.lua" ..
               ";/Users/morishige/.hammerspoon/lib/?.lua"

local config = require("config")
local utils = require("lib.utils")
local logger = require("lib.logger").create(config.paths.hammerspoon .. "/display_log.txt")
local appManager = require("lib.app_manager")

-- 変数初期化
local loadedApps = {}

-- コマンドラインインターフェース
local cli = {}

-- アプリのインストール
cli.installApp = function(url)
    local success, message = appManager.installFromGit(url)
    if success then
        hs.alert.show("アプリがインストールされました。Hammerspoonをリロードしてください。")
    else
        hs.alert.show("インストール失敗: " .. message)
    end
end

-- アプリのアンインストール
cli.uninstallApp = function(appName)
    local success, message = appManager.uninstall(appName)
    if success then
        hs.alert.show("アプリがアンインストールされました: " .. appName)
    else
        hs.alert.show("アンインストール失敗: " .. message)
    end
end

-- インストール済みアプリ一覧表示
cli.listApps = function()
    local apps = appManager.listInstalledApps()
    local message = "インストール済みアプリ:\n"
    for _, app in ipairs(apps) do
        message = message .. "- " .. app.name .. "\n"
    end
    hs.alert.show(message)
end

-- CLIの実行（開発用）
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "I", function()
    local button, url = hs.dialog.textPrompt(
        "アプリインストール", 
        "GitリポジトリのURLを入力:", 
        "https://github.com/yourusername/hammerspoon-display-manager.git", 
        "インストール", 
        "キャンセル"
    )
    
    if button == "インストール" then
        cli.installApp(url)
    end
end)

-- 有効なアプリケーションをロード
for _, appName in ipairs(config.apps.enabled) do
    -- '/'を'.'に置き換えてLuaのモジュールパス形式に変換
    local moduleKey = "apps." .. appName .. ".layout"
    logger("アプリケーション " .. appName .. " のロードを試行します")
    logger("モジュールパス: " .. moduleKey)
    logger("現在のパッケージパス: " .. package.path)
    
    local app = utils.loadModule(moduleKey)
    
    if app and app.updateDisplayLayout then
        logger("アプリケーションロード成功: " .. appName)
        app.updateDisplayLayout(true)
        loadedApps[appName] = app
    else
        logger("アプリケーションロード失敗: " .. appName)
        logger("  試行したモジュールパス: " .. moduleKey)
        
        -- 直接ファイルの存在を確認
        local filePath = config.paths.apps .. "/" .. appName .. "/layout.lua"
        if utils.fileExists(filePath) then
            logger("ファイルは存在するがロードできません: " .. filePath)
            
            -- 直接ロードを試みる
            local ok, mod = pcall(dofile, filePath)
            if ok and type(mod) == "table" and mod.updateDisplayLayout then
                logger("直接dofileでロード成功: " .. filePath)
                loadedApps[appName] = mod
                mod.updateDisplayLayout(true)
            else
                logger("直接dofileでもロード失敗: " .. tostring(mod))
            end
        else
            logger("ファイルが存在しません: " .. filePath)
        end
    end
end

-- ディスプレイ変更を監視
hs.screen.watcher.new(function()
    logger("画面変更検出")
    
    -- デバッグ: 現在の画面情報を記録
    local screens = hs.screen.allScreens()
    local screenInfo = "現在接続されている画面: " .. #screens .. "台\n"
    
    for i, screen in ipairs(screens) do
        local name = screen:name() or "不明"
        local uuid = screen:getUUID()
        local isPrimary = (screen == hs.screen.primaryScreen())
        screenInfo = screenInfo .. string.format("  %d: %s (UUID: %s, Primary: %s)\n", 
                                                i, name, uuid, tostring(isPrimary))
    end
    
    logger(screenInfo)
    
    for appName, app in pairs(loadedApps) do
        if app.updateDisplayLayout then
            logger("アプリによるレイアウト適用試行: " .. appName)
            app.updateDisplayLayout(false)
        end
    end
end):start()

-- アプリ読み込み完了メッセージ
local loadedAppsList = ""
for appName, _ in pairs(loadedApps) do
    if loadedAppsList ~= "" then
        loadedAppsList = loadedAppsList .. ", "
    end
    loadedAppsList = loadedAppsList .. appName
    
    -- デバッグ: アプリの中身を確認
    logger("ロードされたアプリの内容確認: " .. appName)
    for k, v in pairs(loadedApps[appName]) do
        logger("  - " .. k .. ": " .. tostring(v))
    end
end

-- デバッグ: loadedAppsテーブルの内容を表示
logger("loadedAppsテーブルのキー数: " .. utils.countTableKeys(loadedApps))
logger("config.apps.enabled数: " .. #config.apps.enabled)

hs.alert.show("Hammerspoon 起動完了. 読み込まれたアプリ: " .. (loadedAppsList ~= "" and loadedAppsList or "なし"))

