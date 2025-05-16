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
    
    -- アプリのディレクトリパス
    local appDir = config.paths.apps .. "/" .. appName
    
    -- gitでクローン
    logger("アプリをクローン中: " .. url)
    
    -- サブモジュールとしてインストールする場合
    if options.useSubmodule then
        -- 一時的にダウンロード
        local cloneCmd = "git clone " .. url .. " " .. tmpDir
        local success, result = utils.executeCommand(cloneCmd, logger)
        
        if not success then
            logger("クローンに失敗しました: " .. result)
            return false, "クローンに失敗しました: " .. result
        end
        
        -- サブモジュールとして追加
        local addSubmoduleCmd = "cd " .. config.paths.hammerspoon .. " && git submodule add " .. url .. " " .. appDir
        success, result = utils.executeCommand(addSubmoduleCmd, logger)
        
        -- クリーンアップ
        utils.executeCommand("rm -rf " .. tmpDir, logger)
        
        if not success then
            logger("サブモジュールの追加に失敗しました: " .. result)
            return false, "サブモジュールの追加に失敗しました: " .. result
        end
    else
        -- 通常のクローン
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
        
        if not success then
            logger("インストールスクリプトの実行に失敗しました: " .. result)
            return false, "インストールに失敗しました: " .. result
        end
    end
    
    logger("アプリのインストールに成功しました: " .. appName)
    appManager.installedApps[appName] = {
        name = appName,
        url = url,
        installedAt = os.time(),
        isSubmodule = options.useSubmodule or false
    }
    
    return true, "インストール成功"
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
            -- package.jsonからバージョン情報等を取得
            local packagePath = appPath .. "/package.json"
            local packageInfo = {}
            
            if utils.fileExists(packagePath) then
                local f = io.open(packagePath, "r")
                if f then
                    local content = f:read("*all")
                    f:close()
                    
                    local success, info = pcall(function() return hs.json.decode(content) end)
                    if success then
                        packageInfo = info
                    end
                end
            end
            
            table.insert(apps, {
                name = appName,
                path = appPath,
                version = packageInfo.version or "不明",
                description = packageInfo.description or ""
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
    
    local appInfo = appManager.installedApps[appName]
    local isSubmodule = appInfo and appInfo.isSubmodule
    
    if isSubmodule then
        -- サブモジュールとして管理されている場合
        local cmd = "cd " .. config.paths.hammerspoon .. " && git submodule deinit -f -- apps/" .. appName .. 
                   " && git rm -f apps/" .. appName
        local success, result = utils.executeCommand(cmd, logger)
        
        if not success then
            logger("サブモジュールの削除に失敗しました: " .. result)
            return false, "サブモジュールの削除に失敗しました"
        end
    else
        -- 通常のディレクトリとして管理されている場合
        utils.executeCommand("rm -rf " .. config.paths.apps .. "/" .. appName, logger)
    end
    
    -- config.luaから削除
    -- この部分は複雑なので、手動での対応を推奨するメッセージを表示
    logger("アプリをアンインストールしました: " .. appName)
    logger("config.luaから " .. appName .. " を手動で削除してください")
    
    -- インストール済みリストから削除
    appManager.installedApps[appName] = nil
    
    return true, "アンインストール成功（config.luaは手動で更新してください）"
end

-- アプリを更新
function appManager.update(appName)
    if not appManager.isInstalled(appName) then
        logger("アプリはインストールされていません: " .. appName)
        return false, "アプリはインストールされていません"
    end
    
    local appPath = config.paths.apps .. "/" .. appName
    local appInfo = appManager.installedApps[appName]
    local isSubmodule = appInfo and appInfo.isSubmodule
    
    if isSubmodule then
        -- サブモジュールとして管理されている場合
        local cmd = "cd " .. appPath .. " && git pull origin main"
        local success, result = utils.executeCommand(cmd, logger)
        
        if not success then
            logger("アプリの更新に失敗しました: " .. result)
            return false, "アプリの更新に失敗しました"
        end
    else
        -- リポジトリから再インストール
        if not appInfo or not appInfo.url then
            logger("アプリの元URLが不明です: " .. appName)
            return false, "アプリの元URLが不明です"
        end
        
        -- 一度アンインストールして再インストール
        appManager.uninstall(appName)
        return appManager.installFromGit(appInfo.url, {force = true})
    end
    
    logger("アプリを更新しました: " .. appName)
    return true, "更新成功"
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