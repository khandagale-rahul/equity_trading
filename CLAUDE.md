# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **Equity Trading** Rails 8 application for managing trading API configurations across multiple brokers (Zerodha, Upstox, Angel One). The app provides user authentication, allows users to securely store and manage their trading API credentials, and implements OAuth flows for broker authorization. It also manages trading instruments (stocks, options, futures) from multiple brokers using a unified data model.

## Technology Stack

- **Rails**: 8.0.2+
- **Ruby**: 3.4.5
- **Database**: PostgreSQL (primary), SQLite3 (cache, queue, cable)
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5.3.3, HAML templates
- **Background Jobs**: Sidekiq with Sidekiq-cron for scheduled tasks
- **WebSocket**: Faye-WebSocket with EventMachine for real-time market data
- **Message Protocol**: Google Protobuf for binary data decoding
- **Cache/State**: Redis for WebSocket connection state management
- **State Machine**: AASM gem for order state management
- **Soft Delete**: Discard gem for soft-deleting orders
- **Version Tracking**: PaperTrail gem for audit trail on Strategy model
- **Testing**: RSpec with FactoryBot and Faker
- **Deployment**: Kamal (Docker-based)

## Essential Commands

### Database
```bash
# Setup database
bin/rails db:create db:migrate

# Reset database
bin/rails db:reset

# Run migrations
bin/rails db:migrate

# Rollback migration
bin/rails db:rollback
```

### Server
```bash
# Start Rails server
bin/rails server

# Start with specific environment
RAILS_ENV=production bin/rails server

# Start full development stack (server, CSS watch, Sidekiq worker)
bin/dev
```

### Testing
```bash
# Run all specs
bundle exec rspec

# Run specific spec file
bundle exec rspec spec/models/api_configuration_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/api_configuration_spec.rb:10

# Run controller specs
bundle exec rspec spec/controllers/

# Run model specs
bundle exec rspec spec/models/
```

### Code Quality
```bash
# Run Rubocop
bundle exec rubocop

# Auto-correct Rubocop offenses
bundle exec rubocop -A

# Security scan with Brakeman
bundle exec brakeman
```

### Assets
```bash
# Build CSS (using cssbundling-rails)
bin/rails css:build

# Watch CSS for changes
bin/rails css:watch
```

### Console
```bash
# Rails console
bin/rails console

# Production console
RAILS_ENV=production bin/rails console

# Import instruments (in console)
UpstoxInstrument.import_from_upstox(exchange: "NSE_MIS")
ZerodhaInstrument.import_instruments(api_key: "your_key", access_token: "your_token")
```

### Rake Tasks

#### Market Data Operations
```bash
# Start market data service manually
bin/rails market_data:start

# Stop market data service manually
bin/rails market_data:stop

# Check market data service status
bin/rails market_data:status

# Run health check manually
bin/rails market_data:health_check

# View scheduled cron jobs
bin/rails market_data:scheduled
```

#### Job Log Management
```bash
# List all job log files with sizes and dates
bin/rails job_logs:list

# Clean up job logs older than N days (default: 7)
bin/rails job_logs:cleanup[7]

# Archive (compress) old job logs
bin/rails job_logs:archive[7]
```

### Background Jobs (Sidekiq)
```bash
# Start Sidekiq worker
bundle exec sidekiq

# Start Sidekiq with specific queue
bundle exec sidekiq -q market_data

# View Sidekiq web UI (mount in routes.rb first)
# Visit /sidekiq in browser
```

### Redis
```bash
# Connect to Redis CLI
redis-cli

# Check WebSocket service status
redis-cli GET upstox:market_data:status

# View connection stats
redis-cli GET upstox:market_data:connection_stats
```

### Generators
```bash
# Generate model
bin/rails generate model ModelName

# Generate controller
bin/rails generate controller ControllerName

# Generate migration
bin/rails generate migration MigrationName
```

## Architecture & Key Concepts

### Multi-Database Configuration

The application uses a **multi-database setup**:
- **Primary database** (PostgreSQL): Users, Sessions, API Configurations, Instruments
- **Cache database** (SQLite): Solid Cache storage at `storage/equity_cache.sqlite3`
- **Queue database** (SQLite): Solid Queue jobs at `storage/equity_queue.sqlite3`
- **Cable database** (SQLite): Action Cable at `storage/equity_cable.sqlite3`

Each non-primary database has its own migration path (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`).

**Time Zone**: The application is configured for "Kolkata" timezone (IST) in `config/application.rb`.

### Authentication System

Custom session-based authentication implemented in `app/controllers/concerns/Authentication` module:
- **Session management**: Database-backed sessions (not Rails default session cookies)
- **Current context**: Uses `Current.session` (thread-local) to track authenticated user
- **Cookie-based**: Signed, permanent cookies with `httponly` and `same_site: :lax`
- **Controllers**: Include `Authentication` concern, use `allow_unauthenticated_access` to skip auth

Key methods in Authentication concern:
- `start_new_session_for(user)` - Creates session after login
- `terminate_session` - Destroys session on logout
- `require_authentication` - Before action to enforce auth
- `after_authentication_url` - Redirect after login with return_to support

### Models & Relationships

**User** (`app/models/user.rb`):
- `has_secure_password` for bcrypt authentication
- `has_many :sessions, dependent: :destroy`
- `has_many :api_configurations, dependent: :destroy`
- `has_many :holdings, dependent: :destroy`
- Email normalization (strip + downcase)
- Phone validation: 10-15 digits, optional `+` prefix

**ApiConfiguration** (`app/models/api_configuration.rb`):
- Enum for `api_name`: `{ zerodha: 1, upstox: 2, angel_one: 3 }`
- Unique constraint: One API config per `[user_id, api_name]` combination
- Stores API credentials: `api_key` and `api_secret`
- OAuth token management: `access_token`, `token_expires_at`, `oauth_authorized_at`, `oauth_state`
- `redirect_uri` field for OAuth callback URL
- Helper methods for OAuth state:
  - `oauth_authorized?` - Returns true if authorized with valid access token
  - `token_expired?` - Checks if `token_expires_at` is in the past
  - `requires_reauthorization?` - Returns true if not authorized or token expired
  - `oauth_status` - Returns string: "Not Authorized", "Token Expired", or "Authorized"
  - `oauth_status_badge_class` - Returns Bootstrap badge class for UI: "bg-secondary", "bg-danger", or "bg-success"

**Session** (`app/models/session.rb`):
- Tracks `user_agent` and `ip_address`
- Belongs to User

**Instrument** (`app/models/instrument.rb`):
- Base model using **Single Table Inheritance (STI)** pattern
- Stores trading instruments: stocks, options, futures, etc.
- Fields: `type`, `symbol`, `name`, `exchange`, `segment`, `identifier`, `tick_size`, `lot_size`
- `raw_data` JSONB field for broker-specific metadata (indexed with GIN)
- Subclasses: `UpstoxInstrument`, `ZerodhaInstrument`

**MasterInstrument** (`app/models/master_instrument.rb`):
- Links instruments across brokers by exchange and exchange_token
- `belongs_to :zerodha_instrument` and `belongs_to :upstox_instrument` (both optional)
- `create_from_exchange_data(instrument:, exchange:, exchange_token:)` - Creates mapping records

**InstrumentHistory** (`app/models/instrument_history.rb`):
- Historical OHLC price data for instruments
- `belongs_to :master_instrument`
- Enum for `unit`: `{ minute: 1, hour: 2, day: 3, week: 4, month: 5 }`
- Fields: `open`, `high`, `low`, `close`, `volume`, `date`, `unit`, `interval`
- `previous_candle` - Returns the previous candle for the same instrument/unit/interval combination

**Holding** (`app/models/holding.rb`):
- User portfolio holdings from brokers
- Enum for `broker`: `{ zerodha: 1, upstox: 2, angel_one: 3 }`
- `belongs_to :user`

**Screener** (`app/models/screener.rb`):
- Base model for screeners/strategies
- `belongs_to :user`
- Stores screener configuration: `name`, `active`, `rules`, `scanned_instrument_ids` (array)
- `scan` - Scans all master instruments and stores matching IDs in `scanned_instrument_ids`
  - Evaluates rules in a transaction (with rollback to avoid persisting temp state)
  - Returns array of filtered master instrument IDs
- `master_instruments` - Returns scanned instruments ordered by gain percentage (desc)
- `evaluate_rule(master_instrument)` - Evaluates screener rules using Ruby eval()
  - Executes the `rules` formula string against the master instrument
  - Rules can reference technical indicators via the ScreenerConcern modules
- Users define custom `rules` as text expressions that reference technical indicators
- **Security**: `validate_rules_syntax` validation blocks dangerous patterns
  - Prevents system/command execution, file operations, database writes, network calls, etc.
  - Tests rules against a sample instrument before saving
  - Comprehensive pattern matching prevents code injection attacks

**Strategy** (`app/models/strategy.rb`):
- Base model using **Single Table Inheritance (STI)** pattern for trading strategies
- `belongs_to :user`
- Includes `StrategyConcern` (technical indicators) and `RuleEvaluationConcern` (security validation)
- Uses `has_paper_trail` for version tracking (via PaperTrail gem)
- Fields: `name`, `type`, `description`, `entry_rule`, `exit_rule`, `master_instrument_ids` (array), `parameters` (jsonb), `deploy` (boolean)
- Subclasses:
  - **InstrumentBasedStrategy**: Manually selected instruments, requires `master_instrument_ids`
  - **ScreenerBasedStrategy**: Uses screener results, stores `screener_id` and `screener_execution_time` in `parameters`
    - `scan` method updates `master_instrument_ids` from screener results
    - Validates screener execution time format (HH:MM)
  - **RuleBasedStrategy**: Custom rules stored in `parameters["rules"]`
- **Entry/Exit Rules**:
  - `entry_rule` and `exit_rule` - Text expressions evaluated against master instruments
  - `evaluate_entry_rule(market_data)` / `evaluate_exit_rule(market_data)` - Evaluates rules in transaction (with rollback)
  - Rules can reference technical indicators via `StrategyConcern` modules
  - Uses Ruby `eval()` within `instance_eval` context for rule execution
  - Results cached in `@calculated_data` hash for performance
- **Security**: Same `validate_rules_syntax` pattern as Screener (via `RuleEvaluationConcern`)
  - Validates both entry and exit rules before saving
  - Tests rules against sample instrument to catch syntax errors
  - Comprehensive dangerous pattern blocking (defined in `DANGEROUS_PATTERNS` constant)

**Notification** (`app/models/notification.rb`):
- Polymorphic notification system
- `belongs_to :user` and `belongs_to :item, polymorphic: true`
- Fields: `item_type`, `item_id`, `data` (jsonb)

**PushNotification** (`app/models/push_notification.rb`):
- Inherits from Notification model
- Used for notifying users about order events and strategy execution

**Order** (`app/models/order.rb`):
- Base model using **Single Table Inheritance (STI)** pattern for order management
- Uses AASM gem for state machine management
- Uses Discard gem for soft-delete functionality
- Enum for `trade_action`: `{ entry: 1, exit: 2 }`
- `belongs_to :user`, `belongs_to :strategy`, `belongs_to :master_instrument`
- `belongs_to :instrument, polymorphic: true` - References broker-specific instrument (ZerodhaInstrument, etc.)
- Self-referential associations for entry/exit order pairs:
  - `has_one :exit_order` - The exit order for an entry order
  - `has_one :entry_order` - The entry order for an exit order (inverse relationship)
  - Linked via `entry_order_id` foreign key
- `has_many :push_notifications, as: :item`
- Methods:
  - `push_to_broker` - Submits order to broker (or simulates if `strategy.only_simulate`)
  - `notify_about_initiation` - Creates push notification when order is initiated

**ZerodhaOrder** (`app/models/zerodha_order.rb`):
- Subclass of Order for Zerodha Kite Connect API orders
- **Constants** for Zerodha order parameters:
  - Products: `MIS` (intraday), `CNC` (delivery), `NRML` (normal), `CO` (cover order)
  - Order types: `MARKET`, `LIMIT`, `SL` (stop-loss), `SL-M` (stop-loss market)
  - Varieties: `regular`, `co`, `amo` (after-market order)
  - Transaction types: `BUY`, `SELL`
  - Validity: `DAY`, `IOC` (immediate or cancel), `TTL` (time to live)
- **State Machine** (via AASM):
  - States: `completed`, `rejected`, `cancelled`, `open`, `trigger_pending`, `modify_pending_at_exchange`, `cancellation_pending_at_exchange`, `pending_at_exchange`, `unknown`
  - Maps Zerodha API status strings to internal state machine states
- **Lifecycle Callbacks**:
  - `before_create :set_instrument` - Links to ZerodhaInstrument if entry order
  - `before_create :set_order_fields` - Populates order fields (symbol, exchange, price, quantity, etc.)
  - `after_commit :notify_about_initiation` - Sends push notification
  - `after_commit :push_to_broker` - Places order with Zerodha API
  - `after_commit :handle_postback_entry_order_update` - Handles postback updates from Zerodha
- **Key Methods**:
  - `exit_at_current_price` - Modifies exit order to current market price with buffer
  - `initiate_exit_order` - Creates stop-loss exit order after entry is filled (1% SL with 7% buffer)
  - `update_order_details(last_order_history)` - Updates order with latest status from Zerodha API
  - `update_order_status` - Fetches and applies latest order history from Zerodha
  - `modify_order(params)` - Modifies existing order at Zerodha
  - `cancel_order` - Cancels order at Zerodha
  - `getOrderHistory` - Fetches order history from Zerodha API
  - `cancel_and_reinitiate_trailing` - Cancels and recreates exit order if max modifications exceeded

**ScreenerConcern** (`app/models/concerns/screener_concern.rb`):
- Includes technical indicator modules for use in screener rules
- Available technical indicators:
  - `TechnicalIndicators::Close` - Access closing prices via `close(unit, interval, number_of_candles)`
  - `TechnicalIndicators::Open` - Access opening prices via `open(unit, interval, number_of_candles)`
  - `TechnicalIndicators::High` - Access high prices via `high(unit, interval, number_of_candles)`
  - `TechnicalIndicators::Low` - Access low prices via `low(unit, interval, number_of_candles)`
  - `TechnicalIndicators::Ltp` - Access Last Traded Price via `ltp()`
    - During market hours (9:15 AM - 3:30 PM IST): Fetches live LTP from Redis (via `$redis` global)
    - Outside market hours: Returns latest closing price from InstrumentHistory
- Technical indicator methods query `InstrumentHistory` records via `master_instrument` association
- Parameters: `unit` (day/minute/hour/week/month), `interval` (1, 5, 15, etc.), `number_of_candles` (offset from latest)
- Results are cached in `@calculated_data` hash within the screener evaluation context for performance

**StrategyConcern** (`app/models/concerns/strategy_concern.rb`):
- Includes technical indicator modules for use in strategy entry/exit rules
- Same technical indicators as ScreenerConcern:
  - `TechnicalIndicators::Close`, `Open`, `High`, `Low`, `Ltp`
  - `TechnicalIndicators::CurrentTime` - Access current time for time-based rules
  - `TechnicalIndicators::ParseTime` - Parse time strings in rules

**RuleEvaluationConcern** (`app/models/concerns/rule_evaluation_concern.rb`):
- Shared concern for security validation of dynamic rules
- Defines `DANGEROUS_PATTERNS` constant with 100+ regex patterns blocking:
  - System/command execution (`system`, `exec`, backticks, `spawn`, `fork`)
  - Code evaluation (`eval`, `send`, `instance_eval`, `class_eval`)
  - File/directory operations (`File`, `Dir`, `IO`, `Pathname`)
  - Database write operations (`create`, `update`, `delete`, `destroy`)
  - Network/HTTP operations (`Net::`, `Socket`, `URI`)
  - Global variable access (`$variable`)
  - Environment manipulation (`ENV`, `exit`, `raise`)
  - Dangerous deserialization (`YAML.load`, `Marshal.load`)
- Used by both Screener and Strategy models to validate user-defined rules

### Routes Structure

- **Root**: Dashboard (`dashboard#index`)
- **Session**: Singular resource (`resource :session`) for login/logout
- **Passwords**: Token-based password reset (`resources :passwords, param: :token`)
- **API Configurations**: Standard CRUD (`resources :api_configurations`)
- **Instruments**: Read-only index (`resources :instruments, only: [:index]`) for viewing trading instruments
- **Holdings**: Read-only (`resources :holdings, only: [:index, :show]`)
- **Instrument Histories**: Full CRUD (`resources :instrument_histories`)
- **Orders**: Full CRUD (`resources :orders`) for viewing and managing orders
- **Screeners**: Full CRUD (`resources :screeners`) for managing screeners
  - `GET /screeners/:id/scan` - Executes the screener scan against all master instruments
- **Strategies**: Full CRUD (`resources :strategies`) for managing trading strategies
  - Base controller for all strategy types
- **Strategy Types** (STI-based routes):
  - `resources :instrument_based_strategies` - Manually selected instrument strategies
  - `resources :screener_based_strategies` - Screener-based strategies
  - `resources :rule_based_strategies` - Custom rule-based strategies
- **Upstox OAuth**:
  - `POST /upstox/oauth/authorize/:id` - Initiates OAuth flow
  - `GET /upstox/oauth/callback` - Handles OAuth callback
- **Zerodha OAuth**:
  - `POST /zerodha/oauth/authorize/:id` - Initiates OAuth flow
  - `GET /zerodha/oauth/callback` - Handles OAuth callback

### Generator Configuration

RSpec is configured as the default test framework with:
- **Fixtures**: Enabled
- **View specs**: Disabled
- **Helper specs**: Disabled
- **Routing specs**: Disabled
- **Controller specs**: Enabled
- **Request specs**: Disabled
- **Factory replacement**: FactoryBot at `spec/factories`

### Background Jobs & Scheduled Tasks

**Sidekiq Configuration** ([config/initializers/sidekiq.rb](config/initializers/sidekiq.rb)):
- Redis URL: `ENV["REDIS_URL"]` (default: `redis://localhost:6379/0`)
- Sidekiq-cron loads schedule from [config/schedule.yml](config/schedule.yml)

**Scheduled Jobs** (runs in IST timezone, Monday-Friday):
- **Start Market Data** (`Upstox::StartWebsocketConnectionJob`): 9:15 AM - Starts WebSocket connection at market open
- **Schedule Strategy Execution** (`ScheduleStrategyExecutionJob`): 9:15 AM - Triggers entry rule scanning for all deployed strategies
- **Stop Market Data** (`Upstox::StopWebsocketConnectionJob`): 3:30 PM - Stops WebSocket connection at market close
- **Health Check** (`Upstox::HealthCheckWebsocketConnectionJob`): Every 2 min (9 AM-3 PM) - Monitors WebSocket service health
- **Sync Zerodha Holdings** (`Zerodha::SyncHoldingsJob`): 8:00 AM and 4:00 PM - Syncs holdings from Zerodha
- **Sync Upstox Instrument History** (`Upstox::SyncInstrumentHistoryJob`): 9:08 AM - Syncs daily historical OHLC data after market open
- **Cleanup Job Logs** (`CleanupJobLogsJob`): 8:00 AM daily - Removes job log files older than 7 days

**Job Queues**:
- `market_data` - Real-time market data streaming jobs
- `default` - General background jobs

**Alternative**: Solid Queue is available as Rails 8 native adapter (not currently used)

**Strategy Execution Jobs**:

**ScheduleStrategyExecutionJob** (`app/jobs/schedule_strategy_execution_job.rb`):
- Triggered daily at 9:15 AM to initiate strategy execution at market open
- Finds all deployed strategies (`Strategy.deployed`)
- For `ScreenerBasedStrategy`: Schedules `ScanEntryRuleJob` at the screener execution time configured in `parameters["screener_execution_time"]`
- For other strategy types: Immediately enqueues `ScanEntryRuleJob`
- Calls `strategy.reset_fields!` for screener-based strategies before scheduling

**ScanEntryRuleJob** (`app/jobs/scan_entry_rule_job.rb`):
- Evaluates entry rules for a specific strategy against its instruments
- Parameters: `strategy_id`, `options` (JSON with `scanner_check` flag)
- If `options[:scanner_check]` is true for `ScreenerBasedStrategy`: Runs `strategy.scan` to refresh screener results
- Checks if daily max entries reached (`strategy.daily_max_entries`)
- Filters out instruments that reached re-entry limit (`strategy.re_enter`)
- Calls `strategy.evaluate_entry_rule(master_instrument_ids)` to find matching instruments
- For each matching instrument:
  - Adds to `strategy.entered_master_instrument_ids` array
  - Calls `strategy.initiate_place_order(master_instrument_id)` to create entry order
- Self-schedules to run again in 1 minute (with `scanner_check: false`)
- Uses `perform_at` to schedule exact execution time with zero seconds

**ScanExitRuleJob** (`app/jobs/scan_exit_rule_job.rb`):
- Evaluates exit rules for a specific entry order
- Parameters: `entry_order_id`
- Uses Sidekiq unique job lock (`lock: :until_executed, on_conflict: :reject`) to prevent duplicate execution
- Finds the entry order and its associated exit order
- **Exit Order Lifecycle**:
  1. If no exit order exists: Calls `entry_order.initiate_exit_order` to create stop-loss exit order
  2. If exit order exists and not completed/cancelled: Updates both entry and exit order status via `update_order_status`
  3. Evaluates exit rule: `strategy.evaluate_exit_rule([exit_order.master_instrument_id])`
  4. If exit rule satisfied: Calls `exit_order.exit_at_current_price` to modify order to current market price
  5. If exit rule not satisfied: Self-schedules to run again in 1 minute
- Terminates if exit order is already completed or cancelled

**JobLogger Concern** (`app/jobs/concerns/job_logger.rb`):
- Shared concern for all background jobs to enable structured logging
- Creates separate log files per job in `log/jobs/` directory
- Jobs include this module and call `setup_job_logger` in `perform` method
- Provides convenience methods: `log_info`, `log_warn`, `log_error`, `log_debug`
- Log files are named after the job class: `upstox_start_websocket_connection_job.log`
- Daily rotation enabled automatically
- Logs are cleaned up by `CleanupJobLogsJob` after 7 days

Example usage:
```ruby
class MyJob < ApplicationJob
  include JobLogger

  def perform
    setup_job_logger
    log_info "Job started at #{Time.current}"
    # ... job logic ...
    log_info "Job completed successfully"
  end
end
```

### Service Object Pattern

Services are organized by broker in namespaced directories (`app/services/upstox/`, etc.). Each broker should have its own module namespace:

```ruby
module Upstox
  class OauthService
    # Service methods here
  end
end
```

**Upstox OAuth Implementation** (`app/services/upstox/oauth_service.rb`):
- Service object pattern for OAuth operations
- `build_authorization_url(api_key, redirect_uri, state)` - Generates OAuth URL with CSRF protection
- `exchange_code_for_token(api_key, api_secret, code, redirect_uri)` - Exchanges auth code for access token
- Uses Upstox API v2 endpoints: `/v2/login/authorization/dialog` and `/v2/login/authorization/token`
- Returns structured hash with `:success`, `:access_token`, `:expires_at`, or `:error`

**Upstox OAuth Controller** (`app/controllers/upstox/oauth_controller.rb`):
- `authorize` action: Generates CSRF state token, stores in session and DB, redirects to Upstox
- `callback` action: Verifies state token, exchanges code for token, stores credentials
- Uses Rails session for temporary state storage during OAuth flow
- Scoped to `current_user.api_configurations`
- Controllers are namespaced under `app/controllers/upstox/` with module `Upstox`

**Zerodha OAuth Implementation** (`app/services/zerodha/oauth_service.rb`):
- Service object pattern for OAuth operations following Kite Connect v3 API
- `build_authorization_url(api_key, state)` - Generates Kite Connect login URL with state as redirect_params
- `exchange_token(api_key, api_secret, request_token)` - Exchanges request_token for access token
  - Generates SHA-256 checksum: `api_key + request_token + api_secret`
  - POSTs to `/session/token` endpoint
- `calculate_expiry()` - Calculates token expiry (6 AM next day IST)
- Uses Zerodha Kite Connect API endpoints: `https://kite.zerodha.com/connect/login` and `https://api.kite.trade/session/token`
- Returns structured hash with `:success`, `:access_token`, `:user_id`, or `:error`
- **Important**: Zerodha access tokens expire at 6 AM IST the next day (not 24 hours)

**Zerodha OAuth Controller** (`app/controllers/zerodha/oauth_controller.rb`):
- `authorize` action: Generates CSRF state token, stores in session and DB, redirects to Kite Connect
- `callback` action: Verifies state token, exchanges request_token for access token, stores credentials
- Uses Rails session for temporary state storage during OAuth flow
- Scoped to `current_user.api_configurations`
- Controllers are namespaced under `app/controllers/zerodha/` with module `Zerodha`

**Zerodha API Service** (`app/services/zerodha/api_service.rb`):
- Service object for Zerodha Kite API operations
- `instruments` - Fetches all instrument master data in CSV format
- Requires API key and access token for authentication
- Authorization header format: `token api_key:access_token`
- Base URL: `https://api.kite.trade`

**Zerodha Sync Holdings Service** (`app/services/zerodha/sync_holdings_service.rb`):
- Service object for syncing user holdings from Zerodha
- Called by `Zerodha::SyncHoldingsJob` scheduled task
- Fetches holdings via Kite API and stores in `holdings` table

**Upstox API Service** (`app/services/upstox/api_service.rb`):
- Comprehensive service object for Upstox API v3 operations
- **Base URLs**:
  - Assets: `https://assets.upstox.com`
  - API: `https://api.upstox.com/v3`
  - HFT (High-Frequency Trading): `https://api-hft.upstox.com`
- **Order Management**:
  - `place_order(params)` - Place new order with auto-slicing support (via HFT endpoint)
  - `modify_order(params)` - Modify existing order
  - `cancel_order(params)` - Cancel order
  - `get_order_book` / `get_all_orders` - Fetch all orders
  - `get_order_details(order_id)` - Get specific order details
  - `get_order_history(order_id)` - Get order modification history
  - `get_trades` - All trades for the day
  - `get_order_trades(order_id)` - Trades for specific order
- **Portfolio & Positions**:
  - `get_positions` - Current short-term positions
  - `get_holdings` - Long-term holdings
  - `convert_position(params)` - Convert between Intraday/Delivery/MTF
- **User & Margins**:
  - `get_profile` - User profile details
  - `get_fund_margin(segment:)` / `user_equity_margins` - Funds and margin details
- **Historical Data**:
  - `get_historical_candle_data(params)` - OHLC candle data
    - Supports: minutes (1-300), hours (1-5), days, weeks, months
    - Historical availability: Intraday from Jan 2022, Daily from Jan 2000
- **Market Quotes**:
  - `quote_ltp(params)` - Last Traded Price
  - `quote(params)` - Full market quote
  - `get_ohlc(params)` - OHLC data for intervals
- All methods store response in `@response` instance variable
- Requires access token for authentication (except instrument downloads)

### Real-Time Market Data WebSocket System

**Upstox WebSocket Service** ([app/services/upstox/websocket_service.rb](app/services/upstox/websocket_service.rb)):
- Connects to Upstox Market Data Feed v3 API for real-time trading data
- **Authorization**: Fetches WebSocket URL via `/v3/feed/market-data-feed/authorize` endpoint
- **Connection Management**:
  - Auto-reconnection with exponential backoff (max 10 attempts)
  - Heartbeat monitoring (checks every 30 seconds)
  - Connection health tracking with automatic recovery
  - State tracking via Redis: `upstox:market_data:status` (starting/running/stopping/stopped/error)
- **Subscription Modes**: `ltpc` (Last Traded Price), `full`, `option_greeks`, `full_d30`
- **Message Processing**: Binary Protobuf decoding via `lib/protobuf/upstox/MarketDataFeed_pb.rb`
- **EventMachine**: Runs in separate thread with EM reactor loop

**WebSocket Job Lifecycle** ([app/jobs/upstox/start_websocket_connection_job.rb](app/jobs/upstox/start_websocket_connection_job.rb)):
1. Validates authorized Upstox API configuration and access token
2. Spawns EventMachine thread with WebSocket service
3. Subscribes to NSE instruments (from `UpstoxInstrument` table)
4. Stores global reference in `$market_data_service` variable
5. Monitors stop signals from Redis every 60 seconds

**State Management** (Redis keys):
- `upstox:market_data:status` - Current service state
- `upstox:market_data:connection_stats` - JSON connection statistics
- `upstox:market_data:last_error` / `last_error_time` - Error tracking
- `upstox:market_data:last_connected_at` / `last_disconnected_at` - Connection history

**Protobuf Message Decoding**:
- Feed types: LTPC (Last Traded Price & Quantity), Full Feed (Market/Index), First Level with Greeks
- Parses market depth, OHLC, option greeks, bid/ask quotes
- Fallback to JSON/raw data if protobuf compilation unavailable

**Action Cable**: Solid Cable (database-backed adapter) available for server-to-client WebSocket broadcast

### Environment Variables

**Database** ([config/database.yml](config/database.yml)):
- `DATABASE_USERNAME` (default: "admin")
- `DATABASE_PASSWORD` (default: "admin")
- `DATABASE_HOST` (default: "localhost")
- `DATABASE_PORT` (default: "5432")
- `RAILS_MAX_THREADS` (default: 5)

**Redis** (Sidekiq & WebSocket state):
- `REDIS_URL` (default: "redis://localhost:6379/0")

## Important Notes

### Local Development with Foreman

The application includes a [Procfile.dev](Procfile.dev) for running the complete development stack using Foreman (via `bin/dev`):
- **web**: Rails server (`bin/rails server`)
- **css**: CSS build watcher (`npm run build:css -- --watch`)
- **worker**: Sidekiq worker with queue priorities (`bundle exec sidekiq -q market_data,1 -q default,2`)
  - `market_data` queue has priority 1 (higher priority)
  - `default` queue has priority 2 (lower priority)

To start all services at once: `bin/dev`

### Protobuf Message Compilation

The WebSocket service uses Protocol Buffers for efficient binary message decoding. The compiled Ruby file is at [lib/protobuf/upstox/MarketDataFeed_pb.rb](lib/protobuf/upstox/MarketDataFeed_pb.rb).

If you need to recompile from `.proto` file:
```bash
# Install protoc compiler first (platform-specific)
# Then compile:
protoc --ruby_out=lib/protobuf/upstox lib/protobuf/upstox/MarketDataFeed.proto
```

The service gracefully falls back to JSON/raw data if protobuf decoding fails, so compilation is optional but recommended for performance.

### Global State Variables

The application uses global variables for service management:
- `$market_data_service` - Holds the active `Upstox::WebsocketService` instance
  - Created in `Upstox::StartWebsocketConnectionJob`
  - Used for subscribing/unsubscribing to instruments while service is running
  - Set to `nil` when service stops or encounters errors
- `$redis` - Global Redis client instance used by technical indicators
  - Used to fetch real-time LTP (Last Traded Price) data during market hours
  - Exchange tokens are stored as keys with LTP as values
  - Updated by WebSocket service as market data streams in

### Security Considerations
- API credentials (`api_key`, `api_secret`) and OAuth tokens (`access_token`) are stored in plaintext in the database. Consider encrypting these with Rails encrypted attributes or a vault solution.
- Sessions are database-backed, providing better security than cookie-based sessions for this financial application.
- OAuth flow uses CSRF state tokens stored in both session and database for security.

### Testing with RSpec
- Use FactoryBot for test data: `spec/factories/`
- Controller specs are the primary spec type enabled
- Transaction-based fixtures are enabled for speed
- **Note**: Test database uses only the primary PostgreSQL database (not the multi-database setup used in development/production)

### Database Migrations
When creating migrations that affect non-primary databases, specify the migration path:
```bash
bin/rails generate migration CreateSomething --database=cache
```

### CSS Bundling
CSS is bundled via `cssbundling-rails`. After pulling changes, run `bin/rails css:build` if styles are missing.

### CI/CD Pipeline

The application uses GitHub Actions for continuous integration ([.github/workflows/ci.yml](.github/workflows/ci.yml)):

**Jobs**:
1. **scan_ruby**: Security scan using Brakeman
   - Runs `bin/brakeman --no-pager` to detect Rails security vulnerabilities
2. **scan_js**: JavaScript dependency security audit
   - Runs `bin/importmap audit` to check for vulnerabilities in JS dependencies
3. **lint**: Code style check using Rubocop
   - Runs `bin/rubocop -f github` for consistent code formatting
4. **test**: Run RSpec test suite
   - Installs dependencies: `build-essential`, `git`, `libyaml-dev`, `pkg-config`, `google-chrome-stable`
   - Runs `bin/rails db:test:prepare && bundle exec rspec`
   - Uploads screenshots from failed system tests as artifacts

**Triggers**:
- On pull requests to any branch
- On pushes to `main` branch

**Note**: Redis service is currently commented out in CI configuration.

### Single Table Inheritance (STI) Pattern

The application uses STI for three domain models:

**Instrument Model STI**:
- All instruments are stored in the `instruments` table
- The `type` column determines the subclass (`UpstoxInstrument`, `ZerodhaInstrument`)
- Use `Instrument.create(type: 'UpstoxInstrument', ...)` or `UpstoxInstrument.create(...)`
- Query all instruments: `Instrument.all`, or specific broker: `UpstoxInstrument.all`

**Strategy Model STI**:
- All strategies are stored in the `strategies` table
- The `type` column determines the subclass (`InstrumentBasedStrategy`, `ScreenerBasedStrategy`, `RuleBasedStrategy`)
- Use `Strategy.create(type: 'InstrumentBasedStrategy', ...)` or `InstrumentBasedStrategy.create(...)`
- Query all strategies: `Strategy.all`, or specific type: `InstrumentBasedStrategy.all`
- Each strategy type has its own controller and views under respective namespaces

**Order Model STI**:
- All orders are stored in the `orders` table
- The `type` column determines the subclass (`ZerodhaOrder`, future: `UpstoxOrder`, `AngelOneOrder`)
- Use `Order.create(type: 'ZerodhaOrder', ...)` or `ZerodhaOrder.create(...)`
- Query all orders: `Order.all`, or specific broker: `ZerodhaOrder.all`
- Each order type has its own broker-specific implementation for order placement and management

**Screener Model** (not using STI):
- All screeners are stored in the `screeners` table
- Users create screeners with custom `rules` text expressions
- Rules are evaluated dynamically using Ruby `eval()` against master instruments

**UpstoxInstrument** has a class method `import_from_upstox(exchange: "NSE_MIS")` that:
- Downloads and imports instrument data from Upstox API
- Handles gzipped JSON responses
- Uses `find_or_initialize_by` with `identifier` (instrument_key) for upserts
- Creates `MasterInstrument` mapping records automatically
- Returns hash with `:imported`, `:skipped`, `:total` counts

**UpstoxInstrument** also has an instance method `create_instrument_history(params)`:
- Fetches and stores historical OHLC candle data for the instrument
- Parameters: `unit` (day/minute/hour/week/month), `interval`, `from_date`, `to_date`
- Stores data in `InstrumentHistory` via `MasterInstrument` association
- Uses `find_or_initialize_by` with `unit`, `interval`, `date` for upserts
- Requires authorized Upstox API configuration

**ZerodhaInstrument** has a class method `import_instruments(api_key:, access_token:)` that:
- Downloads and imports instrument data from Zerodha Kite API
- Requires API key and valid access token (unlike Upstox which uses public endpoint)
- Filters for NSE exchange and EQ (equity) instrument type only
- Parses CSV response and stores in unified Instrument table
- Uses `find_or_initialize_by` with `identifier` (instrument_token) for upserts
- Creates `MasterInstrument` mapping records automatically
- Call from console: `ZerodhaInstrument.import_instruments(api_key: "your_key", access_token: "your_token")`

### Version Tracking with PaperTrail

The `Strategy` model uses PaperTrail gem for audit trail:
- All create/update/destroy operations are tracked in the `versions` table
- Access version history: `strategy.versions`
- Restore previous version: `strategy.versions.last.reify`
- See who made changes: `version.whodunnit` (user ID from `Current.user`)
- View changes: `version.changeset` returns hash of attribute changes
- The `versions` table uses UUID as primary key for better scalability

### Frontend & Views

- **Template engine**: HAML (`.html.haml` files)
- **Layout**: AdminLTE 3-based layout with sidebar navigation
- **CSS Framework**: Bootstrap 5.3.3 via CDN
- **Icons**: Bootstrap Icons and Font Awesome
- **Hotwire**: Turbo + Stimulus for SPA-like behavior
- **Turbo considerations**: When redirecting to external OAuth providers, disable Turbo on forms using `form: { data: { turbo: false } }` in `button_to` helpers

Example of disabling Turbo on button_to:
```haml
= button_to path, method: :post, form: { data: { turbo: false } } do
  Button text
```
