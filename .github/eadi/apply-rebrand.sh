#!/usr/bin/env bash
# Applies the EADI / CharmPy rebrand to a clean upstream checkout.
#
# The fork keeps no changes to upstream files. This script runs in CI
# after actions/checkout and before the IDE build. Every edit checks its
# expected occurrence count. If an upstream refactor changes a pattern,
# the run fails here and names the file. Fix the pattern in this script.

set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

fail() {
  echo "EADI rebrand: ERROR: $*" >&2
  exit 1
}

count_occurrences() { # <file> <literal pattern>
  PATTERN="$2" perl -0777 -ne '$c = () = /\Q$ENV{PATTERN}\E/g; print $c' "$1"
}

replace() { # <file> <original> <replacement> [expected count]
  local file="$1" original="$2" replacement="$3" expected="${4:-1}"
  [ -f "$file" ] || fail "missing file: $file"
  local before_original before_replacement after_original after_replacement
  before_original="$(count_occurrences "$file" "$original")"
  if [ "$before_original" -ne "$expected" ]; then
    fail "$file: expected $expected occurrence(s), found $before_original: ${original%%$'\n'*}"
  fi
  before_replacement=""
  if [ -n "$replacement" ]; then
    before_replacement="$(count_occurrences "$file" "$replacement")"
  fi
  ORIGINAL="$original" REPLACEMENT="$replacement" \
    perl -0777 -i -pe 's/\Q$ENV{ORIGINAL}\E/$ENV{REPLACEMENT}/g' "$file"
  if [ -n "$replacement" ]; then
    after_replacement="$(count_occurrences "$file" "$replacement")"
    if [ "$after_replacement" -ne "$((before_replacement + expected))" ]; then
      fail "$file: replacement did not take effect"
    fi
  fi
  if ! printf '%s' "$replacement" | grep -qF -- "$original"; then
    after_original="$(count_occurrences "$file" "$original")"
    [ "$after_original" -eq 0 ] || fail "$file: original text still present"
  fi
  echo "EADI rebrand: patched $file"
}

expect_contains() { # <file> <pattern>
  grep -q -- "$2" "$1" || fail "$1: expected to contain: $2"
}

expect_absent() { # <file> <pattern>
  if grep -q -- "$2" "$1"; then fail "$1: still contains: $2"; fi
}

# --- IDEA product properties ---------------------------------------------

idea_kt=build/src/org/jetbrains/intellij/build/IdeaCommunityProperties.kt
replace "$idea_kt" 'get() = "idea"' 'get() = "eadi"'
replace "$idea_kt" '"IdeaIC${' '"EadiIC${'
replace "$idea_kt" '"ideaIC-$buildNumber"' '"eadiIC-$buildNumber"'
replace "$idea_kt" '"idea-ce"' '"eadi-ce"'
replace "$idea_kt" 'urlSchemes = listOf("idea")' 'urlSchemes = listOf("eadi")'
replace "$idea_kt" 'fullName { "IntelliJ IDEA Open Source" }' 'fullName { "EADI Open Source" }'
replace "$idea_kt" 'installDirNameHandler { "IntelliJ IDEA OSS" }' 'installDirNameHandler { "EADI OSS" }'
replace "$idea_kt" 'bundleIdentifier = "com.jetbrains.intellij.ce"' 'bundleIdentifier = "com.eadi.intellij.ce"'
replace "$idea_kt" '"IntelliJ IDEA OSS.app"' '"EADI OSS.app"'
replace "$idea_kt" '"idea-oss"' '"eadi-oss"'
idea_uninstall=$'\n  uninstallFeedbackUrl { appInfo ->\n    "https://www.jetbrains.com/idea/uninstall/?edition=IC-${appInfo.majorVersion}.${appInfo.minorVersion}"\n  }\n'
replace "$idea_kt" "$idea_uninstall" ''

# --- CharmPy product properties ------------------------------------------

pc_base_kt=python/build/src/org/jetbrains/intellij/build/pycharm/PyCharmPropertiesBase.kt
replace "$pc_base_kt" 'get() = "pycharm"' 'get() = "charmpy"'

pc_kt=python/build/src/org/jetbrains/intellij/build/pycharm/PyCharmCommunityProperties.kt
replace "$pc_kt" '"PyCharmCE${' '"CharmPyCE${'
replace "$pc_kt" '"pycharmPC-$buildNumber"' '"charmpyPC-$buildNumber"'
replace "$pc_kt" '"pycharm-ce"' '"charmpy-ce"'
replace "$pc_kt" 'fullName { "PyCharm Open Source" }' 'fullName { "CharmPy Open Source" }'
replace "$pc_kt" 'installDirNameHandler { "PyCharm OSS" }' 'installDirNameHandler { "CharmPy OSS" }'
replace "$pc_kt" 'bundleIdentifier = "com.jetbrains.pycharm.ce"' 'bundleIdentifier = "com.eadi.pycharm.ce"'
replace "$pc_kt" '"PyCharm OSS.app"' '"CharmPy OSS.app"'
replace "$pc_kt" '"pycharm-oss"' '"charmpy-oss"'
pc_uninstall=$'\n    uninstallFeedbackUrl { appInfo ->\n      "https://www.jetbrains.com/pycharm/uninstall/?version=${appInfo.productCode}-${appInfo.majorVersion}.${appInfo.minorVersion}"\n    }\n'
replace "$pc_kt" "$pc_uninstall" ''

# --- Application info ----------------------------------------------------

idea_xml=community-resources/resources/idea/IdeaApplicationInfo.xml
replace "$idea_xml" '<company name="JetBrains s.r.o." url="https://www.jetbrains.com"/>' '<company name="EADI Software" shortName="EADI" url="https://example.com"/>'
replace "$idea_xml" 'product="IDEA" fullname="IntelliJ IDEA" script="idea"' 'product="EADI" fullname="EADI" script="eadi"'

pc_xml=python/ide-common/resources/idea/PyCharmCoreApplicationInfo.xml
replace "$pc_xml" '<company name="JetBrains s.r.o." url="https://www.jetbrains.com" copyrightStart="2010"/>' '<company name="EADI Software" shortName="EADI" url="https://example.com" copyrightStart="2010"/>'
replace "$pc_xml" 'product="PyCharm" script="pycharm"' 'product="CharmPy" script="charmpy"'

# --- Windows installer ---------------------------------------------------

nsi=build/conf/nsis/idea.nsi
replace "$nsi" 'VIAddVersionKey /LANG=0 "CompanyName" "JetBrains s.r.o."' 'VIAddVersionKey /LANG=0 "CompanyName" "${MANUFACTURER}"'
replace "$nsi" 'WriteRegStr SHCTX $0 "Publisher" "JetBrains s.r.o."' 'WriteRegStr SHCTX $0 "Publisher" "${MANUFACTURER}"'
replace "$nsi" 'WriteRegStr SHCTX $0 "URLInfoAbout" "https://www.jetbrains.com/products"' 'WriteRegStr SHCTX $0 "URLInfoAbout" ""'
replace "$nsi" 'd:\JetBrains\Product' 'd:\EADI\Product' 2
replace "$nsi" 'd:\JetBrains\install.log' 'd:\EADI\install.log'
replace "$nsi" 'IntelliJIdeaProjectFile' 'EADIProjectFile' 4
replace "$nsi" '"IntelliJ IDEA Project File"' '"EADI Project File"'

for lang in en ja ko zh_CN; do
  replace "build/conf/nsis/idea_${lang}.nsi" 'JetBrains ETW' 'EADI ETW'
done

# --- Consent crash fix for a non-JetBrains vendor ------------------------

app_ui=platform/platform-impl/src/com/intellij/ui/AppUIUtil.kt
replace "$app_ui" 'var result = options.consents.first' 'var result = options.consents.first.toMutableList()'

# --- Notice --------------------------------------------------------------

if grep -q 'This is a modified distribution' NOTICE.txt; then
  echo "EADI rebrand: NOTICE.txt already patched"
else
  printf '\nThis is a modified distribution of the software above.\nThe product name and the vendor name were changed.\n' >> NOTICE.txt
  echo "EADI rebrand: patched NOTICE.txt"
fi

# --- Final checks --------------------------------------------------------

expect_contains "$idea_kt" 'EadiIC'
expect_contains "$idea_kt" '"eadiIC-$buildNumber"'
expect_contains "$idea_kt" '"eadi-ce"'
expect_contains "$pc_base_kt" 'get() = "charmpy"'
expect_contains "$pc_kt" 'CharmPyCE'
expect_contains "$pc_kt" '"charmpyPC-$buildNumber"'
expect_contains "$pc_kt" '"charmpy-ce"'
expect_contains "$idea_xml" 'name="EADI Software" shortName="EADI"'
expect_contains "$idea_xml" 'product="EADI"'
expect_contains "$pc_xml" 'name="EADI Software" shortName="EADI"'
expect_contains "$pc_xml" 'product="CharmPy"'
expect_contains "$nsi" 'EADIProjectFile'
expect_contains "$nsi" '"${MANUFACTURER}"'
expect_contains "$app_ui" 'options.consents.first.toMutableList()'
expect_contains NOTICE.txt 'This is a modified distribution'
expect_absent "$idea_kt" 'uninstallFeedbackUrl'
expect_absent "$pc_kt" 'uninstallFeedbackUrl'
expect_absent "$nsi" 'IntelliJIdeaProjectFile'
for lang in en ja ko zh_CN; do
  expect_contains "build/conf/nsis/idea_${lang}.nsi" 'EADI ETW'
  expect_absent "build/conf/nsis/idea_${lang}.nsi" 'JetBrains ETW'
done

echo "EADI rebrand: all patches applied"
