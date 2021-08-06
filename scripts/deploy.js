// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers} = require("hardhat");

async function main() {
  const accounts = await ethers.getSigners()
  const owner = await accounts[0].getAddress()

  console.log('Deploying Registry NFT.....')
  const registryNFT = await (await ethers.getContractFactory('RegistryNFT')).deploy()
  await registryNFT.deployed()
  const tx = registryNFT.deployTransaction
  const result = await tx.wait()
  if (!result.status) {
    console.log('Deploying Registry NFT TRANSACTION FAILED!!! ---------------')
    console.log('Transaction hash:' + tx.hash)
    throw (Error('failed to deploy Registry NFT'))
  }
  console.log('Certificate deploy transaction hash:' + tx.hash)
  console.log('Certificate deployed to:', registryNFT.address)

  return {
    accounts: accounts,
    registryNFT: registryNFT,
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
}

exports.deploy = main
