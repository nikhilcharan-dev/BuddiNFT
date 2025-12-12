// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Uses OpenZeppelin ERC721 + Ownable + Pausable
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title NftCollection - ERC721 with maxSupply, owner-only minting, baseURI, pause, burn
contract NftCollection is ERC721, Ownable, Pausable {
    using Counters for Counters.Counter;

    // maximum number of tokens allowed
    uint256 public immutable maxSupply;

    // total minted tokens (including burned ones if you want separate counters; here we decrement on burn)
    Counters.Counter private _totalSupply;

    // Base URI for token metadata (base + tokenId)
    string private _baseTokenURI;

    // Track minted tokenIds to prevent double-mint explicitly (optional: if relying on ownerOf existence)
    mapping(uint256 => bool) private _minted;

    error ZeroAddress();
    error MaxSupplyReached();
    error TokenAlreadyMinted(uint256 tokenId);
    error TokenDoesNotExist(uint256 tokenId);
    error NotTokenOwnerOrApproved();

    event BaseURIUpdated(string newBaseURI);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        require(maxSupply_ > 0, "maxSupply must be > 0");
        maxSupply = maxSupply_;
        _baseTokenURI = baseURI_;
    }

    /// @notice Read current total supply (number of tokens in circulation)
    function totalSupply() public view returns (uint256) {
        return _totalSupply.current();
    }

    /// @notice Owner-only safe mint to address `to` with tokenId
    function safeMint(address to, uint256 tokenId) external onlyOwner whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (_minted[tokenId]) revert TokenAlreadyMinted(tokenId);
        uint256 cur = _totalSupply.current();
        if (cur + 1 > maxSupply) revert MaxSupplyReached();

        _minted[tokenId] = true;
        _totalSupply.increment();
        _safeMint(to, tokenId);
        // Transfer event emitted by _safeMint/_mint
    }

    /// @notice Owner can mint multiple tokenIds in a single call (gas efficient caller-side)
    function batchMint(address to, uint256[] calldata tokenIds) external onlyOwner whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        uint256 count = tokenIds.length;
        uint256 cur = _totalSupply.current();
        if (cur + count > maxSupply) revert MaxSupplyReached();

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            uint256 id = tokenIds[i];
            if (_minted[id]) revert TokenAlreadyMinted(id);
            _minted[id] = true;
            _safeMint(to, id);
            _totalSupply.increment();
        }
    }

    /// @notice Burn a token (owner or approved)
    function burn(uint256 tokenId) public {
        address ownerAddr = ownerOf(tokenId); // will revert if not existent
        if (msg.sender != ownerAddr && !isApprovedForAll(ownerAddr, msg.sender) && getApproved(tokenId) != msg.sender) {
            revert NotTokenOwnerOrApproved();
        }

        _burn(tokenId);
        // reflect totalSupply decrement and minted flag cleared
        _totalSupply.decrement();
        _minted[tokenId] = false;
    }

    /// @notice Pause minting/transfers that require whenNotPaused (we use whenNotPaused on mint; transfers still allowed by default)
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Update base URI
    function setBaseURI(string calldata newBase) external onlyOwner {
        _baseTokenURI = newBase;
        emit BaseURIUpdated(newBase);
    }

    /// @inheritdoc ERC721
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Override tokenURI to revert clearly on non-existent token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist(tokenId);
        return super.tokenURI(tokenId);
    }

    /// @notice Hook to allow pausing transfers if desired (optional)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }


    /// @notice Convenience: check if a token has been minted before
    function isMinted(uint256 tokenId) external view returns (bool) {
        return _minted[tokenId];
    }

    /// @notice Return name and symbol from ERC721 base
    // name() and symbol() are available from ERC721
}
