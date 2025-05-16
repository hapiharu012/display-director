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
        -- 例: シングルモニター
        single = {
            enabled = false,
            position = "centered"  -- "centered", "left", "right"
        },
        -- 例: デュアルモニター
        dual = {
            enabled = false,
            position = "above"  -- "above", "left", "right"
        }
    }
} 