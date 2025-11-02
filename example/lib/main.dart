import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chain_analytics/chain_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ChainAnalytics
  await ChainAnalytics.initialize(
    ChainAnalyticsConfig(
      appId: 'chain_analytics_demo',
      chain: SupportedChain.baseSepolia,
      privateKey: 'YOUR_PRIVATE_KEY_HERE', // Replace with your burner wallet private key
      rpcUrl: 'YOUR_RPC_URL_HERE', // Base Sepolia RPC endpoint/ Base Sepolia RPC endpoint
      batchConfig: const BatchConfig(
        maxBatchSize: 10,
        maxBatchInterval: Duration(minutes: 1),
      ),
      debug: true, // Enable debug logging
      enableOfflineQueue: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chain Analytics Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  int _eventCount = 0;
  String? _lastTxHash;
  bool _isFlushing = false;

  @override
  void initState() {
    super.initState();
    _trackScreenView();
  }

  Future<void> _trackScreenView() async {
    await ChainAnalytics.screen('home');
    setState(() => _eventCount++);
  }

  Future<void> _incrementCounter() async {
    setState(() => _counter++);

    // Track button click
    await ChainAnalytics.track('button_clicked', {
      'action': 'increment',
      'counter_value': _counter,
    });

    setState(() => _eventCount++);

    // Check if batch should trigger
    if (_eventCount % 10 == 0) {
      _showBatchAlert();
    }
  }

  Future<void> _decrementCounter() async {
    setState(() => _counter--);

    // Track button click
    await ChainAnalytics.track('button_clicked', {
      'action': 'decrement',
      'counter_value': _counter,
    });

    setState(() => _eventCount++);

    // Check if batch should trigger
    if (_eventCount % 10 == 0) {
      _showBatchAlert();
    }
  }

  Future<void> _flushEvents() async {
    setState(() => _isFlushing = true);

    try {
      await ChainAnalytics.flush();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Events flushed to blockchain!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() => _lastTxHash = 'Check logs for TX hash');
        _eventCount = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error flushing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFlushing = false);
      }
    }
  }

  void _showBatchAlert() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch limit reached! Events will be sent soon.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showExplorer() {
    if (_lastTxHash != null && _lastTxHash!.isNotEmpty) {
      final url = SupportedChain.baseSepolia.getTransactionUrl(_lastTxHash!);

      // Copy to clipboard
      Clipboard.setData(ClipboardData(text: url));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction URL copied to clipboard'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              // Note: In a real app, you'd use url_launcher here
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Chain Analytics Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _flushEvents,
            tooltip: 'Flush Events',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Counter section
            Text('Counter', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('$_counter', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isFlushing ? null : _incrementCounter,
                  icon: const Icon(Icons.add),
                  label: const Text('Increment'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isFlushing ? null : _decrementCounter,
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrement'),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Analytics info section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blockchain Analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Events tracked', '$_eventCount'),
                  const SizedBox(height: 8),
                  _buildStatRow('Last TX Hash', _lastTxHash ?? 'None yet'),
                  if (_lastTxHash != null)
                    TextButton(
                      onPressed: _showExplorer,
                      child: const Text('View on Explorer'),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFlushing ? null : _flushEvents,
                      icon: _isFlushing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        _isFlushing ? 'Sending...' : 'Flush to Blockchain',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info text
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Each button click is tracked and will be sent to Base Sepolia',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
