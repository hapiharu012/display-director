#!/bin/bash

# Hammerspoon ディスプレイマネージャーインストールスクリプト
echo "Hammerspoonディスプレイマネージャーをインストールしています..."

# Hammerspoonディレクトリのパス
HAMMERSPOON_DIR="$HOME/.hammerspoon"
APP_NAME="display_manager"
APP_DIR="$HAMMERSPOON_DIR/apps/$APP_NAME"

# ディレクトリ構造を作成
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/config"
mkdir -p "$APP_DIR/data"

# ファイルをコピー
echo "メインファイルをコピーしています..."
cp layout.lua "$APP_DIR/"
cp utils.lua "$APP_DIR/"
cp README.md "$APP_DIR/"

# 設定ファイルをコピー
echo "設定ファイルをコピーしています..."
cp -n config/settings.lua "$APP_DIR/config/" 2>/dev/null || echo "既存の設定ファイルを保持しています..."

# config.luaに追加
CONFIG_FILE="$HAMMERSPOON_DIR/config.lua"

# アプリが有効リストにあるか確認
if grep -q "\"$APP_NAME\"" "$CONFIG_FILE"; then
    echo "アプリはすでに有効リストに追加されています"
else
    # 有効リストにアプリを追加
    echo "アプリを有効リストに追加しています..."
    # 一時的なファイルに修正内容を書き込み
    TMP_FILE=$(mktemp)
    awk -v app="$APP_NAME" '
    /enabled = {/ {
        print $0
        getline
        if (!/}/) {
            if (!match($0, app)) {
                print $0
                print "            \"" app "\""
            } else {
                print $0
            }
        } else {
            print "            \"" app "\""
            print $0
        }
        next
    }
    { print $0 }
    ' "$CONFIG_FILE" > "$TMP_FILE"
    
    # 元のファイルを置き換え
    mv "$TMP_FILE" "$CONFIG_FILE"
fi

echo "インストールが完了しました！"
echo "Hammerspoonをリロードしてください。" 