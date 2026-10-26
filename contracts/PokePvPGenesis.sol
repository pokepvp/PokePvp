// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    PokePvP Genesis — Monster NFTs on BNB Chain (chainId 56)
    Website: https://pokepvp.fun

    Three mint phases, all minted to the calling wallet:
      Free Mint   : 0.0005 BNB each, max 10 per wallet
      Public Mint : 0.002  BNB each, max 20 per wallet
      Agent Mint  : 0.0005 BNB each, max 10 per wallet holding a .ai Agent ID
                    (SPACE ID Agent ID registry, Binance Agentic Wallet)

    Each token is one of 10 Monsters, drawn at mint:
      Common 01-04 (60%), Rare 05-07 (28%), Epic 08-09 (10%), Legendary 10 (2%)
    Metadata is generated fully on-chain; images are served from imageBase.

    Fan concept. Not affiliated with Nintendo, Game Freak, The Pokemon Company,
    Binance or SPACE ID.
*/

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract PokePvPGenesis is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    enum Phase { Free, Public, Agent }

    // ----- config -----
    uint256 public constant MAX_SUPPLY = 10_000;

    /// SPACE ID Agent ID registry (ERC-721) on BNB Chain mainnet.
    address public agentIdRegistry = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    uint256 public freePrice   = 0.0005 ether;
    uint256 public publicPrice = 0.002 ether;
    uint256 public agentPrice  = 0.0005 ether;

    uint256 public freeMaxPerWallet   = 10;
    uint256 public publicMaxPerWallet = 20;
    uint256 public agentMaxPerWallet  = 10;

    bool public freeOpen;
    bool public publicOpen;
    bool public agentOpen;

    string public imageBase = "https://pokepvp.fun/";

    // ----- state -----
    uint256 public totalMinted;
    mapping(address => uint256) public freeMinted;
    mapping(address => uint256) public publicMinted;
    mapping(address => uint256) public agentMinted;
    mapping(uint256 => uint8) public monsterOf; // 1..10

    string[10] private _names = ["Ember","Tide","Sprout","Volt","Stone","Gale","Frost","Shade","Fang","Wyrm"];
    string[10] private _files = [
        "m01-ember.png","m02-tide.png","m03-sprout.png","m04-volt.png","m05-stone.png",
        "m06-gale.png","m07-frost.png","m08-shade.png","m09-fang.png","m10-wyrm.png"
    ];
    string[10] private _types = ["Fire","Water","Grass","Electric","Rock","Wind","Ice","Shadow","Fighting","Dragon"];

    // ----- events / errors -----
    event Minted(address indexed to, uint256 indexed tokenId, uint8 monster, Phase phase);
    event PhaseOpen(Phase phase, bool open);

    error MintClosed();
    error BadQuantity();
    error SoldOut();
    error WalletLimit();
    error NoAgentId();
    error Underpaid(uint256 required);
    error RefundFailed();

    constructor() ERC721("PokePvP Genesis", "POKEPVP") Ownable(msg.sender) {}

    // =========================================================
    //                         MINT
    // =========================================================

    function freeMint(uint256 quantity) external payable nonReentrant {
        if (!freeOpen) revert MintClosed();
        _checkQty(quantity, freeMinted[msg.sender], freeMaxPerWallet);
        freeMinted[msg.sender] += quantity;
        _mintBatch(quantity, freePrice, Phase.Free);
    }

    function publicMint(uint256 quantity) external payable nonReentrant {
        if (!publicOpen) revert MintClosed();
        _checkQty(quantity, publicMinted[msg.sender], publicMaxPerWallet);
        publicMinted[msg.sender] += quantity;
        _mintBatch(quantity, publicPrice, Phase.Public);
    }

    /// Only wallets holding a .ai Agent ID (Binance Agentic Wallet) can call this.
    function agentMint(uint256 quantity) external payable nonReentrant {
        if (!agentOpen) revert MintClosed();
        if (!hasAgentId(msg.sender)) revert NoAgentId();
        _checkQty(quantity, agentMinted[msg.sender], agentMaxPerWallet);
        agentMinted[msg.sender] += quantity;
        _mintBatch(quantity, agentPrice, Phase.Agent);
    }

    // =========================================================
    //                         VIEWS
    // =========================================================

    function hasAgentId(address wallet) public view returns (bool) {
        if (agentIdRegistry == address(0)) return false;
        try IERC721(agentIdRegistry).balanceOf(wallet) returns (uint256 bal) {
            return bal > 0;
        } catch {
            return false;
        }
    }

    /// Exact BNB (wei) to send for `quantity` in `phase`.
    function quote(Phase phase, uint256 quantity) external view returns (uint256) {
        return _priceOf(phase) * quantity;
    }

    /// How many more `wallet` can mint in `phase`.
    function remaining(Phase phase, address wallet) external view returns (uint256) {
        uint256 used;
        uint256 cap;
        if (phase == Phase.Free) { used = freeMinted[wallet]; cap = freeMaxPerWallet; }
        else if (phase == Phase.Public) { used = publicMinted[wallet]; cap = publicMaxPerWallet; }
        else {
            if (!hasAgentId(wallet)) return 0;
            used = agentMinted[wallet]; cap = agentMaxPerWallet;
        }
        uint256 left = used >= cap ? 0 : cap - used;
        uint256 supplyLeft = MAX_SUPPLY - totalMinted;
        return left < supplyLeft ? left : supplyLeft;
    }

    function rarityOf(uint8 monster) public pure returns (string memory) {
        if (monster <= 4) return "Common";
        if (monster <= 7) return "Rare";
        if (monster <= 9) return "Epic";
        return "Legendary";
    }

    /// Squad weight of a Monster: Common 1, Rare 2, Epic 4, Legendary 10.
    function weightOf(uint8 monster) public pure returns (uint256) {
        if (monster <= 4) return 1;
        if (monster <= 7) return 2;
        if (monster <= 9) return 4;
        return 10;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint8 m = monsterOf[tokenId];
        uint256 i = uint256(m) - 1;
        string memory json = string.concat(
            '{"name":"PokePvP Genesis #', tokenId.toString(), ' - ', _names[i],
            '","description":"A Genesis Monster from PokePvP. Bond ten into a Squad and enter the arena. https://pokepvp.fun",',
            '"image":"', imageBase, _files[i], '",',
            '"external_url":"https://pokepvp.fun",',
            '"attributes":[',
                '{"trait_type":"Monster","value":"', _names[i], '"},',
                '{"trait_type":"Type","value":"', _types[i], '"},',
                '{"trait_type":"Rarity","value":"', rarityOf(m), '"},',
                '{"trait_type":"Glyph","value":"', uint256(m).toString(), '"},',
                '{"display_type":"number","trait_type":"Squad Weight","value":', weightOf(m).toString(), '}',
            ']}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    // =========================================================
    //                         OWNER
    // =========================================================

    function setOpen(Phase phase, bool open) external onlyOwner {
        if (phase == Phase.Free) freeOpen = open;
        else if (phase == Phase.Public) publicOpen = open;
        else agentOpen = open;
        emit PhaseOpen(phase, open);
    }

    function setPrices(uint256 free_, uint256 public_, uint256 agent_) external onlyOwner {
        freePrice = free_; publicPrice = public_; agentPrice = agent_;
    }

    function setLimits(uint256 free_, uint256 public_, uint256 agent_) external onlyOwner {
        freeMaxPerWallet = free_; publicMaxPerWallet = public_; agentMaxPerWallet = agent_;
    }

    function setAgentIdRegistry(address registry) external onlyOwner {
        agentIdRegistry = registry;
    }

    function setImageBase(string calldata base) external onlyOwner {
        imageBase = base;
    }

    /// Team / giveaway mint, free, no wallet limit.
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        if (quantity == 0) revert BadQuantity();
        if (totalMinted + quantity > MAX_SUPPLY) revert SoldOut();
        for (uint256 k; k < quantity; ++k) _mintOne(to, Phase.Free);
    }

    function withdraw(address payable to) external onlyOwner {
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }

    // =========================================================
    //                        INTERNAL
    // =========================================================

    function _priceOf(Phase phase) internal view returns (uint256) {
        if (phase == Phase.Free) return freePrice;
        if (phase == Phase.Public) return publicPrice;
        return agentPrice;
    }

    function _checkQty(uint256 quantity, uint256 used, uint256 cap) internal view {
        if (quantity == 0) revert BadQuantity();
        if (used + quantity > cap) revert WalletLimit();
        if (totalMinted + quantity > MAX_SUPPLY) revert SoldOut();
    }

    function _mintBatch(uint256 quantity, uint256 unitPrice, Phase phase) internal {
        uint256 cost = unitPrice * quantity;
        if (msg.value < cost) revert Underpaid(cost);
        for (uint256 k; k < quantity; ++k) _mintOne(msg.sender, phase);
        uint256 extra = msg.value - cost;
        if (extra > 0) {
            (bool ok, ) = payable(msg.sender).call{value: extra}("");
            if (!ok) revert RefundFailed();
        }
    }

    function _mintOne(address to, Phase phase) internal {
        uint256 tokenId = ++totalMinted; // ids start at 1
        uint8 m = _draw(tokenId, to);
        monsterOf[tokenId] = m;
        _safeMint(to, tokenId);
        emit Minted(to, tokenId, m, phase);
    }

    /// Pseudo-random draw. Fine for a fun collection; not secure against
    /// validators or contracts that revert unfavourable mints.
    function _draw(uint256 tokenId, address to) internal view returns (uint8) {
        uint256 r = uint256(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), to, tokenId))) % 100;
        if (r < 60) return uint8(1 + (r % 4));            // Common 1-4
        if (r < 88) return uint8(5 + ((r - 60) % 3));     // Rare 5-7
        if (r < 98) return uint8(8 + ((r - 88) % 2));     // Epic 8-9
        return 10;                                        // Legendary
    }

    receive() external payable {}
}
