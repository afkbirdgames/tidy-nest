# Security

## Official downloads

Tidy Nest is only published on this repository's [Releases page](https://github.com/afkbirdgames/tidy-nest/releases). Copies on other sites, or sent to you by someone else, aren't official and may have been tampered with.

Each release includes `SHA256SUMS.txt`. To check a download on Windows, open PowerShell in the download folder and run:

```
Get-FileHash .\tidynest-<version>.jar -Algorithm SHA256
```

The result must match the line for that file in `SHA256SUMS.txt`. The included updater does this check for you automatically.

## Signed releases

Every jar is signed by afkbird, with the same key as afkbird's other mods. The signature is attached to each release as `tidynest-<version>.jar.sig`, and the public key is [`updater/release-signing-key.pem`](updater/release-signing-key.pem).

* The **updater** checks the signature before installing anything. A jar without afkbird's signature is refused, even if it appears on this Releases page, so a stolen account or upload can't push a fake jar to players.
* To check a jar by hand with OpenSSL (included with Git for Windows):

  ```
  openssl base64 -d -in tidynest-<version>.jar.sig -out jar.sig.bin
  openssl dgst -sha256 -verify release-signing-key.pem -signature jar.sig.bin tidynest-<version>.jar
  ```

  It must print `Verified OK`.

## The in-game update notice

When the game or a server starts, the mod asks GitHub's public API for the newest release's version number. If it's newer, the mod shows a notice telling you to update. That is the mod's only internet access. It downloads nothing, runs nothing, and shows only text built into the mod. To turn it off, set `"check_for_updates": false` in `config/tidynest.json`.

## What the mod sends to servers

When the server has Tidy Nest, pressing sort sends one small message: which screen is open and which grid to sort. The server checks everything itself (that the screen is still open, that it's a grid that can be sorted, and that no item is gained or lost) and ignores repeated requests within a few ticks. Without Tidy Nest on the server, the mod only makes ordinary inventory clicks.

## Reporting a problem

If you find a security problem in the mod or the updater, such as a way to crash servers, duplicate or delete items, or run unwanted code, please **don't open a public issue**. Report it privately from this repository's **Security** tab with **Report a vulnerability**. Include the mod version and the steps to reproduce it.
