# 🍎 Mane Pro 4K v1.9.0 — IPA e ndërtuar në GitHub (pa Mac!)

Ky repositor **ndërton aplikacionin iOS Mane Pro 4K në cloud-in e GitHub-it**
(Mac virtual falas) dhe të jep skedarin **.IPA** për instalim në iPhone/iPad.

**Nuk të duhet: Mac ✗ Xcode ✗ Apple Developer (për ndërtim) ✗**

> **E rëndësishme:** repositori duhet të jetë **Public** — ndërtimi në Mac
> virtual të GitHub-it është **falas dhe i pakufizuar VETËM për repo publike**.

---

## 🚀 Si ta ndërtosh — 5 hapa

### Hapi 1 — Krijo repositorin
1. Hyr në [github.com](https://github.com) me llogari falas
2. Kliko **New repository**
3. Emri: `manepro4k` → zgjidh **Public** → **Create repository**

### Hapi 2 — Ngarko skedarët
1. Në faqen e repositorit: **Add file → Upload files**
2. Zvarrit (drag & drop) **përmbajtjen** e kësaj dosjeje:
   - dosjen `Sources/`
   - dosjen `Assets.xcassets/`
   - dosjen `scripts/`
   - skedarin `project.yml`
   - skedarin `README.md`
3. **Commit changes**

### Hapi 3 — Krijo workflow-in e ndërtimit
1. **Add file → Create new file**
2. Shkruaj emrin SAKTËSISHT kështu (pika në fillim është e detyrueshme; slash-et
   krijojnë dosjet automatikisht):

   ```
   .github/workflows/build-ipa.yml
   ```

3. Kopjo gjithë përmbajtjen nga blloku më poshtë → **Commit changes**

> Nëse e ke krijuar më parë këtë skedar: hap skedarin → kliko lapsin ✏️ →
> **Ctrl+A** → fshi → paste përmbajtjen e re → **Commit changes**.

<details>
<summary>📋 KLIKUAR PËR PËRMBAJTJEN E build-ipa.yml (kopjoje të plotë)</summary>

```yaml
name: Mane Pro 4K — Nderto IPA

on:
  workflow_dispatch:
  push:
    branches: [ main, master ]

jobs:
  build:
    name: Ndertimi i IPA (iPhone/iPad)
    runs-on: macos-14
    permissions:
      contents: write
    steps:
      - name: Marr kodin
        uses: actions/checkout@v4

      - name: Instalo XcodeGen
        run: |
          set -euo pipefail
          command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
          xcodegen --version

      - name: Gjenero projektin Xcode
        run: |
          set -euo pipefail
          xcodegen generate
          echo "=== Formati i projektit (duhet: objectVersion = 56) ==="
          grep -m1 objectVersion ManePro4K.xcodeproj/project.pbxproj
          echo "=== Skemat ==="
          xcodebuild -list -project ManePro4K.xcodeproj || true

      - name: Instalo VLC (MobileVLCKit) me CocoaPods
        run: |
          set -euo pipefail
          pod install --repo-update
          echo "=== Pods te instaluar ==="
          pod list --local | grep -i vlc || true

      - name: Nderto aplikacionin (VLC + AVPlayer)
        run: |
          set -o pipefail
          echo "=== Prova 1: me scheme (workspace me VLC) ==="
          if ! xcodebuild \
              -workspace ManePro4K.xcworkspace \
              -scheme ManePro4K \
              -configuration Release \
              -sdk iphoneos \
              -destination 'generic/platform=iOS' \
              -derivedDataPath build/DD \
              CODE_SIGNING_ALLOWED=NO \
              CODE_SIGNING_REQUIRED=NO \
              CODE_SIGN_IDENTITY="" \
              build 2>&1 | tee xcodebuild.log | tail -n 50; then
            echo ""
            echo "=== PROVA 1 deshtoi — PROVA 2: me target ==="
            xcodebuild \
              -workspace ManePro4K.xcworkspace \
              -target ManePro4K \
              -configuration Release \
              -sdk iphoneos \
              SYMROOT=build/Products \
              CODE_SIGNING_ALLOWED=NO \
              CODE_SIGNING_REQUIRED=NO \
              CODE_SIGN_IDENTITY="" \
              build 2>&1 | tee xcodebuild-target.log | tail -n 50
          fi

      - name: Paketo IPA-n (me verifikim te binaries)
        run: |
          set -euo pipefail
          APP="$(find build -type d -name 'ManePro4K.app' | head -1 || true)"
          if [ -z "$APP" ] || [ ! -f "$APP/ManePro4K" ]; then
            echo "❌ BINARJA MUNGGON — kompilimi deshtoi."
            exit 1
          fi
          echo "U gjet binarja ne: $APP"
          mkdir -p build/Payload
          cp -R "$APP" build/Payload/
          (cd build && zip -qry ../ManePro4K-1.9.0-unsigned.ipa Payload)
          echo "=== MADHESIA E IPA-SE (pritet: mbi 15 MB me VLC brenda) ==="
          du -h ManePro4K-1.9.0-unsigned.ipa

      - name: Shkruaj gabimet ne Summary (faqen e run-it)
        if: failure()
        run: |
          {
            echo "## ❌ Gabimet e kompilimit"
            echo '```'
            grep -B2 -A3 -iE "error:|warning: .*deprecated" xcodebuild.log xcodebuild-target.log 2>/dev/null | head -80 || tail -40 xcodebuild.log 2>/dev/null
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"

      - name: Publiko IPA ne Releases (shkarkim direkt)
        if: success()
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          TAG="v1.9.0-ipa"
          if gh release view "$TAG" -R "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
            gh release upload "$TAG" ManePro4K-1.9.0-unsigned.ipa --clobber -R "$GITHUB_REPOSITORY"
          else
            gh release create "$TAG" ManePro4K-1.9.0-unsigned.ipa \
              -R "$GITHUB_REPOSITORY" \
              --title "Mane Pro 4K v1.9.0 (iOS)" \
              --notes "IPA me motor VLC + AVPlayer (dubël si Android). E panenshkruar — nenshkruaje me TrollStore/Sideloadly."
          fi

      - name: Publiko statusin dhe gabimet ne repo
        if: always()
        run: |
          if compgen -G "*.ipa" > /dev/null; then
            SZ=$(du -h ManePro4K-1.9.0-unsigned.ipa | cut -f1)
            printf '# BUILD OK %s

IPA: %s
Shkarko: Releases -> v1.9.0-ipa (pa login)
' "$(date -u +%FT%TZ)" "$SZ" > BUILD-STATUS.md
          else
            {
              echo "# BUILD DESHTOI $(date -u +%FT%TZ)"
              echo
              echo '```'
              grep -h -iE "error:" xcodebuild.log xcodebuild-target.log 2>/dev/null | head -50
              echo '--- fundi i log-ut te provs 1 ---'
              tail -25 xcodebuild.log 2>/dev/null
              echo '```'
            } > BUILD-STATUS.md
          fi
          git config user.name "mane-ci"
          git config user.email "actions@users.noreply.github.com"
          git add BUILD-STATUS.md
          git commit -m "ci: status [skip ci]" >/dev/null 2>&1 || echo "(asgje per commit)"
          git push 2>&1 | tail -2 || true

      - name: Ngarko IPA-n per shkarkim
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ManePro4K-1.9.0-IPA
          path: |
            *.ipa
            xcodebuild.log
            xcodebuild-target.log
          if-no-files-found: warn
          retention-days: 30
```

</details>

### Hapi 4 — Shkarko IPA-n
1. Menu **Actions** (lart) → hap run-in e fundit **"Mane Pro 4K — Nderto IPA"**
2. Prit 10–20 minuta deri të bëhet jeshil ✓
3. Poshtë te seksioni **Artifacts** → shkarko **ManePro4K-1.9.0-IPA**
4. Hape zip-in → brenda ke **ManePro4K-1.9.0-unsigned.ipa** (+ log-u i ndërtimit)

### Hapi 5 — Nënshkruaj dhe instalo në iPhone
Apple KËRKON që çdo IPA të nënshkruhet përpara instalimit. Zgjidh një nga
3 rrugët më poshtë (Rruga A është më e lehta dhe falas).

---

## 🔧 Probleme të njohura & rregullime

| Problemi | Shpjegimi | Zgjidhja |
|---|---|---|
| **exit code 74** | `SWIFT_VERSION "5.9"` nuk ekziston (vlefshme: 4.0/4.2/5.0/6.0) — ndrequr në `project.yml` | Tashmë e rregulluar: `"5.0"` |
| **error code 1** (kompilimi) | 2 gabime Swift: `static let pink` ekziston tashmë në SwiftUI (ridëshmim i pavlefshëm) + izolimi `@MainActor` i AppStore bllokonte thirrjet nga player-i | Tashmë e rregulluar në `Sources/Theme.swift` + `Sources/Models.swift` |
| **IPA 27 KB (bosh)** | 2 skedarë të vjetër (Theme/Models) binin kompilimin, dhe workflow-i i vjetër e fshehte dështimin | Zëvendëso `Sources/Theme.swift` + `Sources/Models.swift` dhe workflow-in e ri verifikon binarën |
| **"future Xcode project file format (77)"** + **IPA bosh 27KB** + **exit 65** | **Shkaku rrënjësor:** XcodeGen 2.45+ vendos si parazgjedhje formatin e projektit Xcode 16 (objectVersion 77). Runner-i ka Xcode 15.4 → hapje e refuzuar (74) ose projekt i çformuar (IPA bosh / dështime 65) | **Zgjidhja zyrtare:** `projectFormat: xcode14_0` në `project.yml` → XcodeGen gjeneron format 56 të vërtetë me compatibilityVersion Xcode 14.0 |
| Paralajmërimi **"Node.js 20 is deprecated"** | Vetëm këshillë nga GitHub për mundësitë (actions) — nuk ndalon ndërtimin | Shpërfillje |
| Ndërtimi dështon përsëri | Hap run-in e kuq → hapi i kuq → lexo rreshtat me "error:", ose shkarko **Artifacts** (përmban `xcodebuild.log` të plotë) | Dërgoja screenshot-it ose tekstit të ndihmësit |

---

## 🔏 Nënshkrimi & instalimi — 3 rrugë

### 🥇 Rruga A — Sideloadly (FALAS, me Apple ID të thjeshtë)

1. Shkarko **Sideloadly** nga [sideloadly.io](https://sideloadly.io)
   (në Windows instalo edhe iTunes që PC-ja ta njohë iPhone-in)
2. Hap Sideloadly → zgjidh **ManePro4K-1.9.0-unsigned.ipa**
3. Lidh iPhone-in me kabllo → zgjidhe në Sideloadly
4. Vendos **Apple ID + fjalëkalimin** tënde
   - Nëse ke 2FA: krijo "App-Specific Password" te
     [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security
5. **Start** → në iPhone: **Settings → General → VPN & Device Management →
   Trust**

⚠️ Apple ID falas: app-i skadon çdo **7 ditë** (rihap Sideloadly dhe rifirmoje),
max 3 app me një Apple ID.

### 🥈 Rruga B — TrollStore (i PËRHERSHËM)

Për iPhone me iOS 14.0–16.6.1: instalim përjetë, pa skadencë, pa Apple ID.

### 🥉 Rruga C — Apple Developer $99/vit (nënshkrim automatik në GitHub)

1. Bli Apple Developer Program
2. Krijo certifikatë **Apple Distribution** → eksporto `.p12`
3. Krijo profil **Ad Hoc** me UDID-të e klientëve (max 100/vit)
4. GitHub → **Settings → Secrets and variables → Actions** → shto:

   | Emri i secret | Vlera |
   |---|---|
   | `SIGNING_CERT_P12_BASE64` | certifikata .p12 në base64 |
   | `SIGNING_CERT_PASSWORD` | fjalëkalimi i .p12 |
   | `PROVISIONING_PROFILE_BASE64` | profili .mobileprovision në base64 |

5. Commit → IPA firmoset automatikisht → **ManePro4K-1.9.0-signed.ipa**

Base64 në Windows PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12"))
```

> ⚠️ Mos përdor "cloud signer" të palëve të treta — Apple i revokon papritur.

---

## 🔄 Përditësime të ardhshme

Ndrysho çdo skedar në `Sources/` direkt në GitHub (lapsi ✏️) → Commit →
Actions ndërton automatikisht IPA-n e re.

## 📱 Përmbajtja e aplikacionit (identike me Android v1.9.0)

- Intro 5.5s — "Welcome To The Best IPTV Player Mane Pro 4K"
- Aktivizim VETËM me MAC nga paneli MANE (poll automatik 10s)
- MAC + token në **Keychain** — nuk ndryshojnë as pas fshirjes së app-it
- LIVE TV: kategoritë e panelit + kërkim + favorites (❤️)
- MOVIES / TV SERIES: posterë, më të rejat në fillim, epizoda sipas sezonave
- Player: HLS (m3u8) + rezervë TS brenda 14s + kanali PARA/PAS
- **Roja e panelit:** fshirë/skaduar në panel → bllokim automatik brenda 20 min
- "Skadon: [data]" + paralajmërimi 7 ditë para skadencës
- PA Logout, PA Connections — njësoj si Android
- Kërkon iOS 16+ (iPhone 8 e lart)

## 📁 Struktura e repositorit

```
├── .github/workflows/build-ipa.yml   ← ndërtuesi (Hapi 3)
├── Sources/                          ← 12 skedarë Swift (e gjithë logjika)
├── Assets.xcassets/                  ← ikonë e aplikacionit
├── scripts/sign.sh                   ← nënshkrimi (vetëm Rruga C)
├── project.yml                       ← konfigurimi i projektit Xcode
└── README.md
```

## 🔗 Paneli MANE

- Endpoint: `https://apkim.uk/mane-panel/api/device.php`
- POST: `mac`, `device_token`, `device_name`, `app_version`
- `pending` → prit shitësin | `active` + linjë → hapet app-i |
  `expired`/`disabled`/fshirë → bllokim automatik (roja 20 min)
- Çdo iPhone/iPad ka MAC-në e vet (`02:4D:41:4E:xx:xx`) — 1 kredit = 1 pajisje

## 🛠️ Për programuesin (nëse merr Mac një ditë)

```
brew install xcodegen
xcodegen generate
open ManePro4K.xcodeproj      # Xcode → zgjidh iPhone → Run
```
