// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EngineNFTTypes {
    enum PartType {
        Turbine,
        DriveTrain,
        Capacitor
    }

    struct EngineNFT {
        PartType partType;
        uint256 game;
        uint256 divepointCapLeft;
        uint256 turbo;
    }

    struct EngineType {
        PartType partType;
        uint256 divepointCap;
        uint256 game;
        uint256 turbo;
        uint256 price;
        uint256 maxSupply;
    }
}
