// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/Ownable.sol";
import "./lib/Pausable.sol";
import "./lib/IWETH.sol";
import "./lib/Strings.sol";
import "./lib/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC2771Context} from "@gelatonetwork/relay-context/contracts/vendor/ERC2771Context.sol";

contract UmiverseMarket is Ownable, ERC2771Context {
    using SafeMath for uint256;
    using Strings for uint256;

    event Buy(uint256 gold, uint256 price, address buyer, address seller);
    event Sell(uint256 gold, uint256 price, address seller, address buyer);

    address public admin;
    address public feeAddress; // umi
    address public rewardPoolAddress; //reward pool
    address public signerAddress; // get from backend private key

    // okbc testnet
    IERC20 public usdt = IERC20(0x21b81F2Cc97334031EfAfF3b93d8F846e02Ad0bc);
    IERC20 public usdc = IERC20(0x63Eb5CCD29905BDeB83f1889C84d4Bf884038d2F);
    IERC20 public umi = IERC20(address(0));
    IERC20 public eth = IERC20(address(0));

    uint256 public presaleFeeToDeveloper = 490;
    uint256 public presaleFeeToUmi = 210;
    uint256 public presaleFeeToRewardFund = 300;

    uint256 public tradeFeeToUmi = 10;
    uint256 public tradeFeeToDeveloper = 10;
    uint256 public tradeFeeToRewardFund = 5;

    constructor(
        address trustedForwarder,
        address _admin,
        address _feeAddress,
        address _signerAddress,
        address _rewardPoolAddess
    ) ERC2771Context(trustedForwarder) {
        admin = _admin;
        feeAddress = _feeAddress;
        signerAddress = _signerAddress;
        rewardPoolAddress = _rewardPoolAddess;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlySigner() {
        require(msg.sender == signerAddress);
        _;
    }

    modifier onlyTrustedForwarder() {
        require(
            isTrustedForwarder(msg.sender),
            "Only callable by Trusted Forwarder"
        );
        _;
    }

    function setAdmin(address _address) public onlyOwner {
        admin = _address;
    }

    function setFee(
        uint256 _presaleFeeToDeveloper,
        uint256 _presaleFeeToUmi,
        uint256 _presaleFeeToRewardFund,
        uint256 _tradeFeeToUmi,
        uint256 _tradeFeeToDeveloper,
        uint256 _tradeFeeToRewardFund
    ) public onlyOwner {
        presaleFeeToDeveloper = _presaleFeeToDeveloper;
        presaleFeeToUmi = _presaleFeeToUmi;
        presaleFeeToRewardFund = _presaleFeeToRewardFund;
        tradeFeeToUmi = _tradeFeeToUmi;
        tradeFeeToDeveloper = _tradeFeeToDeveloper;
        tradeFeeToRewardFund = _tradeFeeToRewardFund;
    }

    function setUsdt(address _usdt) public onlyAdmin {
        usdt = IERC20(_usdt);
    }

    function setUsdc(address _usdc) public onlyAdmin {
        usdc = IERC20(_usdc);
    }

    function setUmi(address _umi) public onlyAdmin {
        umi = IERC20(_umi);
    }

    function setEth(address _eth) public onlyAdmin {
        eth = IERC20(_eth);
    }

    function setFeeAddress(address _address) public onlyAdmin {
        feeAddress = _address;
    }

    function setSignerAddress(address _address) public onlyAdmin {
        signerAddress = _address;
    }

    function setRewardPoolAddress(address _rewardPoolAddress) public onlyAdmin {
        rewardPoolAddress = _rewardPoolAddress;
    }

    function getMessageHash(
        address _buyer,
        address _seller,
        uint256 _tokenid,
        uint256 _price,
        uint256 _amount,
        string memory _priceType,
        address _developerAddress,
        bool _presale,
        uint256 _timestamp
    ) public pure returns (bytes32) {
        require(isTokenSupported(_priceType), "token not support");
        return
            keccak256(
                abi.encodePacked(
                    _buyer,
                    _seller,
                    _tokenid,
                    _price,
                    _amount,
                    _priceType,
                    _developerAddress,
                    _presale,
                    _timestamp
                )
            );
    }

    //verify(_buyer, _seller, _tokenid, _price, _amount, _timestamp, _signature
    function verify(
        address _buyer,
        address _seller,
        uint256 _tokenid,
        uint256 _price,
        uint256 _amount,
        string memory _priceType,
        address _developerAddress,
        bool _presale,
        uint256 _timestamp,
        bytes memory _signature
    ) internal view returns (bool) {
        require(isTokenSupported(_priceType), "token not support");
        bytes32 messageHash = getMessageHash(
            _buyer,
            _seller,
            _tokenid,
            _price,
            _amount,
            _priceType,
            _developerAddress,
            _presale,
            _timestamp
        );
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, _signature) == signerAddress;
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function recoverSignerPublic(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function isTokenSupported(string memory token) public pure returns (bool) {
        return (compareStrings(token, "usdt") ||
            compareStrings(token, "usdc") ||
            compareStrings(token, "umi") ||
            compareStrings(token, "divepoint") ||
            compareStrings(token, "eth"));
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked(a)) ==
            keccak256(abi.encodePacked(b)));
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function processTrade(
        IERC20 token,
        address buyer,
        address seller,
        address _developer,
        bool presale,
        uint256 amount
    ) internal {
        uint256 toDeveloper = 0;
        uint256 toUmi = 0;
        uint256 toRewardFund = 0;


        token.transferFrom(buyer, address(this), amount);

        if (presale) {
            toDeveloper = amount.mul(presaleFeeToDeveloper).div(1000);
            toUmi = amount.mul(presaleFeeToUmi).div(1000);
            toRewardFund = amount.mul(presaleFeeToRewardFund).div(1000);
        } else {
            toDeveloper = amount.mul(tradeFeeToDeveloper).div(1000);
            toUmi = amount.mul(tradeFeeToUmi).div(1000);
            toRewardFund = amount.mul(tradeFeeToRewardFund).div(1000);
        }

        uint256 toSeller = amount - toDeveloper - toUmi - toRewardFund;

        if (toDeveloper > 0) {
            token.transfer(_developer, toDeveloper);
        }

        if (toUmi > 0) {
            token.transfer(feeAddress, toUmi);
        }

        if (toRewardFund > 0) {
            token.transfer(rewardPoolAddress, toRewardFund);
        }

        if (toSeller > 0) {
            token.transfer(seller, toSeller);
        }
    }

    function buy(
        IERC721 nft,
        address _buyer,
        uint256 _tokenid,
        uint256 _price,
        uint256 _amount,
        string memory _priceType,
        address _developerAddress,
        bool _presale,
        uint256 _timestamp,
        address _seller,
        bytes memory _signature
    ) external onlyTrustedForwarder {
        require(_buyer != address(0), "CV: buyer to the zero address");
        require(
            verify(
                _buyer,
                _seller,
                _tokenid,
                _price,
                _amount,
                _priceType,
                _developerAddress,
                _presale,
                _timestamp,
                _signature
            ),
            "CV: invalid _signature"
        );
        require(_price == _amount, "CV: invalid amount");

        // buy with usdt/usdc/umi/eth
        if (_amount > 0) {
            if (compareStrings(_priceType, "usdt")) {
                require(address(usdt) != address(0), "usdt address not config");
                processTrade(
                    usdt,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }

            if (compareStrings(_priceType, "usdc")) {
                require(address(usdc) != address(0), "usdc address not config");
                processTrade(
                    usdc,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }

            if (compareStrings(_priceType, "eth")) {
                require(address(eth) != address(0), "eth address not config");
                processTrade(
                    eth,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }

            if (compareStrings(_priceType, "umi")) {
                require(address(umi) != address(0), "umi address not config");
                processTrade(
                    umi,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }
        }

        bytes memory _data;

        require(
            nft.isApprovedForAll(_seller, address(this)),
            "CV: seller is not approved"
        );
        nft.safeTransferFrom(_seller, _buyer, _tokenid, _data);
        emit Buy(_tokenid * 1e8, _price, _buyer, _seller);
    }

    function sell(
        IERC721 nft,
        address _seller,
        uint256 _tokenid,
        uint256 _price,
        uint256 _amount,
        string memory _priceType,
        address _developerAddress,
        bool _presale,
        uint256 _timestamp,
        address _buyer,
        bytes memory _signature
    ) external onlyTrustedForwarder {
        require(_buyer != address(0), "CV: buyer to the zero address");
        require(
            verify(
                _buyer,
                _seller,
                _tokenid,
                _price,
                _amount,
                _priceType,
                _developerAddress,
                _presale,
                _timestamp,
                _signature
            ),
            "CV: invalid _signature"
        );
        require(_price == _amount, "CV: invalid amount");

        if (_amount > 0) {
            if (compareStrings(_priceType, "usdt")) {
                require(address(usdt) != address(0), "usdt address not config");
                processTrade(
                    usdt,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }

            if (compareStrings(_priceType, "usdc")) {
                require(address(usdc) != address(0), "usdc address not config");
                processTrade(
                    usdc,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }

            if (compareStrings(_priceType, "eth")) {
                require(address(usdt) != address(0), "eth address not config");
                processTrade(
                    eth,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }

            if (compareStrings(_priceType, "umi")) {
                require(address(umi) != address(0), "umi address not config");
                processTrade(
                    umi,
                    _buyer,
                    _seller,
                    _developerAddress,
                    _presale,
                    _amount
                );
            }
        }

        bytes memory _data;

        nft.safeTransferFrom(_seller, _buyer, _tokenid, _data);
        emit Sell(_tokenid * 1e8, _price, _seller, _buyer);
    }
}
