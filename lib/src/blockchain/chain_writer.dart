import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';

import '../chain_analytics_config.dart';
import '../models/analytics_event.dart';
import '../exceptions/chain_analytics_exception.dart';
import '../utils/logger.dart';

class ChainWriter {
  final ChainAnalyticsConfig config;
  final AnalyticsLogger logger;

  Web3Client? _client;
  EthPrivateKey? _credentials;
  int? _chainId;

  ChainWriter({required this.config, required this.logger});

  /// Initialize the chain writer
  Future<void> initialize() async {
    try {
      logger.info('Initializing ChainWriter for ${config.chain.name}');

      // Create Web3 client
      _client = Web3Client(config.getRpcUrl(), http.Client());

      // Create credentials from private key
      _credentials = EthPrivateKey.fromHex(config.privateKey);

      // Get and verify chain ID
      _chainId = (await _client!.getChainId()).toInt();

      if (_chainId != config.chain.chainId) {
        throw ChainWriteException(
          'Chain ID mismatch. Expected ${config.chain.chainId}, got $_chainId',
        );
      }

      final address = _credentials!.address;
      logger.info('ChainWriter initialized. Wallet: ${address.toString()}');
      logger.debug('Chain ID verified: $_chainId');

      EtherAmount balance = await _client!.getBalance(address);
      logger.info('Wallet balance: ${balance.getValueInUnit(EtherUnit.ether)} ETH');
      if (balance.getValueInUnit(EtherUnit.ether) < 0.001) {
        logger.error('Wallet has insufficient funds. Please fund your burner wallet with testnet ETH.');
        logger.error('Wallet address: ${address.toString()}');
        logger.error('Faucet: ${config.chain.isTestnet ? "Get testnet ETH from faucet" : "Add ETH to wallet"}');
        throw ChainWriteException(
          'Wallet has insufficient funds. Please fund your burner wallet with testnet ETH.',
        );
      }
    } catch (e, stackTrace) {
      logger.error('Failed to initialize ChainWriter', e, stackTrace);
      throw ChainWriteException(
        'Failed to initialize ChainWriter',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send a batch of events to the blockchain
  Future<String> sendBatch(EventBatch batch) async {
    if (_client == null || _credentials == null) {
      throw ChainWriteException('ChainWriter not initialized');
    }

    try {
      logger.info(
        'Preparing to send batch ${batch.batchId} with ${batch.events.length} events',
      );

      // Compress batch
      final compressedData = batch.toCompressedBytes();
      logger.debug(
        'Batch compressed: ${batch.sizeBytes} bytes -> ${compressedData.length} bytes',
      );

      // Dead address for calldata mode (cheaper than contract storage)
      final deadAddress = EthereumAddress.fromHex(
        '0x000000000000000000000000000000000000dEaD',
      );

      // Build transaction
      final transaction = Transaction(to: deadAddress, data: compressedData);

      // Estimate gas
      final estimatedGas = await _client!.estimateGas(
        sender: _credentials!.address,
        to: deadAddress,
        data: compressedData,
      );

      // Add 20% buffer to gas estimate
      final gasLimit = BigInt.from(
        (estimatedGas.toDouble() * 1.2).toInt(),
      ).toInt();
      logger.debug('Estimated gas: $estimatedGas, using limit: $gasLimit');

      // Send with retry logic
      final txHash = await _sendWithRetry(
        transaction.copyWith(maxGas: gasLimit),
        0,
      );

      logger.info('Batch sent successfully!');
      logger.info('Transaction hash: $txHash');
      logger.info('Explorer: ${config.chain.getTransactionUrl(txHash)}');

      return txHash;
    } catch (e, stackTrace) {
      logger.error('Failed to send batch ${batch.batchId}', e, stackTrace);
      throw ChainWriteException(
        'Failed to send batch to chain',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send transaction with exponential backoff retry
  Future<String> _sendWithRetry(Transaction transaction, int attempt) async {
    try {
      logger.debug(
        'Sending transaction (attempt ${attempt + 1}/${config.batchConfig.maxRetries + 1})',
      );

      final txHash = await _client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: _chainId,
      );

      return txHash;
    } catch (e) {
      // Check if we should retry
      if (attempt < config.batchConfig.maxRetries) {
        // Calculate exponential backoff delay
        final delayMs =
            config.batchConfig.retryDelay.inMilliseconds * (1 << attempt);
        final delay = Duration(milliseconds: delayMs);

        logger.info(
          'Transaction failed, retrying in ${delay.inSeconds}s... (attempt ${attempt + 1})',
        );
        logger.debug('Error: $e');

        await Future.delayed(delay);
        return _sendWithRetry(transaction, attempt + 1);
      }

      // Max retries reached
      logger.error('Transaction failed after ${attempt + 1} attempts');

      // Provide helpful error message for insufficient funds
      if (e.toString().contains('insufficient funds')) {
        logger.error(
          'Wallet has insufficient funds. Please fund your burner wallet with testnet ETH.',
        );
        logger.error('Wallet address: ${_credentials!.address}');
        logger.error(
          'Faucet: ${config.chain.isTestnet ? "Get testnet ETH from faucet" : "Add ETH to wallet"}',
        );
      }

      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _client?.dispose();
    logger.debug('ChainWriter disposed');
  }
}
