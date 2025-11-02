# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2024-11-01

### Added
- Initial release of chain_analytics
- Core analytics tracking (events, screens, user properties)
- SQLite-based offline event queue
- Automatic event batching (size and time-based)
- Blockchain integration via web3dart
- Support for Base, Polygon, and Arbitrum (mainnet + testnets)
- Privacy-first design with automatic user ID hashing
- Gzip compression for cost optimization
- Retry logic with exponential backoff
- Comprehensive example app
- Full test coverage

### Features
- Track custom events with properties
- Automatic screen view tracking
- Offline-first architecture
- Configurable batching (size/interval)
- Multi-chain support
- User opt-in/opt-out
- Session management
- Cost-effective (~$12/month for 200k events/day)

### Developer Experience
- Simple initialization
- Clean API design
- Extensive documentation
- Type-safe configuration
- Helpful error messages