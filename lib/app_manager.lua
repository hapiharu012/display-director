-- Hammerspoonアプリマネージャー

local appManager = {}
local config = require("config")
local utils = require("lib.utils")
local logger = require("lib.logger").create(config.paths.apps .. "/display_manager/data/app_manager.log")

-- インストール済みアプリ一覧
appManager.installedApps = {}

-- アプリをURLからインストール
function appManager.installFromGit(url, options)
    options = options or {}
    local tmpDir = os.tmpname()
    os.remove(tmpDir) -- tmpnameは一時ファイルを作成するので削除
    
    -- アプリ名を取得 (URLから抽出)
    local appName = url:match("([^/]+)%.git$") or url:match("([^/]+)$")
    if not appName then
        logger("アプリ名を抽出できません: " .. url)
        return false, "アプリ名を抽出できません"
    end
    
    -- すでにインストールされているか確認
    if appManager.isInstalled(appName) and not options.force then
        logger("アプリはすでにインストールされています: " .. appName)
        return false, "アプリはすでにインストールされています"
    end
    
    -- gitでクローン
    logger("アプリをクローン中: " .. url)
    local cloneCmd = "git clone " .. url .. " " .. tmpDir
    local success, result = utils.executeCommand(cloneCmd, logger)
    
    if not success then
        logger("クローンに失敗しました: " .. result)
        return false, "クローンに失敗しました: " .. result
    end
    
    -- インストールスクリプトを実行
    local installCmd = "cd " .. tmpDir .. " && chmod +x install.sh && ./install.sh"
    success, result = utils.executeCommand(installCmd, logger)
    
    -- クリーンアップ
    utils.executeCommand("rm -rf " .. tmpDir, logger)
    
    if success then
        logger("アプリのインストールに成功しました: " .. appName)
        appManager.installedApps[appName] = {
            name = appName,
            url = url,
            installedAt = os.time()
        }
        return true, "インストール成功"
    else
        logger("インストールスクリプトの実行に失敗しました: " .. result)
        return false, "インストールに失敗しました: " .. result
    end
end

-- アプリが既にインストールされているか確認
function appManager.isInstalled(appName)
    -- config.luaでアプリが有効になっているか確認
    for _, name in ipairs(config.apps.enabled) do
        if name == appName then
            return true
        end
    end
    return false
end

-- インストール済みアプリ一覧を取得
function appManager.listInstalledApps()
    local apps = {}
    for _, appName in ipairs(config.apps.enabled) do
        local appPath = config.paths.apps .. "/" .. appName
        if utils.fileExists(appPath) then
            table.insert(apps, {
                name = appName,
                path = appPath
            })
        end
    end
    return apps
end

-- アプリをアンインストール
function appManager.uninstall(appName)
    if not appManager.isInstalled(appName) then
        logger("アプリはインストールされていません: " .. appName)
        return false, "アプリはインストールされていません"
    end
    
    -- アプリディレクトリを削除
    utils.executeCommand("rm -rf " .. config.paths.apps .. "/" .. appName, logger)
    
    -- 設定とデータディレクトリは、アプリ内に移動したため特別な処理は不要
    
    -- config.luaから削除
    -- この部分は複雑なので、手動での対応を推奨するメッセージを表示
    logger("アプリをアンインストールしました: " .. appName)
    logger("config.luaから " .. appName .. " を手動で削除してください")
    
    return true, "アンインストール成功（config.luaは手動で更新してください）"
end

-- ユーティリティ関数を追加
utils.fileExists = function(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

return appManager 