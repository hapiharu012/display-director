# Hammerspoon 設定

これは個人用の Hammerspoon 設定リポジトリです。

## ディレクトリ構造

```
.hammerspoon/
├── apps/                    # アプリケーションディレクトリ（Gitサブモジュール）
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

1. このリポジトリをクローン（サブモジュールを含む）

```
git clone --recursive https://github.com/username/hammerspoon-config.git ~/.hammerspoon
```

あるいは、クローン後にサブモジュールを初期化

```
git clone https://github.com/username/hammerspoon-config.git ~/.hammerspoon
cd ~/.hammerspoon
git submodule update --init --recursive
```

2. Hammerspoonを再起動

## 新しいアプリの追加方法

### 1. 独立したGitリポジトリとして作成

1. 新しいリポジトリを作成（例: `hammerspoon-app-name`）
2. 標準的なディレクトリ構造に沿ってアプリを開発
3. アプリの設定ファイル、データディレクトリ、インストールスクリプトを用意
4. `package.json`ファイルでメタデータを定義

### 2. サブモジュールとして追加

```bash
# アプリをサブモジュールとして追加
git submodule add https://github.com/username/hammerspoon-app-name.git apps/app_name

# config.luaのapps.enabledに追加
# ...

# 変更をコミット
git commit -m "アプリ: 新しいアプリを追加"
```

### 3. アプリマネージャーでインストール

1. Hammerspoonの設定ウィンドウから:
   - `Ctrl+Alt+Cmd+I` を押して、GitリポジトリのURLを入力
   - オプションで「サブモジュールとしてインストール」を選択

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

# 初回プッシュ（サブモジュールを含む）
git push -u origin main --recurse-submodules=on-demand
```

## アプリの構造とGit管理

各アプリは独立したGitリポジトリとして管理されます。推奨される構造：

```
hammerspoon-app-name/
├── layout.lua              # メインモジュール
├── utils.lua               # アプリ固有のユーティリティ
├── config/                 # アプリ専用設定
│   └── settings.lua        # 設定ファイル
├── data/                   # アプリ専用データディレクトリ（空、gitignore対象）
├── README.md               # ドキュメント
├── install.sh              # インストールスクリプト
└── package.json            # アプリ情報と依存関係
```

### アプリの配布方法

アプリは以下の方法で配布・インストールできます：

1. **独立したGitリポジトリとして**
   ```lua
   hs.execute('cd ~/.hammerspoon && git clone https://github.com/username/hammerspoon-app-name.git /tmp/app && cd /tmp/app && ./install.sh && rm -rf /tmp/app')
   ```

2. **Gitサブモジュールとして**
   ```bash
   git submodule add https://github.com/username/hammerspoon-app-name.git apps/app_name
   ```

3. **アプリマネージャーを使用して**
   ```lua
   -- アプリマネージャーのGUIから
   -- または
   hs.luaexec([[require("lib.app_manager").installFromGit("https://github.com/username/hammerspoon-app-name.git", {useSubmodule = true})]])
   ``` 