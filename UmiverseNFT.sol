// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";


contract UMIVERSE is Ownable, ERC721A {
    // metadata URI
    string private _baseTokenURI;
    mapping(uint256 => uint256) public tokenMapper; //nftid mapping tokenid
    mapping(uint256 => uint256) public tokenMapper2; //tokenid mapping nftid
    uint256 private _tokenIds;
    mapping(uint256 => bool) public nftExist;

    constructor(string memory _uri,string memory _name,string memory _symbol) ERC721A(_name, _symbol) {
        _baseTokenURI = _uri;
    }




    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }



    function getCurrentIndex() public view returns (uint256){
        return _nextTokenId();
    }

    function mint(uint256 nftid) public
    {
        require(!nftExist[nftid], "nftid exist!!!");

        tokenMapper[nftid] = _tokenIds;
        tokenMapper2[_tokenIds] = nftid;
        nftExist[nftid] = true;
        _safeMint(address(msg.sender), 1);
        _tokenIds++;
    }

    function batchMint(uint256[] memory nftids) public{
        for(uint256 i=0; i<nftids.length; i++){
            uint256 nftid = nftids[i];
            require(!nftExist[nftid], "nftid exist!!!");

            tokenMapper[nftid] = _tokenIds;
            tokenMapper2[_tokenIds] = nftid;

            nftExist[nftid] = true;
            _safeMint(address(msg.sender), 1);
            _tokenIds++;
        }
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns(string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId))) : '';
    }

    function redeem(uint256 tokenId) external onlyOwner{
        _burn(tokenId);
    }
}