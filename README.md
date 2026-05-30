# vpm-package-template

VRChat Package Manager (VPM) パッケージ用のテンプレートリポジトリです。

## リリース

`Actions` タブから `Release` ワークフローを手動実行（`workflow_dispatch`）すると、
`package.json` の `version` をもとにタグと GitHub Release が作成されます。

## VPM Listing (GitHub Pages)

`Release` ワークフローはリリース作成後、過去の全リリースを走査して
VPM Listing (`index.json`) と最小限の `index.html` を生成し、GitHub Pages へ公開します。

- Listing URL: `https://<owner>.github.io/<repo>/index.json`
- 各リリースに添付された `package.json` の内容と `.zip` のダウンロードURLから自動生成されます。
- メタデータ（`name` / `id` / `url` / `author`）はリポジトリ情報と最新リリースの
  `package.json` から自動導出されるため、利用者が編集する必要はありません。

### 初回のみ必要な設定

リポジトリの **Settings → Pages → Build and deployment → Source** を
**「GitHub Actions」** に設定してください。
