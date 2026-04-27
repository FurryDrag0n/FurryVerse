# SSTORE2 Mint — User Guide

A single‑file minting interface for the SSTORE2‑based NFT contract.

## Prerequisites

- **Approved minter** – ask the contract owner to call `approveMinter(yourAddress)`.
- **Wallet** – either MetaMask (browser extension) or a private key / mnemonic.
- **RPC URL** (manual mode only) – e.g., `https://rpc.sepolia.org` for testnet.
- **Contract address** – the deployed FurryVerse (or similar) contract.

> **Warning:** This is a testing interface. Extensive testing on testnet is strongly advised before mainnet use. Uploading data beyond limits may result in lost funds.

## How to Use

1. **Open the HTML file** in a modern browser (Chrome/Firefox).  
   No server needed – just double‑click it.

2. **Choose authentication mode**:
   - *MetaMask* – connect your wallet.
   - *Manual key* – paste private key (hex) or 12/24‑word seed phrase and provide an RPC URL.

3. **Fill in the metadata**:
   - `Contract address`: the NFT contract (0x…).
   - `Name`: token name (e.g., “My Art #1”).
   - `Description`: free text.
   - `Image`: select an image file (PNG, JPEG, WebP, etc.).

4. **Click “Mint”**.  
   A confirmation dialog will appear – read the warning and confirm.

5. The process:
   - Creates a token via `initToken()`.
   - Uploads the entire metadata (as a percent‑encoded data URI) in chunks of ≤ 24 575 bytes.
   - Seals the token with `sealToken()`.

6. **Monitor the log** – transactions will appear as they are sent.

## Recommendations

- **Keep total metadata under 144 kB** (~6 chunks) for reliable display on marketplaces.
- **Test on testnet first** (use Sepolia, Goerli) before minting on mainnet.
- To reduce size, consider converting images to WebP or shrinking dimensions before upload.

## Troubleshooting

- “Not approved” → you are not an approved minter. Contact the contract owner.
- “WriteError” during chunk upload → chunk too big (≤24 575 bytes allowed).
- “Out of gas” → increase gas limit (manual mode) or use a smaller image.
