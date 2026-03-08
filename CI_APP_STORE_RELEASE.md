# GitHub Actions iOS Release (App Store Connect)

This project includes a manual GitHub workflow:

- `.github/workflows/ios-app-store-release.yml`

It archives the app on GitHub's macOS runner, exports an `.ipa`, stores the IPA as an artifact, and can upload to App Store Connect.

## 1) Create an App Store Connect API key

In App Store Connect:

1. Go to `Users and Access` -> `Integrations` -> `App Store Connect API`.
2. Create a key with at least `App Manager` permissions.
3. Download the `.p8` file once.
4. Copy:
   - `Key ID`
   - `Issuer ID`

## 2) Add GitHub repository secrets

In your GitHub repo:

1. Go to `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`.
2. Add:
   - `ASC_KEY_ID`: your API Key ID.
   - `ASC_ISSUER_ID`: your API Issuer ID.
   - `ASC_PRIVATE_KEY`: full contents of the `.p8` file (include BEGIN/END lines).

## 3) Run the workflow

1. Push your code to GitHub.
2. Open `Actions` -> `iOS App Store Release`.
3. Click `Run workflow`.
4. Keep `upload_to_app_store = true` to upload directly.
   - Set it to `false` to only build/export and download the IPA artifact.

## Notes

- The workflow uses `xcodebuild -target "Timberline Trail App"` and automatic signing.
- It relies on your existing Apple team/app configuration in the project.
- If upload fails, inspect the `Upload to App Store Connect` step logs for the exact App Store error code.
