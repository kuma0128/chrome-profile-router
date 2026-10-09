# Chrome Profile Router

外部アプリでクリックしたURLを、指定したChromeプロファイルで開き、そのウィンドウを前面に出すmacOS用ツールです。URLを受け取るための小さな `.app` と、JSONの振り分け設定で構成します。画面やメニューバーには常駐せず、Chromeへの受け渡しが終わると終了します。

Chromeには `--profile-directory` を起動引数として渡します。Chromeの `Local State` や履歴、Cookieは読み取らず、フルディスクアクセスも使いません。

## 振り分け設定の例

同梱の `config.json` は、架空のドメインを使った設定例です。インストール後、ユーザー設定を実際のドメインと確認済みのプロファイルディレクトリに合わせて編集してください。

| URLのホスト名 | 設定上の名前 | Chromeの保存先 |
| --- | --- | --- |
| `work.example.com` | work | `Profile 1` |
| `docs.example.org` とそのサブドメイン | study | `Profile 2` |
| 上記以外 | personal | `Default` |

ルールは配列の先頭から判定し、最初に一致したものを使います。`includeSubdomains: false` はホスト名の完全一致、`true` はそのホストとサブドメインを対象にします。大文字・小文字と末尾のドットは区別しません。URLのパスやクエリは判定に使いません。

## ビルドとインストール

macOS 13以降、Swift 6以降を含むXcode Command Line Tools、Google Chromeが必要です。外部パッケージへの依存はありません。

```sh
./scripts/test.sh
./scripts/build.sh
```

成果物は `dist/Chrome Profile Router.app` です。手元のMac用にアドホック署名します。他のMacへ配布するためのDeveloper ID署名・公証は含みません。

配布用の実行ファイルからは、ローカルのソースパスを含むデバッグ情報を除去します。同梱する設定はソース側の `config.json` で、ユーザー設定や `config.local.json` は含めません。

`test.sh` は、Command Line Toolsの構成によってSwift Testingのマクロが自動で見つからない場合にも対応しています。選択中のツールチェーン内にマクロライブラリがある場合は、明示して読み込みます。

```sh
./scripts/install.sh
```

インストール先は `~/Applications/Chrome Profile Router.app` です。既に同じアプリがある場合は、`~/Applications/.chrome-profile-router-backup.XXXXXX/` に退避します。ユーザー設定がなければ `~/.config/chrome-profile-router/config.json` を作成し、既存の設定は保持します。

インストール後、**システム設定 → デスクトップとDock → デフォルトのWebブラウザ**で **Chrome Profile Router** を選んでください。インストールスクリプトは既定ブラウザを変更しません。振り分けを使わなくなった場合は、同じ画面でGoogle Chromeなどのブラウザを選びます。

既定ブラウザを変える前に、アプリを指定して動作を確認できます。

```sh
open -a "$HOME/Applications/Chrome Profile Router.app" 'https://example.com/'
```

アプリを単独でダブルクリックしても画面は表示せず、終了します。

## 設定の変更と確認

通常は `~/.config/chrome-profile-router/config.json` を編集します。URLを受け取るたびに読み直すため、再ビルドや再起動は不要です。

実際の会社名・ドメイン・プロファイルの対応表は、このユーザー設定に保存します。公開するソース内の `config.json` は設定例のままにしてください。プロジェクト内で試す場合は、Gitの対象から除外した `config.local.json` を作り、`--config config.local.json` で指定できます。ビルド成果物とログもGitの対象から除外しています。

設定ファイルの優先順位は次のとおりです。

1. CLIの `--config PATH`
2. `~/.config/chrome-profile-router/config.json`
3. `.app` に同梱した `config.json`

優先する設定ファイルが壊れていたり読み取れなかったりする場合は、エラーとして扱います。他の設定やプロファイル指定なしの起動には切り替えません。

`profiles` の値にはChromeの表示名ではなく、`Default` または `Profile 1` のようなディレクトリ名を指定します。対象プロファイルで `chrome://version` を開き、「Profile Path」の末尾を確認してください。**プロファイルの実在確認は行いません。存在しない番号を指定するとChromeが新しいプロファイルを作ることがあるため、確認済みの値を使ってください。**

Chromeを開かずに、設定と振り分け結果を確認できます。

```sh
"dist/Chrome Profile Router.app/Contents/MacOS/ChromeProfileRouter" --check-config
"dist/Chrome Profile Router.app/Contents/MacOS/ChromeProfileRouter" \
  --config config.json --resolve 'https://work.example.com/' 'https://team.docs.example.org/'
```

ソース側の設定を試す場合は `--config config.json` を追加します。`--resolve` は確認用にURL全体を標準出力へ表示します。認証用URLなどを渡した結果を、そのまま共有しないでください。

```sh
swift run ChromeProfileRouter --config config.json --resolve 'https://work.example.com/'
```

`--open URL [URL ...]` は同じルールで実際にChromeを開きます。`http`、`https` とローカルHTMLファイルの `file` URLを受け付けます。シェルは介さず、URLを1つの起動引数として渡します。

1回で複数のURLを受け取った場合は、全URLを検証してから、同じChromeプロファイルのURLを1回の起動要求にまとめます。プロファイルごとのURLの順序と重複は保持します。プロファイルが異なる場合の前面ウィンドウの順序は保証しません。

Chromeが起動中の場合は、URLの受け渡し用プロセスにはフォーカスを移さず、ウィンドウを持つChrome本体をアクティブにします。ウィンドウの操作にAppleScriptやアクセシビリティ権限は使いません。

CLIの `--open` は全起動要求の完了通知を受け取ると終了します。ページの読み込み完了までは待ちません。通常の `.app` 起動では、続けて届くURLイベントを受信するため、受け渡し後に1秒待って終了します。

通常の処理では、macOSの統合ログにホスト名とプロファイルのディレクトリ名だけを記録します。URLのパス、クエリ、フラグメントは記録しません。

```sh
log show --last 5m --info --predicate 'subsystem == "local.ChromeProfileRouter"'
```

## 対応範囲

- Slackなど、macOSの既定ブラウザへ渡されるリンクが対象です。Chrome内の通常のリンククリックやアドレスバーへの入力は経由しません。
- リダイレクト先を見てプロファイルを切り替える機能はありません。最初に受け取ったURLで判定します。
- 既定ブラウザの候補に表示させるため、HTMLの閲覧アプリとしても登録します。ローカルの `.html` / `.htm` / `.xhtml` ファイルは `defaultProfile` で開きます。ルーター自身はファイルの内容を読みません。
- プロファイルを削除・作り直した場合は設定の更新が必要です。
- Chromeが起動中でも、指定したプロファイルで開くために起動引数を渡す新規起動を要求します。Chrome側が既存のプロセスへ処理を引き継ぎます。

## 構成

- `Sources/RouterCore/`: 設定検証、ドメイン判定、Chrome起動引数の生成、プロファイルごとの一括処理
- `Sources/ChromeProfileRouter/`: URLイベントの受信、設定読込、Chrome起動、CLI
- `Tests/RouterCoreTests/`: 振り分け、ドメインの境界、不正設定、URL保持、一括処理のテスト
- `Resources/Info.plist`: macOSへのHTTP/HTTPS・HTMLハンドラー登録
- `scripts/`: テスト、ビルド、インストール

macOS・Chrome更新後は、異なるプロファイルを前面にした状態からのリンク起動を確認してください。

動作確認環境はmacOS 27.0.1（Apple Silicon）、Chrome 154.0.8037.58、Swift 6.4です。11件のテストに加え、起動中のChromeで3プロファイルへの受け渡し、同じプロファイルへの複数URLの一括起動、連続したURLイベント、ルーター終了後の再起動、ローカルHTMLを確認しています。Chromeを非表示にした状態と別のプロファイルが前面の状態から、指定プロファイルのページが前面に出ることも確認しています。振り分け先は `chrome://version` のProfile Pathでも確認しています。ドメインのルールはテストと `--resolve` で確認し、ブラウザへの受け渡しはMac内の確認用ページを使っています。Chrome未起動時、Intel Mac、旧macOSでの実機確認は行っていません。

このMacで同一プロファイルへ5件のURLを渡す測定では、全URLのリクエストがローカルHTTPサーバーへ到着するまでの時間が、変更前の約1.12秒から約0.63秒になりました。各3回の中央値で、起動中のChromeを使用しています。ページ描画の完了時間や、単一URLの表示速度の改善を示す値ではありません。
