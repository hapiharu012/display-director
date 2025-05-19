-- ディスプレイマネージャー設定

return {
    -- 自動切り替え設定（初期値はON）
    autoSwitch = true,
    
    -- ログ設定
    logging = {
        enabled = true,
        level = "info"  -- "debug", "info", "warning", "error"
    },
    
    -- ホットキー設定
    hotkeys = {
        saveLayout = {"ctrl", "alt", "cmd", "S"},
        deleteLayout = {"ctrl", "alt", "cmd", "X"},
        toggleAutoSwitch = {"ctrl", "alt", "cmd", "D"},
        forceApply = {"ctrl", "alt", "cmd", "return"}
    },
    
    -- デフォルトのレイアウト設定
    defaultLayouts = {
        -- シングルモニター
        single = {
            enabled = true,  -- 有効化
            position = "centered"  -- "centered", "left", "right"
        },
        -- デュアルモニター
        dual = {
            enabled = true,  -- 有効化
            position = "above"  -- "above", "left", "right"
        }
    }
} 