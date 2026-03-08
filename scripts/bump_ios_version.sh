#!/usr/bin/env bash
set -euo pipefail

PBXPROJ="Timberline Trail App.xcodeproj/project.pbxproj"
APP_BUNDLE_ID="com.michaeldankanich.timberlinetrailapp.ios2026"

usage() {
  cat <<'EOF'
Usage:
  scripts/bump_ios_version.sh <marketing_version> [build_number]

Examples:
  scripts/bump_ios_version.sh 1.0.1
  scripts/bump_ios_version.sh 1.1.0 12

Behavior:
  - Updates MARKETING_VERSION for app Debug/Release configs.
  - If build_number is omitted, CURRENT_PROJECT_VERSION is incremented by 1.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

if [[ ! -f "$PBXPROJ" ]]; then
  echo "Error: cannot find $PBXPROJ"
  exit 1
fi

NEW_MARKETING_VERSION="$1"

CURRENT_BUILD_NUMBER="$(perl -0777 -ne '
  while (/isa = XCBuildConfiguration;.*?PRODUCT_BUNDLE_IDENTIFIER = com\.michaeldankanich\.timberlinetrailapp\.ios2026;.*?CURRENT_PROJECT_VERSION = ([0-9]+);/sg) {
    print "$1\n";
    exit 0;
  }
' "$PBXPROJ")"

if [[ -z "${CURRENT_BUILD_NUMBER:-}" ]]; then
  echo "Error: could not find app CURRENT_PROJECT_VERSION in $PBXPROJ"
  exit 1
fi

if [[ $# -eq 2 ]]; then
  NEW_BUILD_NUMBER="$2"
else
  NEW_BUILD_NUMBER="$((CURRENT_BUILD_NUMBER + 1))"
fi

BUNDLE_ID="$APP_BUNDLE_ID" \
NEW_MARKETING="$NEW_MARKETING_VERSION" \
NEW_BUILD="$NEW_BUILD_NUMBER" \
perl -0777 -i -pe '
  my $bundle_id = $ENV{"BUNDLE_ID"};
  my $new_marketing = $ENV{"NEW_MARKETING"};
  my $new_build = $ENV{"NEW_BUILD"};

  s{
    (isa = XCBuildConfiguration;.*?PRODUCT_BUNDLE_IDENTIFIER = \Q$bundle_id\E;.*?MARKETING_VERSION = )[^;]+;
  }{$1$new_marketing;}sgex;

  s{
    (isa = XCBuildConfiguration;.*?PRODUCT_BUNDLE_IDENTIFIER = \Q$bundle_id\E;.*?CURRENT_PROJECT_VERSION = )[^;]+;
  }{$1$new_build;}sgex;
' "$PBXPROJ"

UPDATED_MARKETING_COUNT="$(rg -n "MARKETING_VERSION = ${NEW_MARKETING_VERSION};" "$PBXPROJ" | wc -l | tr -d ' ')"
UPDATED_BUILD_COUNT="$(rg -n "CURRENT_PROJECT_VERSION = ${NEW_BUILD_NUMBER};" "$PBXPROJ" | wc -l | tr -d ' ')"

if [[ "$UPDATED_MARKETING_COUNT" -lt 2 || "$UPDATED_BUILD_COUNT" -lt 2 ]]; then
  echo "Error: expected app Debug/Release versions to update, but counts were marketing=$UPDATED_MARKETING_COUNT build=$UPDATED_BUILD_COUNT"
  exit 1
fi

echo "Updated app version settings:"
echo "  MARKETING_VERSION: $NEW_MARKETING_VERSION"
echo "  CURRENT_PROJECT_VERSION: $NEW_BUILD_NUMBER"
