-- Hammerspoon 全体設定

local config = {
    -- 基本パス設定
    paths = {
        home = os.getenv("HOME"),
        hammerspoon = os.getenv("HOME") .. "/.hammerspoon",
        data = os.getenv("HOME") .. "/.hammerspoon/data",
        apps = os.getenv("HOME") .. "/.hammerspoon/apps",
        lib = os.getenv("HOME") .. "/.hammerspoon/lib"
    },
    
    -- アプリケーション設定
    apps = {
        -- 有効化するアプリのリスト
        enabled = {
            "display_manager"
        }
    },
    
    -- デバッグ設定
    debug = {
        enabled = true
    }
}

return config 