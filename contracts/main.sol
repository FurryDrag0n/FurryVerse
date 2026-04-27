// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

import "./deps/SSTORE2.sol";

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract FurryVerse {
    string public name;
    string public symbol;

    uint256 constant MAX_CHUNK_SIZE = 24575;

    address[] private _contractURIChunks;
    bool private _isSealed;
    uint256 private _nextTokenId;

    address public owner;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => address[]) private _tokenURIChunkContracts;
    mapping(uint256 => bool) private _sealed;
    mapping(address => bool) private _approvedMinters;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier approvedMinter() {
        require(msg.sender == owner || _approvedMinters[msg.sender], "Not allowed");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x80ac58cd ||
            interfaceId == 0x5b5e139f ||
            interfaceId == 0x01ffc9a7;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        require(_owner != address(0), "Zero address");
        return _balances[_owner];
    }

    function isApprovedMinter(address _minter) public view returns (bool) {
        return _approvedMinters[_minter];
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Invalid token");
        return tokenOwner;
    }

    function approve(address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "Self-approve");
        require(
            msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
            "Not authorized"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Invalid token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "Self-approve");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address _owner, address operator) public view returns (bool) {
        return _operatorApprovals[_owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "Transfer to non ERC721Receiver"
        );
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "Incorrect owner");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (
            spender == tokenOwner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(tokenOwner, spender)
        ) && _sealed[tokenId];
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length == 0) {
            return true;
        }
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }

    function initToken() public approvedMinter {
        uint256 tokenId = _nextTokenId;

        _balances[msg.sender] += 1;
        _owners[tokenId] = msg.sender;
        _nextTokenId++;
    }

    function approveMinter(address minter) public onlyOwner {
        _approvedMinters[minter] = true;
    }

    function revokeMinter(address minter) public onlyOwner {
        _approvedMinters[minter] = false;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory uri) {
        require(_owners[tokenId] != address(0) && _sealed[tokenId], "Invalid token");

        address[] storage chunks = _tokenURIChunkContracts[tokenId];
        require(chunks.length > 0, "Empty metadata");

        // Считаем общую длину
        uint256 totalLen;
        for (uint256 i; i < chunks.length; i++) {
            totalLen += SSTORE2.read(chunks[i]).length;
        }

        bytes memory output = new bytes(totalLen);
        uint256 offset;
        for (uint256 i; i < chunks.length; i++) {
            bytes memory chunk = SSTORE2.read(chunks[i]);
            uint256 len = chunk.length;
            for (uint256 j; j < len; j++) {
                output[offset++] = chunk[j];
            }
        }
        uri = string(output);
    }

    function tokenURIPreview(uint256 tokenId) public view returns (string memory uri) {
        require(!_sealed[tokenId], "Sealed token. Call tokenURI instead");

        address[] storage chunks = _tokenURIChunkContracts[tokenId];
        require(chunks.length > 0, "Empty metadata");

        uint256 totalLen;
        for (uint256 i; i < chunks.length; i++) {
            totalLen += SSTORE2.read(chunks[i]).length;
        }

        bytes memory output = new bytes(totalLen);
        uint256 offset;
        for (uint256 i; i < chunks.length; i++) {
            bytes memory chunk = SSTORE2.read(chunks[i]);
            uint256 len = chunk.length;
            for (uint256 j; j < len; j++) {
                output[offset++] = chunk[j];
            }
        }
        uri = string(output);
    }

    function getTokenURIChunk(uint256 tokenId, uint256 index) public view returns (bytes memory) {
        return SSTORE2.read(_tokenURIChunkContracts[tokenId][index]);
    }

    function getTokenURISize(uint256 tokenId) public view returns (uint256) {
        return _tokenURIChunkContracts[tokenId].length;
    }

    function pushTokenURI(uint256 tokenId, bytes calldata _chunk) public {
        require(ownerOf(tokenId) == msg.sender, "Incorrect owner");
        require(!_sealed[tokenId], "Token is already sealed");
        require(_chunk.length > 0 && _chunk.length <= 24576, "Invalid chunk size");
        
        address chunkContract = SSTORE2.write(_chunk);
        _tokenURIChunkContracts[tokenId].push(chunkContract);
    }

    function sealToken(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Incorrect owner");
        require(!_sealed[tokenId], "Already sealed");

        _sealed[tokenId] = true;

        emit Transfer(address(0), msg.sender, tokenId);
    }

    function resetTokenURI(uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == msg.sender || owner == msg.sender, "Not allowed");
        require(!_sealed[tokenId], "Token is sealed, cannot burn");

        delete _tokenURIChunkContracts[tokenId];
    }

    function contractURI() public view returns (string memory uri) {
        if (!_isSealed || _contractURIChunks.length == 0) return "";

        address[] storage chunks = _contractURIChunks;
        require(chunks.length > 0, "Empty metadata");

        // Считаем общую длину
        uint256 totalLen;
        for (uint256 i; i < chunks.length; i++) {
            totalLen += SSTORE2.read(chunks[i]).length;
        }

        bytes memory output = new bytes(totalLen);
        uint256 offset;
        for (uint256 i; i < chunks.length; i++) {
            bytes memory chunk = SSTORE2.read(chunks[i]);
            uint256 len = chunk.length;
            for (uint256 j; j < len; j++) {
                output[offset++] = chunk[j];
            }
        }
        uri = string(output);
    }

    function pushContractURI(bytes calldata _chunk) public onlyOwner {
        require(!_isSealed, "Contract is already sealed");
        require(_chunk.length > 0 && _chunk.length <= 24576, "Invalid chunk size");
        
        address chunkContract = SSTORE2.write(_chunk);
        _contractURIChunks.push(chunkContract);
    }

    function resetContractURI() public onlyOwner {
        require(!_isSealed, "Contract is already sealed");

        delete _contractURIChunks;
    }

    function sealContract() public onlyOwner {
        require(!_isSealed, "Contract is already sealed");
        _isSealed = true;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}
