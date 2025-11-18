# Equity Trading Platform

A comprehensive **Rails 8** application for algorithmic equity trading with support for multiple Indian brokers (Zerodha, Upstox, Angel One). Build, backtest, and deploy automated trading strategies with real-time market data streaming and advanced technical analysis.

![Rails](https://img.shields.io/badge/Rails-8.0.2-red?logo=rubyonrails)
![Ruby](https://img.shields.io/badge/Ruby-3.4.5-red?logo=ruby)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Latest-blue?logo=postgresql)
![License](https://img.shields.io/badge/License-MIT-green)

## Table of Contents

- [Features](#features)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Broker Integration](#broker-integration)
  - [Creating Strategies](#creating-strategies)
  - [Running Background Jobs](#running-background-jobs)
- [Architecture](#architecture)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

---

## Features

### Core Functionality

- **Multi-Broker Support**: Seamlessly integrate with Zerodha Kite Connect, Upstox API v3, and Angel One
- **OAuth 2.0 Authentication**: Secure broker authorization with CSRF protection
- **Real-Time Market Data**: WebSocket-based live price feeds using Upstox Market Data Feed v3
- **Automated Trading Strategies**: Build and deploy algorithmic strategies with custom entry/exit rules
- **Technical Analysis**: 50+ built-in technical indicators for strategy development
- **Screeners**: Create custom stock screeners with dynamic filtering rules
- **Order Management**: Full order lifecycle management with state machine (AASM)
- **Portfolio Tracking**: Sync and monitor holdings across multiple brokers
- **Historical Data**: Access OHLC candle data from 2000 onwards
- **Backtesting**: Test strategies against historical data before deployment
- **Audit Trail**: Complete version history of strategy changes (PaperTrail)
- **Notifications**: Push notifications for order events and strategy execution

### Strategy Types

1. **Instrument-Based**: Manually select stocks/instruments for trading
2. **Screener-Based**: Automatically trade instruments from screener results
3. **Rule-Based**: Custom entry/exit logic using technical indicators

### Technical Features

- **Multi-Database Architecture**: PostgreSQL (primary) + SQLite (cache/queue/cable)
- **Background Job Processing**: Sidekiq with scheduled tasks (sidekiq-cron)
- **State Management**: Redis for WebSocket state and live market data caching
- **Soft Deletes**: Recoverable order deletion (Discard gem)
- **Single Table Inheritance**: Flexible broker-specific implementations
- **Security**: Comprehensive input validation against code injection attacks
- **Responsive UI**: Bootstrap 5 + Hotwire (Turbo + Stimulus)

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| **Framework** | Ruby on Rails 8.0.2 |
| **Language** | Ruby 3.4.5 |
| **Primary Database** | PostgreSQL |
| **Cache/Queue** | SQLite3 (Solid Cache, Solid Queue) |
| **Background Jobs** | Sidekiq 7.x + Sidekiq-cron |
| **WebSocket** | Faye-WebSocket + EventMachine |
| **Message Protocol** | Google Protobuf |
| **Cache/State Store** | Redis 6+ |
| **Frontend** | Hotwire (Turbo + Stimulus), Bootstrap 5.3.3 |
| **Template Engine** | HAML |
| **Testing** | RSpec + FactoryBot + Faker |
| **Deployment** | Kamal (Docker-based) |

---

## Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby**: 3.4.5 (use rbenv or rvm)
- **Rails**: 8.0.2+
- **PostgreSQL**: 12+ (for primary database)
- **Redis**: 6.0+ (for Sidekiq and WebSocket state)
- **Node.js**: 18+ (for asset compilation)
- **Bundler**: 2.5+
- **Git**: For version control

### Broker API Credentials

You'll need API credentials from at least one broker:

- **Zerodha**: [Get API Key](https://kite.trade/)
- **Upstox**: [Create App](https://upstox.com/developer/api-documentation/)
- **Angel One**: [Register for API](https://smartapi.angelbroking.com/)

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/equity_trading.git
cd equity_trading
```

### 2. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript dependencies (if any)
npm install
```

### 3. Database Setup

Configure your database credentials in `.env` or export as environment variables:

```bash
export DATABASE_USERNAME=your_db_user
export DATABASE_PASSWORD=your_db_password
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
```

Create and migrate databases:

```bash
# Create all databases (primary, cache, queue, cable)
bin/rails db:create

# Run migrations for all databases
bin/rails db:migrate

# Seed initial data (optional)
bin/rails db:seed
```

### 4. Redis Setup

Start Redis server:

```bash
# macOS (Homebrew)
brew services start redis

# Ubuntu/Debian
sudo systemctl start redis

# Or run manually
redis-server
```

Configure Redis URL (optional, defaults to `redis://localhost:6379/0`):

```bash
export REDIS_URL=redis://localhost:6379/0
```

### 5. Build Assets

```bash
# Build CSS (Bootstrap + custom styles)
bin/rails css:build
```

---

## Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Database
DATABASE_USERNAME=admin
DATABASE_PASSWORD=admin
DATABASE_HOST=localhost
DATABASE_PORT=5432
RAILS_MAX_THREADS=5

```

### Time Zone Configuration

The application is configured for **Indian Standard Time (IST)**. Market hours are:
- **Open**: 9:15 AM IST
- **Close**: 3:30 PM IST

Scheduled tasks automatically run based on IST timezone.

---

## Usage

### Starting the Application

#### Development Mode (All Services)

```bash
# Start Rails server, CSS watcher, and Sidekiq workers
bin/dev
```

This starts:
- Rails server on `http://localhost:3000`
- CSS build watcher
- Sidekiq workers (default + market_data queues)

#### Individual Services

```bash
# Rails server only
bin/rails server

# Sidekiq workers only
bundle exec sidekiq

# CSS watcher only
npm run build:css -- --watch
```

### First-Time Setup

1. **Create an Account**: Visit `http://localhost:3000` and sign up
2. **Add Broker Credentials**: Navigate to API Configurations and add your broker API keys
3. **Authorize Broker**: Click "Authorize" to complete OAuth flow
4. **Import Instruments**: Run in Rails console:

```ruby
# Import Upstox instruments (NSE)
UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")

# Import Zerodha instruments (requires authorized API config)
api_config = ApiConfiguration.find_by(api_name: :zerodha)
ZerodhaInstrument.import_instruments(
  api_key: api_config.api_key,
  access_token: api_config.access_token
)
```

### Broker Integration

#### Adding Broker Credentials

1. Navigate to **API Configurations** (`/api_configurations`)
2. Click **New API Configuration**
3. Select broker (Zerodha, Upstox, Angel One)
4. Enter API Key and API Secret
5. Save and click **Authorize** to complete OAuth flow

#### OAuth Authorization Flow

- **Zerodha**: Redirects to Kite Connect login, returns with `request_token`
- **Upstox**: Redirects to Upstox login, returns with authorization `code`
- Access tokens are automatically stored and refreshed

**Important**:
- Zerodha tokens expire at **6:00 AM IST** daily
- Upstox tokens are valid for extended periods
- Re-authorize when tokens expire

### Creating Strategies

#### 1. Instrument-Based Strategy

Select specific stocks manually:

```ruby
strategy = InstrumentBasedStrategy.create!(
  user: current_user,
  name: "Blue Chip Trading",
  entry_rule: "ltp() > 1000 && close('day', 1, 0) > close('day', 1, 1)",
  exit_rule: "ltp() < close('day', 1, 0) * 0.98",
  master_instrument_ids: [1, 2, 3], # Selected instrument IDs
  deploy: true
)
```

#### 2. Screener-Based Strategy

Create screener first, then link to strategy:

```ruby
# Create screener
screener = Screener.create!(
  user: current_user,
  name: "High Volume Breakout",
  rules: "close('day', 1, 0) > high('day', 1, 1) && ltp() > 500",
  active: true
)

# Scan instruments
screener.scan

# Create strategy based on screener
strategy = ScreenerBasedStrategy.create!(
  user: current_user,
  name: "Breakout Strategy",
  entry_rule: "ltp() > close('day', 1, 0) * 1.02",
  exit_rule: "ltp() < close('day', 1, 0) * 0.98",
  parameters: {
    screener_id: screener.id,
    screener_execution_time: "09:30" # Run screener at 9:30 AM
  },
  deploy: true
)
```

#### 3. Rule-Based Strategy

Define custom rules without pre-selecting instruments:

```ruby
strategy = RuleBasedStrategy.create!(
  user: current_user,
  name: "RSI Reversal",
  entry_rule: "rsi(14) < 30 && ltp() > close('day', 1, 0)",
  exit_rule: "rsi(14) > 70 || ltp() < close('day', 1, 0) * 0.95",
  parameters: {
    rules: "close('day', 1, 0) > 100 && close('day', 1, 0) < 5000"
  },
  deploy: true
)
```

### Available Technical Indicators

Use these in `entry_rule` and `exit_rule` expressions:

| Indicator | Syntax | Description |
|-----------|--------|-------------|
| **LTP** | `ltp()` | Last Traded Price (live during market hours) |
| **Close** | `close('day', 1, 0)` | Closing price (unit, interval, offset) |
| **Open** | `open('day', 1, 0)` | Opening price |
| **High** | `high('day', 1, 0)` | High price |
| **Low** | `low('day', 1, 0)` | Low price |
| **Current Time** | `current_time` | Current time (for time-based rules) |
| **Parse Time** | `parse_time('09:30')` | Parse time string |

**Parameters**:
- `unit`: `'day'`, `'minute'`, `'hour'`, `'week'`, `'month'`
- `interval`: `1`, `5`, `15`, `30`, `60` (for intraday)
- `offset`: `0` (current), `1` (previous), `2` (2 candles ago), etc.

**Examples**:

```ruby
# 5-minute candle data
close('minute', 5, 0)  # Current 5-min close
high('minute', 5, 1)   # Previous 5-min high

# Daily data
close('day', 1, 0)     # Today's close
open('day', 1, 1)      # Yesterday's open
```

### Running Background Jobs

The application uses **Sidekiq** for background job processing with scheduled cron tasks.

#### Scheduled Tasks (Monday-Friday, IST)

| Job | Schedule | Description |
|-----|----------|-------------|
| **Start Market Data** | 9:15 AM | Starts WebSocket connection at market open |
| **Schedule Strategy Execution** | 9:15 AM | Triggers entry rule scanning for deployed strategies |
| **Health Check** | Every 2 min (9 AM-3 PM) | Monitors WebSocket service health |
| **Stop Market Data** | 3:30 PM | Stops WebSocket connection at market close |
| **Sync Holdings** | 8:00 AM, 4:00 PM | Syncs holdings from brokers |
| **Sync Historical Data** | 8:30 AM | Updates OHLC data before market open |
| **Cleanup Logs** | 8:00 AM daily | Removes job logs older than 7 days |

#### Manual Job Control

```bash
# Start Sidekiq worker
bundle exec sidekiq

# Start specific queue
bundle exec sidekiq -q market_data

# Rails console commands
Upstox::StartWebsocketConnectionJob.perform_now
Zerodha::SyncHoldingsJob.perform_now
```

#### Market Data Service

```bash
# Start market data streaming
bin/rails market_data:start

# Stop market data streaming
bin/rails market_data:stop

# Check service status
bin/rails market_data:status

# Health check
bin/rails market_data:health_check
```

#### Monitoring Sidekiq

Access Sidekiq web UI at `/sidekiq` (requires authentication - add routes configuration).

---

## Architecture

### Database Schema

#### Multi-Database Configuration

- **Primary** (PostgreSQL): Users, Sessions, API Configurations, Instruments, Orders, Strategies
- **Cache** (SQLite): Solid Cache storage (`storage/equity_cache.sqlite3`)
- **Queue** (SQLite): Solid Queue jobs (`storage/equity_queue.sqlite3`)
- **Cable** (SQLite): Action Cable WebSocket (`storage/equity_cable.sqlite3`)

#### Key Models

**Users & Authentication**:
- `users` - User accounts with bcrypt password hashing
- `sessions` - Database-backed sessions (not cookie-based)

**Broker Integration**:
- `api_configurations` - Broker API credentials and OAuth tokens
- `holdings` - Portfolio holdings synced from brokers

**Instruments & Market Data**:
- `instruments` - Trading instruments (STI: UpstoxInstrument, ZerodhaInstrument)
- `master_instruments` - Cross-broker instrument mapping
- `instrument_histories` - Historical OHLC candle data

**Strategies & Orders**:
- `strategies` - Trading strategies (STI: InstrumentBased, ScreenerBased, RuleBased)
- `screeners` - Stock screeners with custom filtering rules
- `orders` - Order management (STI: ZerodhaOrder, UpstoxOrder)
- `versions` - Audit trail for strategy changes (PaperTrail)

**Notifications**:
- `notifications` - Polymorphic notifications
- `push_notifications` - Order and strategy event notifications

### Service Layer

Service objects are organized by broker namespace:

```
app/services/
├── upstox/
│   ├── oauth_service.rb          # OAuth 2.0 flow
│   ├── api_service.rb             # API operations
│   └── websocket_service.rb       # Real-time market data
└── zerodha/
    ├── oauth_service.rb           # Kite Connect OAuth
    ├── api_service.rb             # Kite API operations
    └── sync_holdings_service.rb   # Portfolio sync
```

### Background Jobs

```
app/jobs/
├── schedule_strategy_execution_job.rb  # Triggers strategy scanning
├── scan_entry_rule_job.rb              # Entry rule evaluation
├── scan_exit_rule_job.rb               # Exit rule evaluation
├── sync_instrument_history_job.rb      # Historical data sync
├── cleanup_job_logs_job.rb             # Log file maintenance
├── upstox/
│   ├── start_websocket_connection_job.rb
│   ├── stop_websocket_connection_job.rb
│   └── health_check_websocket_connection_job.rb
└── zerodha/
    └── sync_holdings_job.rb
```

### Real-Time Market Data Flow

1. **Authorization**: Fetch WebSocket URL from Upstox API
2. **Connection**: Establish WebSocket connection with EventMachine
3. **Subscription**: Subscribe to instrument tokens (NSE stocks)
4. **Message Decoding**: Parse Protobuf binary messages
5. **State Management**: Store connection state in Redis
6. **LTP Caching**: Cache Last Traded Prices in Redis for strategy evaluation
7. **Heartbeat Monitoring**: Auto-reconnect on connection failures

### Order Lifecycle (AASM State Machine)

```
pending → trigger_pending → open → completed
                ↓
            rejected
                ↓
            cancelled
```

**States**:
- `pending` - Order created but not yet placed
- `trigger_pending` - Stop-loss order waiting for trigger
- `open` - Order placed at exchange
- `completed` - Order fully executed
- `rejected` - Order rejected by broker/exchange
- `cancelled` - Order cancelled by user/system

---

## API Documentation

### Zerodha Kite Connect API

**Base URL**: `https://api.kite.trade`

**Endpoints Used**:
- `GET /instruments` - Download instrument master (CSV)
- `POST /session/token` - Exchange request_token for access_token
- `GET /orders` - Get order book
- `POST /orders/:variety` - Place order
- `PUT /orders/:variety/:order_id` - Modify order
- `DELETE /orders/:variety/:order_id` - Cancel order
- `GET /holdings` - Get portfolio holdings

**Authentication**: `Authorization: token api_key:access_token`

### Upstox API v3

**Base URL**: `https://api.upstox.com/v3`

**Endpoints Used**:
- `GET /feed/market-data-feed/authorize` - Get WebSocket URL
- `POST /v2/login/authorization/token` - Exchange code for token
- `GET /market-quote/ltp` - Get Last Traded Price
- `GET /historical-candle/:instrument_key/:interval/:to_date` - Historical OHLC
- `POST /order/place` - Place order
- `PUT /order/modify` - Modify order
- `DELETE /order/cancel` - Cancel order
- `GET /order/retrieve-all` - Get order book
- `GET /portfolio/short-term-positions` - Get positions
- `GET /portfolio/long-term-holdings` - Get holdings

**Authentication**: `Authorization: Bearer {access_token}`

---

## Testing

### Running Tests

```bash
# Run all specs
bundle exec rspec

# Run specific spec file
bundle exec rspec spec/models/api_configuration_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/api_configuration_spec.rb:10

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Test Structure

```
spec/
├── factories/          # FactoryBot factories
├── models/            # Model unit tests
├── controllers/       # Controller specs
├── services/          # Service object specs
├── jobs/              # Background job specs
└── support/           # Test helpers
```

### Testing Philosophy

- **Unit Tests**: Models, services, and job logic
- **Mock External APIs**: Use WebMock for broker API calls

### Continuous Integration

GitHub Actions CI pipeline runs on every pull request:

1. **Brakeman**: Security vulnerability scan
2. **Importmap Audit**: JavaScript dependency security
3. **Rubocop**: Code style enforcement
4. **RSpec**: Full test suite with PostgreSQL + Redis

```
# Run ci workflow, defined in ci.rb
bin/ci
```

---

## Deployment

### Kamal Deployment (Docker)

The application is configured for deployment with **Kamal** (Rails 8 default):

```bash
# Setup Kamal configuration
kamal setup

# Deploy application
kamal deploy

# Check deployment status
kamal app logs
```

### Environment Variables for Production

Set these on your production server:

```env
RAILS_ENV=production
SECRET_KEY_BASE=your_production_secret
DATABASE_URL=postgresql://user:password@localhost/equity_trading_production
REDIS_URL=redis://localhost:6379/0

```

### Production Checklist

- [ ] Set `SECRET_KEY_BASE` (run `bin/rails secret`)
- [ ] Configure production database (PostgreSQL)
- [ ] Setup Redis server
- [ ] Enable SSL/TLS (Let's Encrypt recommended)
- [ ] Configure SMTP for email notifications (optional)
- [ ] Setup monitoring (Sentry, New Relic, etc.)
- [ ] Enable log rotation
- [ ] Schedule database backups
- [ ] Configure firewall rules
- [ ] Setup process manager (systemd, supervisor)

### Running in Production

```bash
# Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# Run database migrations
RAILS_ENV=production bin/rails db:migrate

# Start application server (Puma)
RAILS_ENV=production bin/rails server

# Start Sidekiq workers
RAILS_ENV=production bundle exec sidekiq -d -L log/sidekiq.log
```

---

## Contributing

Contributions are welcome! Please follow these guidelines:

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-new-feature`
3. **Write tests** for your changes
4. **Run the test suite**: `bundle exec rspec`
5. **Run Rubocop**: `bundle exec rubocop -A`
6. **Commit your changes**: `git commit -am 'Add new feature'`
7. **Push to the branch**: `git push origin feature/my-new-feature`
8. **Create a Pull Request**

### Code Style

- Follow Ruby style guide (enforced by Rubocop)
- Write descriptive commit messages
- Add tests for new functionality
- Update documentation for user-facing changes

### Reporting Issues

Please use GitHub Issues to report bugs or request features. Include:

- **Description**: Clear description of the issue
- **Steps to Reproduce**: How to recreate the bug
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: Ruby version, Rails version, OS

---

## Security Considerations

### Data Protection

- **API Credentials**: Currently stored in plaintext. Consider encrypting with Rails encrypted attributes
- **Sessions**: Database-backed sessions (more secure than cookies for financial data)
- **OAuth Tokens**: CSRF state validation on all OAuth flows
- **Input Validation**: Comprehensive dangerous pattern blocking for user-defined rules

### Dangerous Pattern Protection

The application blocks 100+ dangerous patterns in user-defined strategy rules:

- System/command execution (`system`, `exec`, backticks)
- Code evaluation (`eval`, `send`, `instance_eval`)
- File/directory operations (`File`, `Dir`, `IO`)
- Database write operations (`create`, `update`, `delete`)
- Network/HTTP operations (`Net::`, `Socket`, `URI`)
- Environment manipulation (`ENV`, `exit`, `raise`)

### Best Practices

- Never commit API credentials to version control
- Use environment variables for sensitive configuration
- Regularly rotate access tokens
- Enable 2FA on broker accounts
- Run security audits: `bundle exec brakeman`
- Keep dependencies updated: `bundle update`

---

## Troubleshooting

### Common Issues

#### Database Connection Error

```bash
# Ensure PostgreSQL is running
sudo systemctl start postgresql

# Check credentials in .env
echo $DATABASE_USERNAME
```

#### Redis Connection Error

```bash
# Start Redis
redis-server

# Test connection
redis-cli ping
# Expected output: PONG
```

#### WebSocket Connection Fails

```bash
# Check if access token is valid
api_config = ApiConfiguration.find_by(api_name: :upstox)
api_config.token_expired?

# Re-authorize if needed
# Visit /api_configurations and click "Authorize"
```

#### Sidekiq Jobs Not Running

```bash
# Ensure Sidekiq is running
bundle exec sidekiq

# Check Redis connection
echo $REDIS_URL

# View Sidekiq logs
tail -f log/sidekiq.log
```

#### Assets Not Loading

```bash
# Rebuild CSS
bin/rails css:build

# Check if node_modules exists
npm install
```

---

## Roadmap

Future enhancements planned:

- [ ] Zerodha Websocket Implementation
- [ ] Upstox Order placing feature
- [ ] Angel One broker integration
- [ ] Back-testing engine with historical data
- [ ] Portfolio analytics dashboard
- [ ] Paper trading mode (simulation)
- [ ] Machine learning strategy recommendations
- [ ] Custom indicator builder

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Zerodha Kite Connect**: Broker API integration
- **Upstox API**: Real-time market data and trading
- **Rails Community**: Framework and gems
- **Bootstrap**: UI framework
- **AdminLTE**: Dashboard template

---

## Contact

For questions, feedback, or support:

- **GitHub Issues**: [Create an issue](https://github.com/yourusername/equity_trading/issues)

---

## Disclaimer

**This software is for educational purposes only.**

- Trading involves substantial risk of loss
- Past performance does not guarantee future results
- The developers are not responsible for any financial losses
- Always test strategies thoroughly before deploying with real capital
- Consult a financial advisor before making investment decisions
- Use at your own risk

**SEBI Disclaimer**: This application is not registered with SEBI. Users are responsible for compliance with all applicable regulations.

---

**Happy Trading! 📈**
