# Project for Registry NFT (Test project for Valory)

### Install packages, and configure hardhat project
```
yarn install
vi .env
vi hardhat.config.js
```

### Edit main contract
```
vi ./contracts/*.sol
```

### Compile contract
```
npx hardhat compile
```

### Run hardhat node (or run Ganache) to deploy contract to test
```
npx hardhat node
```

### Create deploy script and deploy contract
```
vi ./scripts/deploy.js
npx hardhat run --network hardhat scripts/deploy.js
```
