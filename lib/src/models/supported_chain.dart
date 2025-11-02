enum SupportedChain {
  baseMainnet(
    chainId: 8453,
    name: 'Base',
    defaultRpcUrl: 'https://mainnet.base.org',
    explorerUrl: 'https://basescan.org',
  ),
  baseSepolia(
    chainId: 84532,
    name: 'Base Sepolia',
    defaultRpcUrl: 'https://sepolia.base.org',
    explorerUrl: 'https://sepolia.basescan.org',
  ),
  polygonMainnet(
    chainId: 137,
    name: 'Polygon',
    defaultRpcUrl: 'https://polygon-rpc.com',
    explorerUrl: 'https://polygonscan.com',
  ),
  polygonAmoy(
    chainId: 80001,
    name: 'Polygon Amoy',
    defaultRpcUrl: 'https://rpc-mumbai.maticvigil.com',
    explorerUrl: 'https://amoy.polygonscan.com',
  ),
  arbitrumMainnet(
    chainId: 42161,
    name: 'Arbitrum One',
    defaultRpcUrl: 'https://arbitrum.drpc.org',
    explorerUrl: 'https://arbiscan.io',
  ),
  arbitrumSepolia(
    chainId: 421614,
    name: 'Arbitrum Sepolia',
    defaultRpcUrl: 'https://arbitrum-sepolia.drpc.org',
    explorerUrl: 'https://sepolia.arbiscan.io',
  ),
  bnbMainnet(
    chainId: 56,
    name: 'BNB Chain',
    defaultRpcUrl: 'https://bsc.drpc.org',
    explorerUrl: 'https://bscscan.com',
  ),
  bnbTestnet(
    chainId: 97,
    name: 'BNB Chain Testnet',
    defaultRpcUrl: 'https://bsc-testnet.public.blastapi.io',
    explorerUrl: 'https://testnet.bscscan.com',
  ),
  tronMainnet(
    chainId: 728126428,
    name: 'Tron',
    defaultRpcUrl: 'https://api.trongrid.io/jsonrpc',
    explorerUrl: 'https://tronscan.org',
  );

  const SupportedChain({
    required this.chainId,
    required this.name,
    required this.defaultRpcUrl,
    required this.explorerUrl,
  });

  final int chainId;
  final String name;
  final String defaultRpcUrl;
  final String explorerUrl;

  bool get isTestnet =>
      this == SupportedChain.baseSepolia ||
      this == SupportedChain.polygonAmoy ||
      this == SupportedChain.arbitrumSepolia;

  /// Get explorer URL for a transaction hash
  String getTransactionUrl(String txHash) {
    return '$explorerUrl/tx/$txHash';
  }

  /// Get explorer URL for an address
  String getAddressUrl(String address) {
    return '$explorerUrl/address/$address';
  }
}
