#!/bin/bash
# ============================================================================
# Nenshkrimi i IPA-se ne GitHub Actions (Rruga C — Apple Developer $99/vit)
# ----------------------------------------------------------------------------
# Vepro VETEM kur ekzistojne keto secrets te repos (Settings → Secrets → Actions):
#   SIGNING_CERT_P12_BASE64       → certifikata .p12 (Apple Distribution) ne base64
#   SIGNING_CERT_PASSWORD         → fjalekalimi i .p12
#   PROVISIONING_PROFILE_BASE64   → profili .mobileprovision (Ad Hoc) ne base64
#
# Pa keto secrets, skripti del menjehere dhe IPA mbetet e panenshkruar
# (perdor Sideloadly ose TrollStore per ta nenshkruar).
# ============================================================================
set -euo pipefail

if [ -z "${SIGNING_CERT_P12_BASE64:-}" ] || [ -z "${PROVISIONING_PROFILE_BASE64:-}" ]; then
  echo "→ Nuk ka secrets firmosjeje: IPA mbetet 'ManePro4K-1.9.0-unsigned.ipa'."
  echo "→ Firmose me Sideloadly/TrollStore, ose shto secrets (Apple Developer)."
  exit 0
fi

APP="build/Payload/ManePro4K.app"
BUNDLE_ID="uk.apkim.manepro4k"
KC="mane-build.keychain-db"
KCPASS="mane-ci-temp"

echo "== Dekodo certifikaten dhe profilin =="
echo "$SIGNING_CERT_P12_BASE64" | openssl base64 -d -A -out cert.p12
echo "$PROVISIONING_PROFILE_BASE64" | openssl base64 -d -A -out profile.mobileprovision

echo "== Krijo keychain dhe importo certifikaten =="
security create-keychain -p "$KCPASS" "$KC"
security default-keychain -s "$KC"
security unlock-keychain -p "$KCPASS" "$KC"
security import cert.p12 -k "$KC" -P "${SIGNING_CERT_PASSWORD:-}" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -k "$KCPASS" "$KC" >/dev/null

echo "== Instalo profilin =="
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
security cms -D -i profile.mobileprovision > profile.plist
UUID=$(/usr/libexec/PlistBuddy -c 'Print :UUID' profile.plist)
echo "Profili: $UUID"
cp profile.mobileprovision "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
cp profile.mobileprovision "$APP/embedded.mobileprovision"

echo "== Nxirr entitlements nga profili =="
/usr/libexec/PlistBuddy -x -c 'Print :Entitlements' profile.plist > entitlements.plist

echo "== Gjej identitetin =="
IDENTITY=$(security find-identity -v -p codesigning "$KC" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
echo "Po nenshkruaj me: $IDENTITY"

echo "== Nenshkruaj librarite e brendshme (nese ka) =="
find "$APP" -type d -name '*.framework' -print0 | while IFS= read -r -d '' fw; do
  codesign --force --sign "$IDENTITY" "$fw" || true
done
find "$APP" -type f -name '*.dylib' -print0 | while IFS= read -r -d '' dy; do
  codesign --force --sign "$IDENTITY" "$dy" || true
done

echo "== Nenshkruaj app-in =="
codesign --force --identifier "$BUNDLE_ID" --entitlements entitlements.plist --sign "$IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP"

echo "== Paketo IPA-n e nenshkruar =="
(cd build && zip -qry ../ManePro4K-1.9.0-signed.ipa Payload)
echo "✅ Gati: ManePro4K-1.9.0-signed.ipa"
