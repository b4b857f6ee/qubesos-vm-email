# QubesOS DNS Filter

A modular DNS filtering solution for QubesOS that restricts network access to whitelisted domains only. Perfect for creating isolated VMs dedicated to specific tasks like email or cloud storage.

## Features

- **Local DNS filtering** - Each VM runs its own dnsmasq instance with a whitelist
- **DoH blocking** - Prevents DNS-over-HTTPS bypass (Firefox policies + DNS blocking)
- **Immutable configs** - All configurations are protected with `chattr +i`
- **DispVM support** - Create disposable VMs that reset on shutdown
- **Modular design** - Easy to customize and extend with new profiles
- **Interactive setup** - Numbered menus, multi-select cleanup, no manual typing
- **Multi-language support** - Works with localized desktop folders (Bureau, Desktop, Escritorio, etc.)

## Architecture

```
┌─────────────────────────────────────────┐
│              QubesOS dom0               │
└─────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌──────────┐
│ email  │    │  drive   │    │  custom  │
│  VM    │    │   VM     │    │   VM     │
├────────┤    ├──────────┤    ├──────────┤
│dnsmasq │    │ dnsmasq  │    │ dnsmasq  │
│127.0.0.1│   │127.0.0.1 │    │127.0.0.1 │
├────────┤    ├──────────┤    ├──────────┤
│Gmail   │    │G. Drive  │    │ Your     │
│Outlook │    │OneDrive  │    │ domains  │
│Proton  │    │Dropbox   │    │          │
└────────┘    └──────────┘    └──────────┘
```

Each VM has:
- Local dnsmasq listening on `127.0.0.1:53`
- Whitelist of allowed domains
- All other domains blocked (return `0.0.0.0`)
- Firefox with DoH disabled and locked

## Installation

### Prerequisites

- QubesOS 4.x
- A Fedora or Debian based template

### Quick Start

1. Download and extract in dom0:

```bash
# Download the zip file to dom0
cd ~/Downloads
unzip qubes-dns-filter.zip
cd qubes-dns-filter
```

2. Run the setup:

```bash
./setup.sh
```

3. Follow the interactive prompts:
   - Select base template
   - Choose profiles (Email, Drive, or Both)
   - Choose VM types (DispVM, AppVM, or Both)

## Usage

### Launch Email DispVM

From Qubes menu: `dvm-email` → `Firefox`

Or from terminal:
```bash
qvm-run --dispvm=dvm-email firefox
```

### Launch Drive DispVM

From Qubes menu: `dvm-drive` → `Firefox`

Or from terminal:
```bash
qvm-run --dispvm=dvm-drive firefox
```

### Test Filtering

```bash
# Should be blocked (returns 0.0.0.0)
qvm-run email 'getent hosts wikipedia.org'
# Output: 0.0.0.0    wikipedia.org

# Should work (returns real IPs)
qvm-run email 'getent hosts mail.google.com'
# Output: 142.250.x.x    mail.google.com
```

## Profiles

### Email Profile

Allows access to:
- **Gmail/Google** - mail.google.com, accounts.google.com, etc.
- **Outlook/Microsoft** - outlook.com, login.live.com, etc.
- **ProtonMail** - proton.me, mail.proton.me, etc.

### Drive Profile

Allows access to:
- **Google Drive** - drive.google.com, docs.google.com, etc.
- **OneDrive** - onedrive.com, sharepoint.com, etc.
- **Dropbox** - dropbox.com, dropboxusercontent.com, etc.

## Customization

### Add Domains to Existing Profile

Edit the config file:

```bash
nano lib/config/email.conf
```

Add new domains at the end:

```
# My custom addition
server=/example.com/9.9.9.9
server=/api.example.com/9.9.9.9
```

Then recreate the template:

```bash
./setup.sh
```

### Create a New Profile

1. Copy an existing config:

```bash
cp lib/config/email.conf lib/config/banking.conf
```

2. Edit the whitelist:

```bash
nano lib/config/banking.conf
```

3. Update `setup.sh` to add the new profile option in the menu.

## Project Structure

```
qubes-dns-filter/
├── setup.sh                    # Main script (interactive menu)
├── lib/
│   ├── common.sh              # Colors, utility functions
│   ├── cleanup.sh             # VM deletion with multi-select
│   ├── template.sh            # Template creation logic
│   └── config/
│       ├── email.conf         # Email whitelist (dnsmasq)
│       ├── drive.conf         # Drive whitelist (dnsmasq)
│       └── firefox.json       # Firefox DoH policies
```

| File | Purpose |
|------|---------|
| `setup.sh` | Main entry point, menus |
| `lib/common.sh` | Shared functions (colors, VM utils) |
| `lib/cleanup.sh` | Interactive VM deletion |
| `lib/template.sh` | Template creation logic |
| `lib/config/*.conf` | dnsmasq whitelists |
| `lib/config/firefox.json` | Firefox policies |

## Security Features

### DNS Filtering

- All domains blocked by default (`address=/#/0.0.0.0`)
- Only whitelisted domains are forwarded to upstream DNS (Quad9)
- Uses `no-resolv` to prevent reading system DNS

### DoH Prevention

**DNS level:**
- Blocks known DoH providers (Cloudflare, Google, Quad9, etc.)

**Firefox level:**
- `network.trr.mode = 5` (disabled)
- `DNSOverHTTPS.Enabled = false`
- `DNSOverHTTPS.Locked = true`
- All settings locked (cannot be changed by user)

### Immutable Configs

All critical files are protected:

```bash
chattr +i /etc/dnsmasq.d/email-filter.conf
chattr +i /etc/resolv.conf
chattr +i /etc/firefox/policies/policies.json
```

Users cannot modify DNS settings, even with root access in AppVM.

## Troubleshooting

### DNS Not Working

1. Check dnsmasq is running:
```bash
qvm-run -u root <vm> 'systemctl status dnsmasq'
```

2. Check resolv.conf:
```bash
qvm-run <vm> 'cat /etc/resolv.conf'
# Should show: nameserver 127.0.0.1
```

3. Check nsswitch.conf:
```bash
qvm-run <vm> 'grep hosts /etc/nsswitch.conf'
# Should show: hosts: files dns myhostname
# Should NOT contain: resolve
```

### Domain Not Accessible

1. Test DNS resolution:
```bash
qvm-run <vm> 'getent hosts example.com'
```

2. If blocked (returns 0.0.0.0), add domain to whitelist in `lib/config/<profile>.conf`

3. Recreate the template:
```bash
./setup.sh
```

### VM Creation Fails

If you see "Got empty response from qubesd":

1. Wait a moment and retry
2. Check template is fully shutdown:
```bash
qvm-ls <template-name>
```

## Upstream DNS

By default, whitelisted domains are resolved via [Quad9](https://quad9.net/):
- `9.9.9.9`
- `149.112.112.112`

To change, edit the `server=` lines at the top of the config files.

## License

MIT License - Feel free to use and modify.

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Ideas for contributions:
- New profiles (banking, social media, etc.)
- Support for other browsers (Chromium)
- GUI for domain management
