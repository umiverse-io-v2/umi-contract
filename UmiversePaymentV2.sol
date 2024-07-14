// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/Ownable.sol";
import "./lib/SafeMath.sol";
import {ERC2771Context} from "@gelatonetwork/relay-context/contracts/vendor/ERC2771Context.sol";

contract UmiversePaymentV2 is ERC2771Context {
    using SafeMath for uint256;

    address public owner;
    address public signerAddress;

    uint256 public presaleFeeToDeveloper = 490;
    uint256 public presaleFeeToUmi = 210;
    uint256 public presaleFeeToRewardFund = 300;

    address public feeAddress; // umi
    address public rewardPoolAddress; //reward pool

    IERC20 public usdt = IERC20(0x21b81F2Cc97334031EfAfF3b93d8F846e02Ad0bc);
    IERC20 public usdc = IERC20(0x63Eb5CCD29905BDeB83f1889C84d4Bf884038d2F);
    IERC20 public umi = IERC20(address(0));
    IERC20 public eth = IERC20(address(0));

    event PaymentSent(
        address indexed recipient,
        uint256 orderId,
        uint256 amount,
        string _priceType,
        bytes _signature
    );
    event TokensWithdrawn(uint256 amount);

    struct Order {
        address recipient;
        uint256 orderId;
        uint256 amount;
        string _priceType;
        uint256 timestamp;
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId = 1;

    constructor(
        address trustedForwarder,
        address _rewardPoolAddress,
        address _feeAddress,
        address _signerAddress
    ) ERC2771Context(trustedForwarder) {
        owner = msg.sender;
        rewardPoolAddress = _rewardPoolAddress;
        feeAddress = _feeAddress;
        signerAddress = _signerAddress;
    }

    modifier onlyTrustedForwarder() {
        require(
            isTrustedForwarder(msg.sender),
            "Only callable by Trusted Forwarder"
        );
        _;
    }

    // config
    function setFee(
        uint256 _presaleFeeToDeveloper,
        uint256 _presaleFeeToUmi,
        uint256 _presaleFeeToRewardFund
    ) public onlyOwner {
        presaleFeeToDeveloper = _presaleFeeToDeveloper;
        presaleFeeToUmi = _presaleFeeToUmi;
        presaleFeeToRewardFund = _presaleFeeToRewardFund;
    }

    function setUsdt(address _usdt) public onlyOwner {
        usdt = IERC20(_usdt);
    }

    function setUsdc(address _usdc) public onlyOwner {
        usdc = IERC20(_usdc);
    }

    function setUmi(address _umi) public onlyOwner {
        umi = IERC20(_umi);
    }

    function setEth(address _eth) public onlyOwner {
        eth = IERC20(_eth);
    }

    // config
    function config(
        address _feeAddress,
        address _rewardPoolAddress,
        address _signerAddress
    ) public onlyOwner {
        feeAddress = _feeAddress;
        rewardPoolAddress = _rewardPoolAddress;
        signerAddress = _signerAddress;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function sendPayment(
        address from,
        address recipient,
        uint256 orderId,
        uint256 amount,
        string memory _priceType,
        uint256 _timestamp,
        bytes memory _signature
    ) external onlyTrustedForwarder {
        require(amount > 0, "Invalid amount");
        require(from != address(0), "CV: from to the zero address");
        require(
            verify(
                from,
                recipient,
                orderId,
                amount,
                _priceType,
                _timestamp,
                _signature
            ),
            "CV: invalid _signature"
        );

        IERC20 sendToken;
        if (amount > 0) {
            if (compareStrings(_priceType, "usdt")) {
                require(address(usdt) != address(0), "usdt address not config");
                sendToken = usdt;
            }
            if (compareStrings(_priceType, "usdc")) {
                require(address(usdc) != address(0), "usdc address not config");
                sendToken = usdc;
            }

            if (compareStrings(_priceType, "eth")) {
                require(address(eth) != address(0), "eth address not config");
                sendToken = eth;
            }

            if (compareStrings(_priceType, "umi")) {
                require(address(umi) != address(0), "umi address not config");
                sendToken = umi;
            }
            processTrade(sendToken, from, recipient, amount);
        }

        orders[orderId] = Order(
            recipient,
            orderId,
            amount,
            _priceType,
            _timestamp
        );
        nextOrderId += 1;

        emit PaymentSent(recipient, orderId, amount, _priceType, _signature);
    }

    function withdrawTokens(IERC20 token, uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");
        require(token.transfer(owner, amount), "Token transfer failed");
        emit TokensWithdrawn(amount);
    }

    function processTrade(
        IERC20 token,
        address sender,
        address receiver,
        uint256 amount
    ) internal {
        uint256 toDeveloper = 0;
        uint256 toUmi = 0;
        uint256 toRewardFund = 0;
        token.transferFrom(sender, address(this), amount);
        toDeveloper = amount.mul(presaleFeeToDeveloper).div(1000);
        toUmi = amount.mul(presaleFeeToUmi).div(1000);
        toRewardFund = amount.mul(presaleFeeToRewardFund).div(1000);

        uint256 toSeller = amount - toDeveloper - toUmi - toRewardFund;

        if (toDeveloper > 0) {
            token.transfer(receiver, toDeveloper);
        }

        if (toUmi > 0) {
            token.transfer(feeAddress, toUmi);
        }

        if (toRewardFund > 0) {
            token.transfer(rewardPoolAddress, toRewardFund);
        }

        if (toSeller > 0) {
            token.transfer(receiver, toSeller);
        }
    }

    // signer
    function getMessageHash(
        address _from,
        address _recipient,
        uint256 _orderId,
        uint256 _amount,
        string memory priceType,
        uint256 _timestamp
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _from,
                    _recipient,
                    _orderId,
                    _amount,
                    priceType,
                    _timestamp
                )
            );
    }

    //verify(_buyer, _seller, _tokenid, _price, _amount, _timestamp, _signature
    function verify(
        address _from,
        address _recipient,
        uint256 _orderId,
        uint256 _amount,
        string memory priceType,
        uint256 _timestamp,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes32 messageHash = getMessageHash(
            _from,
            _recipient,
            _orderId,
            _amount,
            priceType,
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
}
