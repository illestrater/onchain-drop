// SPDX-License-Identifier: Unlicense
// Written by illestrater <> @illestrater_
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "hardhat/console.sol";

contract Drop is ERC721, VRFConsumerBaseV2, ReentrancyGuard {
    using SafeMath for uint256;

    // Chainlink Parameters
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    bytes32 keyHash;
    uint64 subscriptionId;

    struct Metadata {
        string[] choosableTraits;
        string[][] choosableValues;
        string[] randomTraits;
        string[][] randomValues;
        uint16[] traitsChance;
        uint16[][] valuesChance;
    }

    struct TraitIndex {
        uint16 traitIndex;
        uint16 valueIndex;
    }

    address deployer;
    uint tokenIdCounter = 0;
    uint metadataRandomizedCounter = 0;
    uint tokenPrice;
    uint maxSupply;
    Metadata metadata;
    mapping (uint => TraitIndex[]) traitIndexes;

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        string memory name,
        string memory symbol,
        uint _tokenPrice,
        uint _maxSupply,
        string[][][] memory traits,
        uint16[][][] memory chances
    ) ERC721(name, symbol) VRFConsumerBaseV2(_vrfCoordinator) {
        require(traits[0][0].length == traits[1].length &&
                traits[2][0].length == traits[3].length &&
                traits[3].length == chances[0][0].length &&
                traits[3].length == chances[1].length, "Invalid metadata");

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(_linkToken);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        deployer = msg.sender;
        maxSupply = _maxSupply;
        tokenPrice = _tokenPrice;

        uint16[][] memory valueChances = new uint16[][](chances[1].length);
        for (uint i = 0; i < chances[1].length; i++) {
            uint16 propertySum = 0;
            uint16[] memory propertyChances = new uint16[](chances[1][i].length);
            for (uint j = 0; j < chances[1][i].length; j++) {
                propertySum += chances[1][i][j];
                propertyChances[j] = propertySum;
            }
            valueChances[i] = propertyChances;
        }

        metadata = Metadata({
            choosableTraits: traits[0][0],
            choosableValues: traits[1],
            randomTraits: traits[2][0],
            randomValues: traits[3],
            traitsChance: chances[0][0],
            valuesChance: valueChances
        });
    }

    function randomMetadata(uint vrfNumber) public {
        console.log('GENERATING', vrfNumber);

        // TODO: REMOVE VRF NUMBER TO MINT NUMBER
        for (uint i = 0; i < metadata.traitsChance.length; i++) {
            if (uint(keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, vrfNumber, i
                ))) % 10000 < metadata.traitsChance[i]) {
                uint randomNumber = uint(keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, vrfNumber, i * 1000
                ))) % metadata.valuesChance[i][metadata.valuesChance[i].length - 1];
                for (uint j = 0; j < metadata.valuesChance[i].length; j++) {
                    if (randomNumber <= metadata.valuesChance[i][j]) {
                        if (j == 0 || randomNumber > metadata.valuesChance[i][j - 1]) {
                            traitIndexes[vrfNumber].push(TraitIndex(uint16(i), uint16(j)));
                            break;
                        }
                    }
                }
            }
        }

        for (uint i = 0; i < traitIndexes[vrfNumber].length; i++) {
            console.log(metadata.randomTraits[traitIndexes[vrfNumber][i].traitIndex], metadata.randomValues[traitIndexes[vrfNumber][i].traitIndex][traitIndexes[vrfNumber][i].valueIndex]);
        }
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        randomMetadata(randomWords[0]);
    }

    function mint() public payable nonReentrant {
        require(tokenIdCounter < maxSupply, "Total supply reached");
        tokenIdCounter += 1;

        uint excessAmount = msg.value.sub(tokenPrice);

        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
            require(returnExcessStatus, "Failed to return excess.");
        }

        _mint(_msgSender(), tokenIdCounter);
    }

    function withdraw(address _to, uint amount) public {
        require(msg.sender == deployer);
        payable(_to).call{value:amount, gas:200000}("");
    }
}
