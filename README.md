# StackCredit Protocol

[![Clarity Version](https://img.shields.io/badge/Clarity-3.0-blue)](https://clarity.guide/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)](tests/)

## Overview

StackCredit is a revolutionary decentralized lending ecosystem built on Bitcoin's Layer 2 that transforms traditional credit scoring through blockchain transparency and programmable trust mechanisms. The protocol reimagines lending by creating an autonomous credit infrastructure where borrowers earn reputation through verifiable on-chain behavior.

### Key Features

🏦 **Autonomous Credit Infrastructure** - Build portable credit scores that transcend traditional banking limitations

📈 **Dynamic Loan Terms** - Loan conditions adjust automatically based on proven creditworthiness

🔒 **Intelligent Collateral Management** - Smart collateral requirements based on credit scores

⚡ **Bitcoin-Secured Finality** - Leverages Stacks' unique Bitcoin finality for maximum security

🌐 **Decentralized Financial Identity** - Create a truly decentralized financial identity backed by Bitcoin

## Table of Contents

- [Architecture](#architecture)
- [Protocol Mechanics](#protocol-mechanics)
- [Getting Started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [API Reference](#api-reference)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## Architecture

### Core Components

1. **Credit Profiles** - Comprehensive on-chain credit scoring system
2. **Loan Registry** - Immutable loan tracking with detailed metrics
3. **Portfolio Management** - Multi-loan portfolio tracking per user
4. **Dynamic Pricing** - Algorithmic interest rate and collateral calculations

### Protocol Constants

| Parameter | Value | Description |
|-----------|-------|-------------|
| Min Credit Score | 300 | Starting credit score for new users |
| Max Credit Score | 850 | Maximum achievable credit score |
| Loan Eligibility | 500 | Minimum credit score for borrowing |
| Max Active Loans | 3 | Maximum concurrent loans per user |
| Max Loan Duration | 26,280 blocks | ~6 months maximum loan term |
| Base Interest Rate | 12% APR | Starting interest rate |
| Max Collateral Ratio | 150% | Maximum collateral requirement |

## Protocol Mechanics

### Credit Scoring Algorithm

StackCredit employs a sophisticated credit scoring system that considers:

- **Payment History**: On-time repayments increase scores
- **Loan Diversity**: Different loan sizes affect score improvements
- **Repayment Timing**: Early repayments may provide additional benefits
- **Default Penalties**: Missed payments significantly impact scores

### Dynamic Loan Terms

#### Collateral Requirements

```clarity
;; Higher credit scores = Lower collateral requirements
;; Formula: MAX_RATIO - ((credit_score - MIN_SCORE) * 50 / SCORE_RANGE)
```

#### Interest Rates

```clarity
;; Better credit scores = Lower interest rates
;; Formula: BASE_RATE - ((credit_score - MIN_SCORE) * 600 / SCORE_RANGE)
;; Minimum: 6% APR
```

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- [Node.js](https://nodejs.org/) v18+
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/eddy-kaz/StackCredit.git
cd StackCredit
```

2. **Install dependencies**

```bash
npm install
```

3. **Check contract syntax**

```bash
clarinet check
```

4. **Run tests**

```bash
npm test
```

### Basic Usage

#### 1. Create Credit Profile

```clarity
(contract-call? .stack-credit create-credit-profile)
```

#### 2. Preview Loan Terms

```clarity
(contract-call? .stack-credit preview-loan-terms tx-sender u1000000)
```

#### 3. Request Loan

```clarity
(contract-call? .stack-credit request-loan u1000000 u1500000 u4380)
```

#### 4. Repay Loan

```clarity
(contract-call? .stack-credit repay-loan u1 u1120000)
```

## Development

### Project Structure

```text
StackCredit/
├── contracts/
│   └── stack-credit.clar      # Main protocol contract
├── tests/
│   └── stack-credit.test.ts   # Comprehensive test suite
├── settings/
│   ├── Devnet.toml           # Development network settings
│   ├── Testnet.toml          # Testnet configuration
│   └── Mainnet.toml          # Production settings
├── Clarinet.toml             # Clarinet project configuration
├── package.json              # Node.js dependencies
└── vitest.config.js          # Test configuration
```

### Local Development

1. **Start Clarinet console**

```bash
clarinet console
```

2. **Deploy contract locally**

```clarity
::deploy_contracts
```

3. **Interact with contract**

```clarity
(contract-call? .stack-credit get-protocol-stats)
```

### Watch Mode Development

```bash
npm run test:watch
```

This monitors contract and test files for changes and automatically runs tests.

## Testing

### Running Tests

```bash
# Run all tests
npm test

# Run tests with coverage and cost analysis
npm run test:report

# Watch mode for development
npm run test:watch
```

### Test Coverage

The test suite covers:

- ✅ Credit profile creation and management
- ✅ Loan request validation and processing
- ✅ Repayment processing and credit score updates
- ✅ Collateral management and release
- ✅ Default processing and penalties
- ✅ Administrative functions
- ✅ Edge cases and error conditions

## API Reference

### Public Functions

#### `create-credit-profile()`

Creates a new credit profile for the caller.

**Returns:** `(response bool uint)`

#### `request-loan(amount uint, collateral uint, duration uint)`

Requests a loan with specified terms.

**Parameters:**

- `amount`: Loan amount in microSTX
- `collateral`: Collateral amount in microSTX  
- `duration`: Loan duration in blocks

**Returns:** `(response uint uint)` - Loan ID on success

#### `repay-loan(loan-id uint, payment-amount uint)`

Makes a payment towards an active loan.

**Parameters:**

- `loan-id`: ID of the loan to repay
- `payment-amount`: Payment amount in microSTX

**Returns:** `(response bool uint)`

### Read-Only Functions

#### `get-credit-profile(user principal)`

Retrieves comprehensive credit profile for a user.

#### `get-loan-details(loan-id uint)`

Gets detailed information about a specific loan.

#### `preview-loan-terms(user principal, amount uint)`

Calculates loan terms without creating a loan.

#### `get-protocol-stats()`

Returns protocol-wide statistics and metrics.

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-UNAUTHORIZED | Caller not authorized |
| u101 | ERR-INSUFFICIENT-FUNDS | Insufficient funds/collateral |
| u102 | ERR-INVALID-AMOUNT | Invalid amount specified |
| u103 | ERR-LOAN-NOT-EXISTS | Loan does not exist |
| u104 | ERR-LOAN-DEFAULTED | Loan is in default status |
| u105 | ERR-CREDIT-TOO-LOW | Credit score below minimum |
| u106 | ERR-TOO-MANY-LOANS | Maximum active loans exceeded |
| u107 | ERR-PAYMENT-NOT-DUE | Payment not yet due |
| u108 | ERR-INVALID-DURATION | Invalid loan duration |

## Security

### Security Features

- **Collateral Protection**: Loans are over-collateralized based on credit scores
- **Credit Score Validation**: Multiple validation layers prevent manipulation
- **Principal Verification**: All operations verify caller identity
- **State Consistency**: Atomic operations ensure consistent state
- **Admin Controls**: Limited administrative functions for protocol maintenance

### Audit Status

⚠️ **This contract has not been audited.** Do not use in production without a comprehensive security audit.

### Known Limitations

- No oracle integration for collateral price feeds
- Fixed interest calculation (no compounding)
- Limited to STX tokens only
- No flash loan protection mechanisms

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Ensure all tests pass: `npm test`
5. Check contract syntax: `clarinet check`
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

### Code Style

- Follow Clarity best practices
- Include comprehensive comments
- Add tests for new functionality
- Maintain backwards compatibility

## Roadmap

### Phase 1: Core Protocol ✅

- [x] Basic credit scoring
- [x] Loan creation and repayment
- [x] Collateral management

### Phase 2: Enhanced Features (Q4 2025)

- [ ] Oracle integration for price feeds
- [ ] Multi-token support
- [ ] Governance token implementation
- [ ] Liquidation mechanisms

### Phase 3: Advanced Features (Q1 2026)

- [ ] Flash loans
- [ ] Cross-chain integration
- [ ] Advanced credit scoring models
- [ ] Insurance pools

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Stacks Foundation](https://stacks.org/) for the robust blockchain infrastructure
- [Clarinet](https://github.com/hirosystems/clarinet) for excellent development tools
- The Bitcoin and Stacks communities for inspiration and support
