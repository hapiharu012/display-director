# Hammerspoon 設定

これは個人用の Hammerspoon 設定リポジトリです。

## ディレクトリ構造

```
.hammerspoon/
├── apps/                    # アプリケーションディレクトリ
│   └── display_manager/     # ディスプレイマネージャーアプリ
│       ├── config/          # アプリ専用設定
│       │   └── settings.lua # 設定ファイル
│       ├── data/            # アプリ専用データ（gitignore対象）
│       │   └── saved_layouts.lua # 保存されたレイアウト
│       ├── layout.lua       # メインモジュール
│       ├── utils.lua        # アプリ固有のユーティリティ
│       └── README.md        # アプリのドキュメント
├── config.lua               # 全体設定ファイル
├── init.lua                 # 起動スクリプト
└── lib/                     # 共通ライブラリ
    ├── app_manager.lua      # アプリマネージャー
    ├── logger.lua           # ロギング機能
    └── utils.lua            # 共通ユーティリティ
```

## アプリケーション

### ディスプレイマネージャー

ディスプレイの配置を自動的に管理するアプリケーションです。

#### 機能

- 外部モニター接続時に自動的にレイアウトを適用
- レイアウトの保存と復元
- ホットキーによる操作

#### ホットキー

- `Ctrl+Alt+Cmd+S`: 現在のレイアウトを保存
- `Ctrl+Alt+Cmd+X`: 現在のモニター構成のレイアウトを削除
- `Ctrl+Alt+Cmd+D`: 自動切り替えのON/OFF
- `Ctrl+Alt+Cmd+Return`: レイアウトを強制適用

## インストール方法

1. このリポジトリをクローン

```
git clone https://github.com/username/hammerspoon-config.git ~/.hammerspoon
```

2. Hammerspoonを再起動

## 新しいアプリの追加方法

1. `apps/` ディレクトリに新しいアプリケーション用のフォルダを作成
2. `config.lua` の `apps.enabled` にアプリケーション名を追加
3. アプリディレクトリ内に `config` と `data` ディレクトリを作成

## Git管理について

このリポジトリはGitで管理されています。以下は主要な管理ポイントです：

### コミットのガイドライン

- アプリの追加/更新時は明確なコミットメッセージを使用
- 各機能の変更は個別のコミットにする
- 設定ファイルの変更と機能の実装は分けてコミットする

### 除外ファイル

以下のファイルは除外されています：

- `*.log` - すべてのログファイル
- `apps/*/data/*` - アプリケーションデータ（`.gitkeep`は除く）
- `Spoons/` - Spoonsディレクトリ（個別にインストール）
- `private_config.lua` - プライベート設定（個人情報など）

### リモートリポジトリの設定

```bash
# リモートリポジトリを追加
git remote add origin https://github.com/username/hammerspoon-config.git

# 初回プッシュ
git push -u origin main
```

## アプリのGit管理とインストール

### アプリの管理方法

各アプリは独立したGitリポジトリとして管理できます。アプリは以下の構造に従います：

```
hammerspoon-app-name/
├── layout.lua              # メインモジュール
├── utils.lua               # アプリ固有のユーティリティ
├── config/                 # アプリ専用設定
│   └── settings.lua        # 設定ファイル
├── data/                   # アプリ専用データディレクトリ（空、gitignore対象）
├── README.md               # ドキュメント
├── install.sh              # インストールスクリプト
└── package.json            # アプリ情報
```

### アプリの作成手順

1. 新しいリポジトリを作成
2. アプリのコードを作成
3. `install.sh` スクリプトを作成（ファイルコピーと設定更新用）
4. `package.json` で依存関係などを定義

### アプリのインストール方法

1. Hammerspoonの設定ウィンドウから:
   - `Ctrl+Alt+Cmd+I` を押して、GitリポジトリのURLを入力

2. コマンドラインから:
   ```lua
   hs.execute('cd ~/.hammerspoon && git clone https://github.com/username/hammerspoon-app-name.git /tmp/app && cd /tmp/app && ./install.sh && rm -rf /tmp/app')
   ```

### 既存アプリのリポジトリへの分離方法

1. アプリ用の新しいリポジトリを作成
2. アプリファイルをコピー
3. `install.sh` を作成
4. `package.json` を作成
5. 変更をコミットしてプッシュ 