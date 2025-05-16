-- ディスプレイマネージャーのメインモジュール

local config = require("config")
local utils = require("lib.utils")
local logger = require("lib.logger").create(config.paths.hammerspoon .. "/display_log.txt")
local displayUtils = require("apps.display_manager.utils")

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
    local ok, t = pcall(dofile, savePath)
    if ok and type(t) == "table" then
        savedLayouts = t
        logger("設定ファイル再読み込み成功: " .. savePath)
        return true
    else
        logger("設定ファイル再読み込み失敗: " .. tostring(t))
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
        logger("保存するレイアウト: " .. k)
    end
    f:write("}\n")
    f:close()
    logger("設定をファイルに保存しました: " .. savePath)
end

-- レイアウト適用ロジック
local function updateDisplayLayout(forceMode)
    logger("updateDisplayLayout開始: forceMode=" .. tostring(forceMode))
    
    -- 強制モードでない場合は自動切り替え設定を確認
    if not forceMode and not settings.autoSwitch then
        logger("自動切り替えが無効なため終了")
        return
    end
    
    reloadSavedLayouts()
    displayUtils.logScreenDetails(logger)
    local key = displayUtils.getExternalKey()
    if savedLayouts[key] then
        logger("保存済みレイアウト発見: " .. key)
        if forceMode or settings.autoSwitch then
            local cmd = displayUtils.extractDisplayplacerCommand(savedLayouts[key], logger)
            if cmd == "" then
                logger("有効なdisplayplacerコマンドが見つかりませんでした")
                return
            end
            utils.executeCommand(cmd, logger)
            hs.alert.show("ディスプレイレイアウトを適用しました")
        end
    else
        logger("保存済みレイアウトが見つかりません: " .. key)
        if forceMode then
            hs.alert.show("このモニター構成の保存レイアウトが見つかりません")
        end
    end
end

-- レイアウト保存コマンド
local function saveLayout()
    local key = displayUtils.getExternalKey()
    if key == "" then
        hs.alert.show("外部モニターが見つかりません")
        return
    end
    
    -- 現在の構成を取得
    local layout = displayUtils.getCurrentLayout(logger)
    
    -- 保存
    savedLayouts[key] = layout
    persist()
    
    hs.alert.show("レイアウトを保存しました")
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
hs.hotkey.bind({"ctrl","alt","cmd"}, "return", function() updateDisplayLayout(true) end)

-- 初期化
reloadSavedLayouts()
updateDisplayLayout(true)

return {
    updateDisplayLayout = updateDisplayLayout,
    saveLayout = saveLayout,
    toggleAutoSwitch = toggleAutoSwitch
} 