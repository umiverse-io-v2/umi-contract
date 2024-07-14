// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/Signature.sol";
import "./UmiDiveEngineNFT.sol";
import "./types/EngineNFTTypes.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UmiNFTsDiveEngine is Ownable, EngineNFTTypes {
    UmiDiveEngineNFT public engineNFTContract;
    address public signerAddress;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    IERC20 token;

    constructor(
        UmiDiveEngineNFT _engineNFTContract,
        IERC20 _token,
        address _signAddress
    ) Ownable(msg.sender) {
        engineNFTContract = _engineNFTContract;
        token = _token;
        signerAddress = _signAddress;
    }

    function config(
        UmiDiveEngineNFT _engineNFTContract,
        IERC20 _token,
        address _signAddress
    ) public onlyOwner {
        engineNFTContract = _engineNFTContract;
        token = _token;
        signerAddress = _signAddress;
    }

    function conversionDivePoint(
        uint256 gameId,
        uint256 totalDivePoint,
        uint256 turbineTokenId,
        uint256 driveTrainTokenId,
        uint256 capacitorTokenId,
        uint256 rate,
        uint256 timestamp,
        bytes memory _signature
    ) public {
        //TODO Signature
        require(
            engineNFTContract.ownerOf(turbineTokenId) == msg.sender,
            "NFT_OWNER_ERROR"
        );
        require(
            engineNFTContract.ownerOf(driveTrainTokenId) == msg.sender,
            "NFT_OWNER_ERROR"
        );
        require(
            engineNFTContract.ownerOf(capacitorTokenId) == msg.sender,
            "NFT_OWNER_ERROR"
        );

        require(
            verify(
                msg.sender,
                gameId,
                totalDivePoint,
                turbineTokenId,
                driveTrainTokenId,
                capacitorTokenId,
                rate,
                timestamp,
                _signature
            ),
            "CV: invalid _signature"
        );

        uint256 convertPoint = totalDivePoint.mul(rate).div(10000);
        require(convertPoint > 0, "MINIMUM_CONVERT_DP_ERROR");

        EngineNFT memory turbineEngineNFT = engineNFTContract.getEngineNFT(
            turbineTokenId
        );
        require(turbineEngineNFT.partType == PartType.Turbine, "TURBINE_TYPE_ERROR");

        EngineNFT memory driveTrainEngineNFT = engineNFTContract.getEngineNFT(
            driveTrainTokenId
        );
        require(driveTrainEngineNFT.partType == PartType.DriveTrain, "DRIVETRAIN_TYPE_ERROR");

        EngineNFT memory capacitorEngineNFT = engineNFTContract.getEngineNFT(
            capacitorTokenId
        );
        require(capacitorEngineNFT.partType == PartType.Capacitor, "CAPACITOR_TYPE_ERROR");

        require(
            capacitorEngineNFT.divepointCapLeft >= convertPoint,
            "CAP_ERROR"
        );
        require(driveTrainEngineNFT.game == gameId, "DRIVETRAIN_ERROR");
        uint256 turbo = turbineEngineNFT.turbo;

        uint256 conversionToken = convertPoint.mul(turbo).div(100);
        engineNFTContract.dreaseDivePointCap(capacitorTokenId, convertPoint);
        token.approve(address(this), conversionToken);
        token.safeTransferFrom(address(this), msg.sender, conversionToken);
    }

    function withdrawETH(address payable recipient, uint256 amount)
        public
        onlyOwner
    {
        require(address(this).balance >= amount, "Insufficient balance");
        recipient.transfer(amount);
    }

    function withdrawERC20(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public onlyOwner {
        IERC20 _token = IERC20(tokenAddress);
        uint256 contractBalance = _token.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient balance");
        // Approve the transfer
        _token.approve(address(this), amount);
        _token.safeTransferFrom(address(this), recipient, amount);
    }

    //verify(_buyer, _seller, _tokenid, _price, _amount, _timestamp, _signature
    function verify(
        address owner,
        uint256 gameId,
        uint256 totalDivePoint,
        uint256 turbineTokenId,
        uint256 driveTrainTokenId,
        uint256 capacitorTokenId,
        uint256 rate,
        uint256 timestamp,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes32 messageHash = getMessageHash(
            owner,
            gameId,
            totalDivePoint,
            turbineTokenId,
            driveTrainTokenId,
            capacitorTokenId,
            rate,
            timestamp
        );
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, _signature) == signerAddress;
    }

    // signer
    function getMessageHash(
        address owner,
        uint256 gameId,
        uint256 totalDivePoint,
        uint256 turbineTokenId,
        uint256 driveTrainTokenId,
        uint256 capacitorTokenId,
        uint256 rate,
        uint256 timestamp
    ) public view returns (bytes32) {
        require(
            engineNFTContract.ownerOf(turbineTokenId) == owner,
            "NFT_OWNER_ERROR"
        );
        require(
            engineNFTContract.ownerOf(driveTrainTokenId) == owner,
            "NFT_OWNER_ERROR"
        );
        require(
            engineNFTContract.ownerOf(capacitorTokenId) == owner,
            "NFT_OWNER_ERROR"
        );

        EngineNFT memory turbineEngineNFT = engineNFTContract.getEngineNFT(
            turbineTokenId
        );
        require(turbineEngineNFT.partType == PartType.Turbine, "TURBINE_TYPE_ERROR");

        EngineNFT memory driveTrainEngineNFT = engineNFTContract.getEngineNFT(
            driveTrainTokenId
        );
        require(driveTrainEngineNFT.partType == PartType.DriveTrain, "DRIVETRAIN_TYPE_ERROR");

        EngineNFT memory capacitorEngineNFT = engineNFTContract.getEngineNFT(
            capacitorTokenId
        );
        require(capacitorEngineNFT.partType == PartType.Capacitor, "CAPACITOR_TYPE_ERROR");

        uint256 convertPoint = totalDivePoint.mul(rate).div(10000);
        require(convertPoint > 0, "MINIMUM_CONVERT_DP_ERROR");
        require(
            capacitorEngineNFT.divepointCapLeft >= convertPoint,
            "CAP_ERROR"
        );
        require(driveTrainEngineNFT.game == gameId, "DRIVETRAIN_ERROR");

        return
            keccak256(
                abi.encodePacked(
                    gameId,
                    totalDivePoint,
                    turbineTokenId,
                    driveTrainTokenId,
                    capacitorTokenId,
                    rate,
                    timestamp
                )
            );
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
