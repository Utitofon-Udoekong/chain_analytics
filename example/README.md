# Chain Analytics Example App

This is a simple Flutter counter app that demonstrates how to use `chain_analytics` to track user events on the blockchain.

## Features

- **Counter**: Increment/decrement buttons that track clicks
- **Event Tracking**: Each button click is sent to Base Sepolia testnet
- **Batch Processing**: Events are batched and compressed before sending
- **Offline Support**: Events are queued locally and sent when online
- **Real-time UI**: Shows event count and last transaction hash

## Setup Instructions

### 1. Install Dependencies

```bash
cd example
flutter pub get
```

### 2. Generate a Burner Wallet

You need a private key for a burner wallet that will send analytics transactions.

#### Option A: Using MetaMask

1. Install [MetaMask](https://metamask.io/)
2. Switch to Base Sepolia testnet
3. Create a new account (this will be your burner wallet)
4. Copy the private key:
   - Click the account name to copy address
   - Click the three dots → Account Details → Export Private Key
   - Enter your password
   - Copy the private key

#### Option B: Using Web3 Tools

```bash
# Using Node.js with web3
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Or use any Ethereum key generator. The private key should be:
- 66 characters long (including `0x` prefix)
- Hexadecimal format

### 3. Get Base Sepolia ETH

You need testnet ETH to pay for gas:

1. Get testnet ETH from [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
2. Send a small amount (0.01-0.05 ETH) to your burner wallet
3. Verify balance on [Sepolia BaseScan](https://sepolia.basescan.org/)

**Alternative Faucets:**
- [QuickNode](https://faucet.quicknode.com/base/sepolia)
- [Chainlink Faucet](https://faucets.chain.link/)

### 4. Configure the App

Open `lib/main.dart` and replace the placeholder:

```dart
privateKey: 'YOUR_PRIVATE_KEY_HERE', // Replace with your burner wallet private key
```

Example:
```dart
privateKey: '0xabc123...your64charprivatekey...',
```

### 5. Run the App

```bash
flutter run
```

## Expected Costs

### Testnet (Base Sepolia)

- **Gas per batch**: ~21,000 gas
- **Current gas price**: ~0.0000001 ETH per gas
- **Cost per batch**: ~0.002 ETH ($0.004 at $2/ETH)
- **With batching (50 events/batch)**: ~$0.00008 per event

### Mainnet Estimates (for reference only)

- **Gas per batch**: ~21,000 gas
- **Base mainnet gas price**: ~0.01 gwei
- **Cost per batch**: ~0.00021 ETH
- **With batching (50 events/batch)**: ~$0.000004 per event

**Note**: These are estimates. Actual costs depend on network congestion and gas prices.

## How It Works

1. **Button Click** → Event tracked locally
2. **Batch Collection** → Events collected until batch size (10) or time limit (1 min)
3. **Compression** → Batch compressed with gzip (~70% reduction)
4. **Transaction** → Sent to dead address on Base Sepolia
5. **Persistence** → Events stored permanently on blockchain

## Testing

### Check Event Tracking

- Click increment/decrement buttons
- Watch the "Events tracked" counter increase
- Click "Flush to Blockchain" to send immediately

### Verify on Blockchain

1. Click "Flush to Blockchain"
2. Copy the transaction hash from logs
3. Visit `https://sepolia.basescan.org/tx/<hash>`
4. Decode the transaction data to see your events

### Debug Logs

The app runs with `debug: true`, so you'll see detailed logs in the console:

```
[ChainAnalytics] [INFO] [2025-01-11 07:50:00] Initializing ChainAnalytics for app: chain_analytics_demo
[ChainAnalytics] [DEBUG] [2025-01-11 07:50:01] Session ID: abc-123...
[ChainAnalytics] [DEBUG] [2025-01-11 07:50:02] Event enqueued: event-456
[ChainAnalytics] [INFO] [2025-01-11 07:50:05] Sending batch batch-789 with 10 events
[ChainAnalytics] [INFO] [2025-01-11 07:50:06] Batch sent successfully. TX: 0xabc...
```

## Configuration Options

In `main.dart`, you can customize:

```dart
ChainAnalyticsConfig(
  appId: 'chain_analytics_demo',           // Your app identifier
  chain: SupportedChain.baseSepolia,       // Blockchain network
  privateKey: '0x...',                     // Burner wallet key
  rpcUrl: 'https://sepolia.base.org',      // RPC endpoint
  batchConfig: const BatchConfig(
    maxBatchSize: 10,                      // Events per batch
    maxBatchInterval: Duration(minutes: 1), // Auto-send interval
  ),
  debug: true,                              // Enable logs
  enableOfflineQueue: true,                // Queue when offline
  hashUserIds: true,                       // Privacy mode
),
```

## Troubleshooting

### "Chain ID mismatch" error
- Make sure you're using `SupportedChain.baseSepolia` for Base Sepolia
- Check that your RPC is correct

### "Insufficient funds" error
- Get more testnet ETH from the faucet
- Check your balance on BaseScan

### Events not sending
- Check internet connection
- Verify private key format (must start with `0x`)
- Enable debug mode to see detailed logs
- Try clicking "Flush to Blockchain" manually

## Security Notes

⚠️ **IMPORTANT**: This example uses a public private key for demonstration. 

**DO NOT**:
- Use the same key in production
- Store private keys in code
- Use keys with real funds
- Commit keys to version control

**DO**:
- Generate a unique burner wallet for each app
- Use environment variables or secure storage
- Fund with minimal gas only
- Add the key to `.gitignore`

## Next Steps

- Integrate into your own Flutter app
- Configure production chains (Base, Polygon, Arbitrum)
- Set up monitoring and alerting
- Build dashboards using on-chain data

## Support

- Check the main [README](../README.md) for full documentation
- See [QUICK_START.md](../QUICK_START.md) for detailed guide
- Review [CHANGELOG](../CHANGELOG.md) for updates


