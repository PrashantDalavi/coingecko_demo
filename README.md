# CoinGecko Crypto Price Sync Service

A robust, high-performance Ruby on Rails API designed to synchronize, cache, and serve cryptocurrency prices from the CoinGecko API. 

The application utilizes a multi-tier fallback architecture (**Redis Cache** ➔ **PostgreSQL Database** ➔ **Robust Background Sync**) to guarantee high availability and consistent delivery of the last known price, even in the event of third-party API downtime or network latency.

---

## 🚀 Key Features

* **Multi-Tier Availability**: Reads are served instantly from a low-latency Redis cache. If the cache is empty/fails, it seamlessly falls back to PostgreSQL.
* **Resilient Background Syncing**: A recurring scheduler enqueues a Sidekiq background worker every **1 minute** to fetch the latest prices from CoinGecko, ensuring data freshness without blocking web request-response loops.
* **External API Resilience**: Implements strict connection error and payload validation handling. If CoinGecko fails, the system continues serving the last stored database price seamlessly.
* **Full Test Coverage**: Robust suite of RSpec unit, request, and job specs verifying the caching layers, fallback strategies, and sync job states.

---

## 🛠 Tech Stack & Services

* **Ruby on Rails** (v7.2+)
* **PostgreSQL** (Relational Database for persistent last-known price storage)
* **Redis** (Unified backend for Sidekiq queues and ActiveSupport cache store)
* **Sidekiq** (Concurrent background job processor)
* **Whenever** (Cron-scheduling utility generating clean crontab entries)
* **Faraday** (Robust HTTP/REST client for external requests)

---

## 🏗 System Architecture & Flow

```mermaid
sequenceDiagram
    participant User
    participant Router
    participant HomeController
    participant Redis Cache
    participant PostgreSQL DB
    
    User->>Router: GET /crypto_price?crypto_id=bitcoin
    Router->>HomeController: #index
    

    note right of HomeController: Attempt 1: Fetch from Cache
    HomeController->>Redis Cache: Read cached payload
    alt Cache Hit
        Redis Cache-->>HomeController: Cached JSON Payload
        HomeController-->>User: 200 OK (Instant Cache response)
    else Cache Miss / Cache Error
        Redis Cache-->>HomeController: nil / StandardError
    end
    
    note right of HomeController: Attempt 2: Fallback to DB
    HomeController->>PostgreSQL DB: Query Crypto by name (find_by!)
    alt DB Record Exists
        PostgreSQL DB-->>HomeController: Active Record object
        HomeController-->>User: 200 OK (DB Fallback response)
    else DB Record Missing
        PostgreSQL DB-->>HomeController: ActiveRecord::RecordNotFound
        HomeController-->>User: 404 Not Found (Friendly message)
    end
```

---

## ⚙️ Core Components

### 1. Scheduler (`config/schedule.rb`)
Uses the `whenever` gem to schedule the Rails rake task to run **every minute**.
```ruby
every 1.minute do
  rake "crypto_prices:refresh"
end
```

### 2. Rake Task (`lib/tasks/crypto_prices.rake`)
An environmental bridge that enqueues the Sidekiq background job asynchronously:
```ruby
namespace :crypto_prices do
  task refresh: :environment do
    CryptoPriceRefreshJob.perform_later
  end
end
```

### 3. Background Sync Job (`app/jobs/crypto_price_refresh_job.rb`)
* Iterates through supported coins in `Crypto::COINS` (Bitcoin, Ethereum, Solana, XRP, Cardano, Dogecoin).
* Queries the CoinGecko API over Faraday.
* Persists the fresh prices into PostgreSQL.
* Writes the structured payload into the Redis cache with a 5-minute expiration period.

---

## 🏁 Setup & Installation

### Prerequisites
Make sure you have the following installed:
* Ruby (v3.3+)
* PostgreSQL
* Redis

### 1. Install Dependencies
```bash
bundle install
```

### 2. Configure Credentials
Store your CoinGecko API key in Rails credentials:
```bash
EDITOR=nano bundle exec rails credentials:edit
```
Add the key in the following format:
```yaml
API_KEY: "your_api_key"
```

### 3. Setup Database
```bash
bundle exec rails db:create db:migrate
```

### 4. Apply Cron Schedule (Whenever)
Write the configured cron schedules to your system's crontab:
```bash
bundle exec whenever --update-crontab
```

---

## 🏃 Running the Application

### 1. Start Redis Server
Ensure your Redis instance is running locally:
```bash
redis-server
```

### 2. Start Sidekiq
Launch Sidekiq to begin processing background refresh tasks:
```bash
bundle exec sidekiq
```

### 3. Start Rails Server
Run the local development server:
```bash
bundle exec rails server
```

Now, query the API in your browser or client:
```bash
curl -H "Accept: application/json" "http://localhost:3000/crypto_price?crypto_id=bitcoin"
```

---

## 🧪 Testing

The application features a comprehensive RSpec test suite covering model logic, controller response states, database fallback workflows, and edge-case job conditions (such as API failures or Redis caching downtime).

Run the tests using the following command:
```bash
bundle exec rspec 
```

---

## 🐳 Dockerization & Container Orchestration

The application is fully containerized using **Docker** and **Docker Compose** in **Development Mode** out of the box. This provides a plug-and-play development environment featuring hot-reloading (live code updates) and automatic database migrations!

### Services Orchestrated
1. **`db`** (`postgres:16-alpine`): Local development database (`coingecko_dev`).
2. **`redis`** (`redis:7-alpine`): Caching and Sidekiq backend.
3. **`web`** (Rails API): Mounted on port `3000` with hot-reloading enabled.
4. **`sidekiq`** (Sidekiq worker): Asynchronous background job worker.
5. **`scheduler`** (Bash sync-loop): Enqueues the sync task in Sidekiq every 60 seconds.

### Hot Reloading & Live Code Updates
Your local directory `.` is mounted as a volume (`/rails`) inside the containers. This means **any code changes you make in your IDE will be instantly reflected inside the running Docker containers** without needing a rebuild or restart!

### Quick Start

#### 1. Build and Start the Containers
Run the start command:
```bash
docker compose up --build
```

Docker Compose will automatically:
- Spin up the Postgres and Redis servers.
- Install all gems (including `:development` tools like `pry` and `rspec`).
- Run `db:prepare` to automatically create your local `coingecko_dev` database and run outstanding migrations.
- Spin up the hot-reloaded Web server, Sidekiq, and the price scheduler.

#### 2. Test the API
Query the running containerized API:
```bash
curl -H "Accept: application/json" "http://localhost:3000/crypto_price?crypto_id=ethereum"
```

#### 3. Stop Services
To stop the services and clean up container footprints:
```bash
docker compose down
```
