// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const metadata = require('../metadata.json');

const vrfCoordinator = '0x6168499c0cFfCaCD319c818142124B7A15E857ab';
const link = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
const keyHash = '0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc';
const subscriptionId = 677;

const tokenPrice = ethers.utils.parseEther("0.0007");
const maxSupply = 4000;
const name = "Lago Frame";
const symbol = "LAGO";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Drop = await hre.ethers.getContractFactory("Drop");

  const args = [
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
  ];

  const drop = await Drop.deploy(...args);

  await drop.deployed();

  console.log('Drop contract deployed', drop.address);

  await new Promise(resolve => setTimeout(resolve, 20000));

  try {
    await hre.run("verify:verify", {
      address: drop.address,
      constructorArguments: args,
    });
  } catch (e) {
    console.log('got error', e);
  }

  console.log('Drop contract verified');

  await drop.mint([0, 1, 1, 0], {value: tokenPrice });
  await drop.mint([1, 0, 1, 1], {value: tokenPrice });
  await drop.mint([1, 1, 2, 1], {value: tokenPrice });

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
