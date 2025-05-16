# Hammerspoon ディスプレイマネージャー

ディスプレイ構成を自動的に管理するHammerspoonアプリケーション

## 概要

このアプリケーションは外部モニターの接続状態を検出し、保存されたレイアウトを自動的に適用します。異なるモニター構成ごとに個別のレイアウトを保存できます。

## インストール

### 自動インストール

```lua
hs.execute('cd ~/.hammerspoon && git clone https://github.com/yourusername/hammerspoon-display-manager.git /tmp/app && cd /tmp/app && ./install.sh && rm -rf /tmp/app')
```

または、Hammerspoonコンソールから:

```
Ctrl+Alt+Cmd+I を押して、GitリポジトリのURLを入力
```

### 手動インストール

1. このリポジトリをクローン
2. ファイルを以下のようにコピー:
   - `layout.lua` と `utils.lua` → `~/.hammerspoon/apps/display_manager/`
   - `config/settings.lua` → `~/.hammerspoon/apps/display_manager/config/`
3. `~/.hammerspoon/config.lua` の `apps.enabled` に `"display_manager"` を追加
4. Hammerspoonをリロード

## ディレクトリ構造

```
display_manager/
├── config/               # アプリ専用設定
│   └── settings.lua      # 設定ファイル
├── data/                 # アプリ専用データ（gitignore対象）
│   └── saved_layouts.lua # 保存されたレイアウト
├── layout.lua            # メインモジュール
├── utils.lua             # アプリ固有のユーティリティ
└── README.md             # このファイル
```

## 使い方

### ホットキー

- `Ctrl+Alt+Cmd+S`: 現在のレイアウトを保存
- `Ctrl+Alt+Cmd+X`: 現在のモニター構成のレイアウトを削除（未実装）
- `Ctrl+Alt+Cmd+D`: 自動切り替えのON/OFF
- `Ctrl+Alt+Cmd+Return`: レイアウトを強制適用

### 自動レイアウト

1. モニターを接続
2. レイアウトを調整
3. `Ctrl+Alt+Cmd+S` を押して保存
4. 次回同じモニターを接続すると自動的にレイアウトが適用されます

## カスタマイズ

`config/settings.lua` で以下の設定が可能です:

- 自動切り替え（ON/OFF）
- ログレベル
- ホットキー設定
- デフォルトレイアウト（未実装）

## 依存関係

- [Hammerspoon](https://www.hammerspoon.org/)
- [displayplacer](https://github.com/jakehilborn/displayplacer) (オプション、推奨)

## ライセンス

MITライセンス 