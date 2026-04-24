// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

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

    bytes private _contractURIEncoded;
    bool private _isSealed;
    uint256 private _nextTokenId;

    address public owner;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => bytes) private _tokenURIs;
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
        require(to != address(0), "Zero address");

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

        emit Transfer(address(0), msg.sender, tokenId);
    }

    function approveMinter(address minter) public onlyOwner {
        _approvedMinters[minter] = true;
    }

    function revokeMinter(address minter) public onlyOwner {
        _approvedMinters[minter] = false;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory uri) {
        require(_owners[tokenId] != address(0) && _sealed[tokenId], "Invalid token");
        uri = string(_tokenURIs[tokenId]);
    }

    function pushTokenURI(uint256 tokenId, bytes calldata _pushbytes) public {
        require(ownerOf(tokenId) == msg.sender, "Incorrect owner");
        require(!_sealed[tokenId], "Token is already sealed");

        for (uint256 i = 0; i < _pushbytes.length; i++) {
            _tokenURIs[tokenId].push(_pushbytes[i]);
        }
    }

    function sealToken(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Incorrect owner");
        require(!_sealed[tokenId], "Already sealed");

        _sealed[tokenId] = true;
    }

    function burn(uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == msg.sender || owner == msg.sender, "Not allowed");
        require(!_sealed[tokenId], "Token is sealed, cannot burn");

        _tokenApprovals[tokenId] = address(0);
        emit Approval(tokenOwner, address(0), tokenId);

        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];

        delete _tokenURIs[tokenId];
        delete _sealed[tokenId];

        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function contractURI() public view returns (string memory) {
        return _isSealed ? string(_contractURIEncoded) : "";
    }

    function pushContractURI(bytes calldata _pushbytes) public onlyOwner {
        require(!_isSealed, "Contract is already sealed");
        for (uint256 i = 0; i < _pushbytes.length; i++) {
            _contractURIEncoded.push(_pushbytes[i]);
        }
    }

    function sealContract() public onlyOwner {
        require(!_isSealed, "Contract is already sealed");
        _isSealed = true;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}
