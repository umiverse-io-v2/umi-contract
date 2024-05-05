    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/Strings.sol";
import "../lib/Signature.sol";
import "./UmiDiveEngineNFT.sol";
import "./types/EngineNFTTypes.sol";
import "../lib/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UmiNFTsDiveEngine is Ownable, EngineNFTTypes{
    UmiDiveEngineNFT public engineNFTContract;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    IERC20 token;

    constructor(UmiDiveEngineNFT _engineNFTContract, IERC20 _token) Ownable(msg.sender){
        engineNFTContract = _engineNFTContract;
        token = _token;
    }

    function conversionDivePoint(uint256 gameId, uint256 divePoint, uint256 turbineTokenId, uint256 driveTrainTokenId, uint256 capacitorTokenId) public {
        //TODO Signature
        require(engineNFTContract.ownerOf(turbineTokenId) == msg.sender, "NFT_OWNER_ERROR");
        require(engineNFTContract.ownerOf(driveTrainTokenId) == msg.sender, "NFT_OWNER_ERROR");
        require(engineNFTContract.ownerOf(capacitorTokenId) == msg.sender, "NFT_OWNER_ERROR");

        EngineNFT memory turbineEngineNFT = engineNFTContract.getEngineNFT(turbineTokenId);
        EngineNFT memory driveTrainEngineNFT = engineNFTContract.getEngineNFT(driveTrainTokenId);
        EngineNFT memory capacitorEngineNFT = engineNFTContract.getEngineNFT(capacitorTokenId);

        require(capacitorEngineNFT.divepointCapLeft>=divePoint, "CAP_ERROR");
        require(driveTrainEngineNFT.game == gameId, "DRIVETRAIN_ERROR");
        uint256 turbo = turbineEngineNFT.turbo;

        uint256 conversionToken = divePoint.mul(turbo).div(100);
        engineNFTContract.dreaseDivePointCap(capacitorTokenId, divePoint);
        token.safeTransferFrom(address(this), msg.sender, conversionToken);
    }

    function withdrawETH(address payable recipient, uint256 amount) public onlyOwner{
        require(address(this).balance >= amount, "Insufficient balance");
        recipient.transfer(amount);
    }

    function withdrawERC20(address tokenAddress, address recipient, uint256 amount) public onlyOwner{
        IERC20 _token = IERC20(tokenAddress);
        uint256 contractBalance = _token.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient balance");
        _token.safeTransferFrom(address(this), recipient, amount);
    }
}
