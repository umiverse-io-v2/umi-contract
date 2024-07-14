// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./types/EngineNFTTypes.sol";

contract UmiDiveEngineNFT is Ownable, ERC721Enumerable, EngineNFTTypes {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Strings for uint256;

    // metadata URI
    string private _baseTokenURI;
    mapping(uint256 => uint256) public tokenMapper; // nftid mapping tokenid
    mapping(uint256 => uint256) public tokenMapper2; // tokenid mapping nftid

    mapping(string => EngineType) public engineTypes;
    mapping(uint256 => EngineNFT) public engineNFTs;

    mapping(string => uint256) public currentSupplies;

    mapping(uint256 => bool) public nftExist;
    mapping(address => bool) public supportToken;

    uint256 startTokenId = 0;
    address engine = address(0);

    bool public mintingAllowed = true; // 新增变量，默认允许mint

    constructor(
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) Ownable(msg.sender) ERC721(_name, _symbol) {
        _baseTokenURI = _uri;
        saveEngineType("TB-0001", PartType.Turbine, 0, 0, 10 * 1e6, 100, 10000);
        saveEngineType("TB-0001S", PartType.Turbine, 0, 0, 50 * 1e6, 102, 1000);

        saveEngineType("DT-FHK-00", PartType.DriveTrain, 40, 0, 25 * 1e6, 0, 10000);
        saveEngineType("DT-SS-00", PartType.DriveTrain, 40, 0, 25 * 1e6, 0, 1000);

        saveEngineType(
            "CX-0001",
            PartType.Capacitor,
            0,
            100 * 1e6,
            50 * 1e6,
            0,
            10000000000
        );
        saveEngineType(
            "CX-0001M",
            PartType.Capacitor,
            0,
            150 * 1e6,
            80 * 1e6,
            0,
            100000000
        );
    }

    modifier onlyEngine() {
        require(address(engine) != address(0), "ERROR_ENGINE_NOT_SET");
        require(msg.sender == engine, "ERROR_PERMISSION");
        _;
    }

    function configEngine(address _engine) public onlyOwner {
        engine = _engine;
    }

    function configSupportToken(address _token, bool state) public onlyOwner {
        supportToken[_token] = state;
    }

    function checkEngineTypeExist(string memory engineName)
        public
        view
        returns (bool)
    {
        EngineType memory engineType = engineTypes[engineName];
        if (
            engineType.divepointCap == 0 &&
            engineType.game == 0 &&
            engineType.turbo == 0 &&
            engineType.price == 0 &&
            engineType.maxSupply == 0
        ) return false;
        return true;
    }

    function checkEngineNFTsExist(uint256 tokenId) public view returns (bool) {
        EngineNFT memory engineNFT = engineNFTs[tokenId];
        if (
            engineNFT.game == 0 &&
            engineNFT.turbo == 0 &&
            engineNFT.divepointCapLeft == 0
        ) {
            return false;
        }
        return true;
    }

    function saveEngineType(
        string memory _name,
        PartType _partType,
        uint256 _game,
        uint256 _divepointCap,
        uint256 _price,
        uint256 _turbo,
        uint256 _maxSupply
    ) internal {
        EngineType memory engineType = EngineType({
            partType: _partType,
            divepointCap: _divepointCap,
            game: _game,
            turbo: _turbo,
            price: _price,
            maxSupply: _maxSupply
        });
        engineTypes[_name] = engineType;
    }

    function saveEngineNFT(
        uint256 tokenId,
        PartType partType,
        uint256 game,
        uint256 divepointCapLeft,
        uint256 turbo
    ) internal {
        EngineNFT memory engineNFT = EngineNFT({
            partType: partType,
            game: game,
            divepointCapLeft: divepointCapLeft,
            turbo: turbo
        });
        engineNFTs[tokenId] = engineNFT;
    }

    function configEngineType(
        string memory _name,
        uint8 _partType,
        uint256 _game,
        uint256 _divepointCap,
        uint256 _price,
        uint256 _turbo,
        uint256 _maxSupply
    ) public onlyOwner {
        saveEngineType(
            _name,
            convertPartType(_partType),
            _game,
            _divepointCap,
            _price,
            _turbo,
            _maxSupply
        );
    }

    function convertPartType(uint256 _type) public pure returns (PartType) {
        if (_type == 0) return PartType.Turbine;
        else if (_type == 1) return PartType.DriveTrain;
        else return PartType.Capacitor;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function getCurrentIndex() public view returns (uint256) {
        return totalSupply();
    }

    function mint(
        uint256 nftid,
        string memory engineName,
        address payToken
    ) public {
        require(mintingAllowed, "Minting is not allowed"); // 检查 mintingAllowed 变量
        require(engine != address(0), "ENGINE_NOT_CONFIG");
        require(!nftExist[nftid], "nftid exist!!!");
        require(checkEngineTypeExist(engineName), "Engine not exist");
        require(supportToken[payToken], "Token not support");

        EngineType memory engineType = engineTypes[engineName];
        uint256 maxSupply = engineType.maxSupply;
        uint256 currentSupply = currentSupplies[engineName];
        require(
            currentSupply + 1 <= maxSupply,
            "Cannot mint more, max supply reached"
        );

        uint256 price = engineType.price;
        //TODO transfer usdt/usdc
        IERC20(payToken).safeTransferFrom(msg.sender, engine, price);

        uint256 tokenId = totalSupply();
        saveEngineNFT(
            tokenId,
            engineType.partType,
            engineType.game,
            engineType.divepointCap,
            engineType.turbo
        );

        // increase totalSupply Of NFT
        currentSupplies[engineName]++;

        tokenMapper[nftid] = tokenId;
        tokenMapper2[tokenId] = nftid;
        nftExist[nftid] = true;
        _safeMint(msg.sender, tokenId);
    }

    function dreaseDivePointCap(uint256 tokenId, uint256 amount) public onlyEngine {
        require(checkEngineNFTsExist(tokenId), "Engine NFT does not exist");
        EngineNFT storage engineNFT = engineNFTs[tokenId];
        require(engineNFT.divepointCapLeft >= amount, "Insufficient dive point cap");
        engineNFT.divepointCapLeft = engineNFT.divepointCapLeft.sub(amount);
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }


    function redeem(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }

    function getEngineNFT(uint256 id) public view returns (EngineNFT memory) {
        return engineNFTs[id];
    }

    // 新增方法：获取用户拥有的所有NFT的tokenIds
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    // 新增方法：设置mintingAllowed变量
    function setMintingAllowed(bool _allowed) external onlyOwner {
        mintingAllowed = _allowed;
    }
}
