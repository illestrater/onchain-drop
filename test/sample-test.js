const { expect } = require("chai");
const { ethers } = require("hardhat");

const metadata = require('../metadata.json');

const vrfCoordinator = '0x6168499c0cFfCaCD319c818142124B7A15E857ab';
const link = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
const keyHash = '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc';
const subscriptionId = 677;

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("Drop", function () {
  const tokenPrice = ethers.utils.parseEther("0.0007");
  const maxSupply = 4000;
  const name = "Lago Frame";
  const symbol = "LAGO";

  it("Should randomize and show metadata", async function () {
    const Drop = await hre.ethers.getContractFactory("Drop");

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

    await drop.deployed();

    console.log("Contract deployed to:", drop.address);

    await drop.mint([0, 1, 1, 0], {value: tokenPrice });
    await drop.mint([1, 0, 1, 1], {value: tokenPrice });
    await drop.mint([1, 1, 2, 1], {value: tokenPrice });
    await drop.mint([0, 0, 0, 0], {value: tokenPrice });

    await drop.fulfillVRFMock();

    let test = await drop.tokenURI(1);
    console.log(base64toJSON(test));
    test = await drop.tokenURI(2);
    console.log(base64toJSON(test));
    test = await drop.tokenURI(3);
    console.log(base64toJSON(test));
    test = await drop.tokenURI(4);
    console.log(base64toJSON(test));
    // const tokenJSON = base64toJSON(test);
    // console.log(tokenJSON);
  });
});
