const { expect } = require("chai");
const { ethers } = require("hardhat");

const metadata = require('../metadata.json');

const vrfCoordinator = '0x6168499c0cFfCaCD319c818142124B7A15E857ab';
const link = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
const keyHash = '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc';
const subscriptionId = 677;

describe("Drop", function () {
  const tokenPrice = ethers.utils.parseEther("0.0007");
  const maxSupply = 4000;
  const name = "Lago Frame";
  const symbol = "LAGO";

  it("Should return the new greeting once it's changed", async function () {
    const Drop = await hre.ethers.getContractFactory("Drop");
    console.log([
      metadata.chooseTraits,
      metadata.chooseProperties,
      metadata.randomTraits,
      metadata.randomTraitValues
    ]);
    const drop = await Drop.deploy(
      vrfCoordinator,
      link,
      keyHash,
      subscriptionId,
      name,
      symbol,
      tokenPrice,
      maxSupply,
      [
        metadata.chooseTraits,
        metadata.chooseProperties,
        metadata.randomTraits,
        metadata.randomTraitValues
      ],
      [
        metadata.randomTraitsChance,
        metadata.randomValuesChance
      ]
    );

    console.log([
      metadata.randomTraitsChance,
      metadata.randomValuesChance
    ])

    await drop.deployed();

    console.log("Contract deployed to:", drop.address);

    await drop.mint({value: tokenPrice });
    await drop.mint({value: tokenPrice });
    await drop.mint({value: tokenPrice });
    await drop.mint({value: tokenPrice });

    await drop.randomMetadata(77);
    await drop.randomMetadata(69);
    await drop.randomMetadata(777);
    await drop.randomMetadata(420);
    await drop.randomMetadata(0);
  });
});
