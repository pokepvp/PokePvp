# Security Policy

## Supported Versions

This project ships as a single static `index.html`. There are no versioned
releases yet — the `main` branch is always the actively supported version.

| Branch | Supported |
| ------ | --------- |
| main   | ✅        |

## Reporting a Vulnerability

If you discover a security vulnerability (e.g. an XSS vector, unsafe wallet
interaction, or a way to manipulate match/battle state client-side in a way
that affects other players), please **do not open a public issue**.

Instead:

1. Open a **private security advisory** via the repository's "Security"
   tab → "Report a vulnerability", or
2. Email the maintainer directly (add your contact email here).

Please include:

- A clear description of the vulnerability
- Steps to reproduce
- Potential impact (e.g. wallet risk, data exposure, gameplay exploit)

We aim to acknowledge reports within **72 hours** and to provide a fix or
mitigation plan as quickly as possible given this is a community project.

## Wallet Safety Note

PokePvP Cyber Arena integrates with browser wallets (e.g. Solana). Never share
your seed phrase or private key with this app or anyone claiming to represent
this project — legitimate wallet connections only ever request a public
address/signature approval.
