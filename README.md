# Timberline Trail App

- [Development to Release Runbook](DEVELOPMENT_TO_RELEASE.md)
- [CI Release Setup](CI_APP_STORE_RELEASE.md)
- [Release Checklist](RELEASE_CHECKLIST.md)
- [Firestore Roles and Content](FIRESTORE_ROLES_AND_CONTENT.md)

## Version Bump

- Auto-increment build number and set marketing version:
  - `scripts/bump_ios_version.sh 1.0.1`
- Set both explicitly:
  - `scripts/bump_ios_version.sh 1.0.1 6`
