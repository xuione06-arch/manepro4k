# 🍎 Mane Pro 4K v1.9.0 — IPA e ndërtuar në GitHub (pa Mac!)

Ky repositor **ndërton aplikacionin iOS Mane Pro 4K në cloud-in e GitHub-it**
(Mac virtual falas) dhe të jep skedarin **.IPA** për instalim në iPhone/iPad.

**Nuk të duhet: Mac ✗ Xcode ✗ Apple Developer (për ndërtim) ✗**

> **E rëndësishme:** repositori duhet të jetë **Public** — ndërtimi në Mac
> virtual të GitHub-it është **falas dhe i pakufizuar VETËM për repo publike**.
> (Në repo private, minutat macOS konsumohen 10x më shpejt.)

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
   - skedarin `.gitignore` (nëse s'shfaqet dot, nuk është problem)
3. **Commit changes**

### Hapi 3 — Krijo workflow-in e ndërtimit
1. **Add file → Create new file**
2. Shkruaj emrin SAKTËSISHT kështu (pika në fillim është e detyrueshme; slash-et
   krijojnë dosjet automatikisht):

   ```
   .github/workflows/build-ipa.yml
   ```

3. Kopjo gjithë përmbajtjen nga blloku më poshtë → **Commit changes**

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
    steps:
      - name: Marr kodin
        uses: actions/checkout@v4

      - name: Instalo XcodeGen
        run: brew install xcodegen

      - name: Gjenero projektin Xcode
        run: xcodegen generate

      - name: Nderto aplikacionin (Release, pa nenshkrim)
        run: |
          set -o pipefail
          xcodebuild \
            -project ManePro4K.xcodeproj \
            -scheme ManePro4K \
            -configuration Release \
            -sdk iphoneos \
            -destination 'generic/platform=iOS' \
            -derivedDataPath build/DD \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" \
            build 2>&1 | tail -n 120

      - name: Paketo IPA-n (e panenshkruar)
        run: |
          mkdir -p build/Payload
          cp -R "build/DD/Build/Products/Release-iphoneos/ManePro4K.app" build/Payload/
          cd build
          zip -qry ../ManePro4K-1.9.0-unsigned.ipa Payload
          cd ..
          ls -lh *.ipa

      - name: Nenshkruaj IPA-n (opsionale — vetem me secrets te certifikates)
        env:
          SIGNING_CERT_P12_BASE64: ${{ secrets.SIGNING_CERT_P12_BASE64 }}
          SIGNING_CERT_PASSWORD: ${{ secrets.SIGNING_CERT_PASSWORD }}
          PROVISIONING_PROFILE_BASE64: ${{ secrets.PROVISIONING_PROFILE_BASE64 }}
        run: bash scripts/sign.sh

      - name: Ngarko IPA-n per shkarkim
        uses: actions/upload-artifact@v4
        with:
          name: ManePro4K-1.9.0-IPA
          path: "*.ipa"
          if-no-files-found: error
```

</details>

### Hapi 4 — Shkarko IPA-n
1. Menu **Actions** (lart) → hap run-in e fundit **"Mane Pro 4K — Nderto IPA"**
2. Prit 10–20 minuta deri të bëhet jeshil ✓
3. Poshtë te seksioni **Artifacts** → shkarko **ManePro4K-1.9.0-IPA**
4. Hape zip-in → brenda ke **ManePro4K-1.9.0-unsigned.ipa**

### Hapi 5 — Nënshkruaj dhe instalo në iPhone
Apple KËRKON që çdo IPA të nënshkruhet përpara instalimit. Zgjidh një nga
3 rrugët më poshtë (Rruga A është më e lehta dhe falas).

---

## 🔏 Nënshkrimi & instalimi — 3 rrugë

### 🥇 Rruga A — Sideloadly (FALAS, me Apple ID të thjeshtë)

Instalon app-in në iPhone me Apple ID-në tënde të zakonshme — pa paguar asgjë.

1. Shkarko **Sideloadly** nga [sideloadly.io](https://sideloadly.io)
   (punon në Windows, Mac dhe Linux — në Windows instalo edhe iTunes
   që PC-ja ta njohë iPhone-in)
2. Hap Sideloadly → zgjidh **ManePro4K-1.9.0-unsigned.ipa**
3. Lidh iPhone-in me kabllo → zgjidhe në Sideloadly
4. Vendos **Apple ID + fjalëkalimin** tënde
   - Nëse ke aktivizuar 2FA (dy hapësh), krijo një "App-Specific Password":
     shko te [appleid.apple.com](https://appleid.apple.com) → Sign-In and
     Security → App-Specific Passwords
5. Kliko **Start** → prit 1–2 minuta
6. Në iPhone: **Settings → General → VPN & Device Management** → kliko
   Apple ID-në tënde → **Trust**

⚠️ **Kufizimet e Apple ID falas:** aplikacioni skadon çdo **7 ditë** (pastaj
hape Sideloadly dhe rifirmoje — 2 minuta) dhe maksimumi është 3 app të
instaluara njëkohësisht me një Apple ID.

### 🥈 Rruga B — TrollStore (i PËRHERSHËM, pa skadencë)

Nëse iPhone/iPad ka version iOS 14.0–16.6.1 (ose disa 17.0 beta):
instalimi me TrollStore është **përjetë** — pa 7 ditë, pa ri-firmim, pa Apple ID.
Kontrollo listën e versioneve të mbështetura në faqen e TrollStore.

### 🥉 Rruga C — Apple Developer $99/vit (nënshkrim i PLOTË automatik në GitHub)

Për biznes: IPA firmoset **automatikisht në GitHub** dhe hyn pa problem:

1. Bli Apple Developer Program ([developer.apple.com](https://developer.apple.com))
2. Krijo certifikatë **Apple Distribution** → eksporto `.p12` me fjalëkalim
3. Krijo profil **Ad Hoc** me UDID-të e klientëve (maks 100 pajisje/vit)
4. Në GitHub: **Settings → Secrets and variables → Actions → New repository secret**:

   | Emri i secret | Vlera |
   |---|---|
   | `SIGNING_CERT_P12_BASE64` | certifikata .p12 e kthyer në base64 |
   | `SIGNING_CERT_PASSWORD` | fjalëkalimi i .p12 |
   | `PROVISIONING_PROFILE_BASE64` | profili .mobileprovision në base64 |

5. Bëj një commit → workflow-i ndërton dhe firmos vetë → shkarkon
   **ManePro4K-1.9.0-signed.ipa** (1 vit pa skadencë, TestFlight i mundshëm)

Base64 në Windows PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12"))
```
Base64 në Mac/Linux:
```bash
base64 -i cert.p12 | pbcopy     # Mac
base64 -w 0 cert.p12            # Linux
```

> ⚠️ **Kujdes:** mos përdor "cloud signer" të palëve të treta (ESign, SignStore,
> farm-certifikata etj.) — Apple i revokon papritur dhe klientët mbeten pa app.
> Për biznes, Rruga A (Sideloadly me Apple ID të klientit) ose Rruga C janë
> të sigurta.

---

## 🔄 Përditësime të ardhshme (p.sh. v1.9.1)

Ndrysho çdo skedar në `Sources/` direkt në GitHub (kliko lapsin ✏️) → Commit
→ Actions ndërton automatikisht IPA-n e re. Kaq!

---

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
- **Kërkon iOS 16+** (iPhone 8 e lart). Për iPhone më të vjetër ke Web-App-in.

---

## 📁 Struktura e repositorit

```
├── .github/workflows/build-ipa.yml   ← ndërtuesi (krijoje me Hapin 3)
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
