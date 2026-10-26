# PokePvP Genesis — Smart Contract (BNB Chain)

ERC-721, 10,000 Monsters, metadata fully on-chain (images from https://pokepvp.fun).

| Phase | Price | Max per wallet | Function |
|---|---|---|---|
| Free Mint | 0.0005 BNB | 10 | `freeMint(qty)` |
| Public Mint | 0.002 BNB | 20 | `publicMint(qty)` |
| Agent Mint | 0.0005 BNB | 10 (wallet must hold a .ai Agent ID) | `agentMint(qty)` |

Agent ID check: `balanceOf(wallet) > 0` on SPACE ID Agent ID registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`.

Views: `quote(phase, qty)`, `remaining(phase, wallet)`, `hasAgentId(wallet)`, `monsterOf(tokenId)`, `totalMinted()`.
Phase ids: 0 = Free, 1 = Public, 2 = Agent. All phases start CLOSED.

## Deploy with Remix
1. Open https://remix.ethereum.org, create `PokePvPGenesis.sol`, paste the file.
2. Solidity Compiler: version 0.8.24, Optimization ON (200), EVM version `paris`. Compile.
3. Deploy & Run: Environment = Injected Provider (MetaMask / Binance Wallet / OKX) on BNB Smart Chain (chainId 56). Keep ~0.02 BNB for gas. Deploy `PokePvPGenesis`.
4. Open mints: `setOpen(0,true)`, `setOpen(1,true)`, `setOpen(2,true)`.
5. Verify on BscScan (Single file, 0.8.24, optimizer 200, paris) — or flatten in Remix first.
6. Withdraw proceeds anytime: `withdraw(yourAddress)`.

Note: the Monster draw is pseudo-random (prevrandao + blockhash); fine for a fun collection, not tamper-proof.
