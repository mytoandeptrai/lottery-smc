# DLottery Smart Contract

A decentralized lottery system built on Ethereum and BSC networks.

## Features

- Buy lottery tickets with ETH/BNB
- Automatic random winner selection
- Prize withdrawal mechanism
- Admin controls for contract management
- Pausable functionality for emergencies

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- MetaMask or another Web3 wallet
- Some test ETH/BNB for deployment and testing

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/lottery-smc.git
cd lottery-smc
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file based on `.env.example`:
```bash
cp .env.example .env
```

4. Fill in your environment variables in the `.env` file:
```
# Network RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your-infura-project-id
BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/

# Private keys for deployment
PRIVATE_KEY=your_private_key_here

# API Keys for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
BSCSCAN_API_KEY=your_bscscan_api_key
```

## Testing

### Running Tests

Run the test suite:
```bash
npm run test
```

This will execute all test cases defined in the `test` directory.

### Test Coverage

To check test coverage:
```bash
npx hardhat coverage
```

### Test Structure

The test suite is organized into several sections:

1. **Deployment Tests**: Verify that the contract deploys correctly with the right initial values
2. **Lottery Operations Tests**: Test buying tickets, performing draws, and prize withdrawals
3. **Admin Operations Tests**: Test admin functions like pausing, unpausing, and changing ticket price
4. **Edge Cases**: Test special scenarios like no winner situations

### Writing New Tests

To add new tests, create or modify files in the `test` directory. Follow the existing pattern:

```javascript
describe("Feature Name", function () {
  it("Should do something specific", async function () {
    // Test code here
  });
});
```

## Deployment

### Local Deployment

1. Start a local Hardhat node:
```bash
npm run node
```

2. In a new terminal, deploy the contract to the local network:
```bash
npm run deploy:local
```

### Sepolia Testnet Deployment

Before deploying to Sepolia, you need:

1. **Test ETH**: Get some Sepolia test ETH from a faucet like [Sepolia Faucet](https://sepoliafaucet.com/)
2. **RPC URL**: An Infura, Alchemy, or other provider URL for Sepolia network
3. **Private Key**: Your wallet's private key (keep this secure!)
4. **Etherscan API Key**: For contract verification

Then deploy:
```bash
npm run deploy:sepolia
```

### BSC Testnet Deployment

Before deploying to BSC Testnet, you need:

1. **Test BNB**: Get some BSC Testnet BNB from a faucet like [BSC Testnet Faucet](https://testnet.bnbchain.org/faucet-smart)
2. **RPC URL**: The BSC Testnet RPC URL (provided in .env.example)
3. **Private Key**: Your wallet's private key (keep this secure!)
4. **BSCScan API Key**: For contract verification

Then deploy:
```bash
npm run deploy:bsc
```

## Contract Verification

After deployment, the contract will be automatically verified on Etherscan/BSCScan if you have provided the appropriate API keys in your `.env` file.

## Contract Interaction

You can interact with the deployed contract using:

1. Etherscan/BSCScan interface
2. Web3 libraries like ethers.js or web3.js
3. Hardhat console:
```bash
npm run console:local
# or
npm run console:sepolia
# or
npm run console:bsc
```

4. Using the interaction script:
```bash
npm run interact -- <contract-address>
```

## License

MIT
