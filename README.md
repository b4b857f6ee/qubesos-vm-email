# QubesOS DNS Filter v2.0

DNS filtering for QubesOS with strict network compartmentalization. Each VM can only access whitelisted domains.

## Features

- **14 pre-configured profiles** - Email, Banking, Shopping, Social, Media, and more
- **French services included** - Banques FR, impôts, CAF, SNCF, presse française...
- **Local DNS filtering** - Each VM runs dnsmasq with whitelist
- **DoH blocking** - Firefox policies + DNS blocking
- **Immutable configs** - Protected with `chattr +i`
- **DispVM & AppVM support**
- **Multi-language** - Works with Bureau, Desktop, Escritorio...

## Available Profiles

| Profile | Services |
|---------|----------|
| **email** | Gmail, Outlook, ProtonMail |
| **social** | Facebook, Instagram, Twitter, LinkedIn, Discord, Reddit |
| **work** | Slack, Teams, Notion, Zoom, Figma, Trello |
| **drive** | Google Drive, OneDrive, Dropbox, Proton Drive, Synology |
| **banking** | Banques FR, PayPal, Lydia, N26, Revolut |
| **crypto** | Binance, Kraken, Coinbase, Ledger, MetaMask |
| **gov** | Impôts, CAF, Ameli, ANTS, France Connect |
| **health** | Doctolib, Ameli, mutuelles, pharmacies |
| **shopping** | Amazon, Fnac, Cdiscount, Leboncoin, LDLC |
| **travel** | SNCF, Booking, Airbnb, Air France, BlaBlaCar |
| **media** | Netflix, YouTube, Spotify, Twitch, Disney+, Canal+ |
| **news** | Le Monde, Le Figaro, BFM, Numerama, 01net |
| **admin** | GitHub, OVH, Cloudflare, AWS, Docker |
| **ai** | ChatGPT, Claude, Mistral, Gemini, Midjourney |

## Quick Start

```bash
cd ~/Downloads
unzip qubes-dns-filter.zip
cd qubes-dns-filter
./setup.sh
```

Follow the interactive prompts to select profiles and services.

## Drive Sync VM (Client lourd)

Pour une VM avec **clients lourds** et **stockage persistant** (Proton Drive, Synology Drive, Dropbox, rclone...) :

```bash
./setup-drive-sync.sh
```

Features:
- Stockage configurable (50 GB à 1 TB+)
- Clients installés: Proton Drive, Synology Drive, Dropbox, Nextcloud, MEGA
- rclone pré-configuré pour Google Drive / OneDrive
- Dossiers de sync dans `/home/user/Sync/`
- Autostart des services

## Messaging VM (Messageries instantanées)

Pour une VM dédiée aux **messageries chiffrées** avec les clients installés :

```bash
./setup-messaging.sh
```

Applications disponibles:
- **Privacy-focused**: Signal, Element/Matrix, Session, Olvid, Threema, Wire, Briar, SimpleX, Jami
- **Popular**: Telegram, WhatsApp (web), Discord, Slack, Skype

Features:
- Clients natifs Linux installés
- Intégration au menu Qubes (lancer directement Signal, Telegram, etc.)
- DNS filtré: uniquement les domaines des messageries autorisés
- Recommandations de sécurité incluses

## Usage

```bash
# DispVM
qvm-run --dispvm=dvm-banking firefox

# AppVM
qvm-run banking firefox

# Test filtering
qvm-run banking 'getent hosts wikipedia.org'      # Blocked: 0.0.0.0
qvm-run banking 'getent hosts boursorama.com'     # Works: real IP
```

## Customization

Add domains to `lib/config/services/<profile>.conf`:

```
server=/mybank.fr/9.9.9.9
server=/www.mybank.fr/9.9.9.9
```

Then re-run `./setup.sh`.

## Project Structure

```
qubes-dns-filter/
├── setup.sh                    # Main interactive script
├── lib/
│   ├── common.sh              # Utility functions
│   ├── cleanup.sh             # VM cleanup
│   ├── template.sh            # Template creation
│   └── config/
│       ├── base.conf          # Base dnsmasq config
│       ├── firefox.json       # Firefox DoH policies
│       └── services/          # Service whitelists
│           ├── gmail.conf
│           ├── banking-fr.conf
│           ├── shopping-fr.conf
│           └── ...
```

## Security

- All domains blocked by default (`address=/#/0.0.0.0`)
- Only whitelisted domains forwarded to Quad9 (9.9.9.9)
- DoH disabled and locked in Firefox
- Config files immutable (chattr +i)
- **Block in existing VMs**: Specialized domains can be blocked in your existing QubesOS VMs

### Block Domains in Existing VMs

After creating specialized VMs (email, banking, etc.), the script offers to block those domains in your existing QubesOS VMs like `work`, `personal`, `untrusted`.

Example workflow:
1. You create a `banking` VM with Boursorama, BNP, PayPal
2. Script asks: "Block these domains in existing VMs?"
3. You select: `work`, `personal`
4. Result: `work` and `personal` keep full internet access BUT cannot access banking sites

This ensures true compartmentalization: your banking is ONLY accessible from the `banking` VM.

## License

MIT License
