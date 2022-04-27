// SPDX-License-Identifier: Unlicense
// Written by illestrater <> @illestrater_
// Thought innovation by LAGO Frame

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import 'base64-sol/base64.sol';
import "./HelperFunctions.sol";
import "hardhat/console.sol";

/* TODO:
 * - Minting phases
 * - Chainlink request double handler(?)
 */
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
    string nftName;
    Metadata metadata;
    mapping (uint => uint[]) chosenTraits;
    mapping (uint => TraitIndex[]) traitIndexes;

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        string memory _name,
        string memory _symbol,
        uint _tokenPrice,
        uint _maxSupply,
        string[][][] memory traits,
        uint16[][][] memory chances
    ) ERC721(_name, _symbol) VRFConsumerBaseV2(_vrfCoordinator) {
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
        nftName = _name;

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

    function randomMetadata(uint vrfNumber, uint tokenId) private {
        for (uint i = 0; i < metadata.traitsChance.length; i++) {
            if (uint(keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, vrfNumber, tokenId, i
                ))) % 10000 < metadata.traitsChance[i]) {
                uint randomNumber = uint(keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, vrfNumber, tokenId, i + 1234
                ))) % metadata.valuesChance[i][metadata.valuesChance[i].length - 1];
                for (uint j = 0; j < metadata.valuesChance[i].length; j++) {
                    if (randomNumber <= metadata.valuesChance[i][j]) {
                        if (j == 0 || randomNumber > metadata.valuesChance[i][j - 1]) {
                            traitIndexes[tokenId].push(TraitIndex(uint16(i), uint16(j)));
                            break;
                        }
                    }
                }
            }
        }
    }

    function randomizeMetadata() public {
        require(msg.sender == deployer);

        uint remainder = tokenIdCounter.sub(metadataRandomizedCounter);
        if (remainder > 100) remainder = 100;

        uint256 requestId = COORDINATOR.requestRandomWords(
          keyHash,
          subscriptionId,
          3,
          uint32(remainder.mul(175000)),
          1
      );
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint remainder = tokenIdCounter.sub(metadataRandomizedCounter);
        if (remainder > 100) remainder = 100;
        for (uint i = 0; i < remainder; i++) {
            randomMetadata(randomWords[0], tokenIdCounter + i);
        }

        metadataRandomizedCounter.add(remainder);
    }

    /**
     * Used for testing purposes mocking random function
     */
    function fulfillVRFMock() public {
        uint remainder = tokenIdCounter.sub(metadataRandomizedCounter);
        if (remainder > 100) remainder = 100;

        uint randomWord = uint(keccak256(
            abi.encodePacked(block.difficulty, block.timestamp, uint(234), uint(1982)
        )));

        for (uint i = 0; i < remainder; i++) {
            randomMetadata(randomWord, tokenIdCounter + i);
        }

        metadataRandomizedCounter.add(remainder);
    }

    function mint(uint16[] calldata traits) public payable nonReentrant {
        require(tokenIdCounter < maxSupply, "Total supply reached");
        tokenIdCounter += 1;

        uint excessAmount = msg.value.sub(tokenPrice);

        if (excessAmount > 0) {
            (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
            require(returnExcessStatus, "Failed to return excess.");
        }

        chosenTraits[tokenIdCounter] = traits;
        _mint(_msgSender(), tokenIdCounter);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        string memory encodedMetadata = '';
        string memory urlParams = '';

        for (uint i = 0; i < traitIndexes[tokenId].length; i++) {
            encodedMetadata = string(abi.encodePacked(
                encodedMetadata,
                '{"trait_type":"',
                metadata.randomTraits[traitIndexes[tokenId][i].traitIndex],
                '", "value":"',
                metadata.randomValues[traitIndexes[tokenId][i].traitIndex][traitIndexes[tokenId][i].valueIndex],
                '"}',
                i == traitIndexes[tokenId].length ? '' : ',')
            );

            urlParams = string(abi.encodePacked(
                urlParams,
                metadata.randomTraits[traitIndexes[tokenId][i].traitIndex],
                '=',
                metadata.randomValues[traitIndexes[tokenId][i].traitIndex][traitIndexes[tokenId][i].valueIndex],
                '&'
            ));
        }

        for (uint i = 0; i < metadata.choosableTraits.length; i++) {
            encodedMetadata = string(abi.encodePacked(
                encodedMetadata,
                '{"trait_type":"',
                metadata.choosableTraits[i],
                '", "value":"',
                metadata.choosableValues[i][chosenTraits[tokenId][i]],
                '"}',
                i == metadata.choosableTraits.length - 1 ? '' : ',')
            );

            urlParams = string(abi.encodePacked(
                urlParams,
                metadata.choosableTraits[i],
                '=',
                metadata.choosableValues[i][chosenTraits[tokenId][i]],
                '&'
            ));
        }        

        string memory encoded = string(
            abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(
                bytes(
                abi.encodePacked(
                    '{"name":"',
                    nftName,
                    ' #',
                    HelperFunctions.toString(tokenId),
                    '", "description":"',
                    'Lago Pass Description',
                    '", "image": "',
                    'https://lagoframe.com/nft?',
                    urlParams,
                    '", "attributes": [',
                    encodedMetadata,
                    '] }'
                )
                )
            )
            )
        );

        return encoded;
    }

    function withdraw(address _to, uint amount) public {
        require(msg.sender == deployer);
        payable(_to).call{value:amount, gas:200000}("");
    }
}
