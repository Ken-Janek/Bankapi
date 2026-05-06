# MIN001 Branch Bank API

Microservices branch bank — registered with Central Bank as **MIN001**.  
Interoperates with other branch banks via the shared Central Bank system.

| | |
|---|---|
| **API** | `http://localhost:3000/api/v1` |
| **Swagger UI** | `http://localhost:3000/docs` |
| **OpenAPI spec** | `http://localhost:3000/api-docs.json` |

---

## Technologies

| Layer | Technology |
|---|---|
| Runtime | Node.js 20 |
| Framework | Express.js |
| Database | SQLite (`better-sqlite3`) — one DB per service |
| JWT | `jose` — ES256 / ECDSA P-256 |
| API Docs | `swagger-ui-express` |
| Containers | Docker Compose (local) / Railway (cloud) |

---

## Architecture

```
                    ┌──────────────────────────┐
                    │     gateway  :3000        │
                    │  • Auth (Bearer apiKey)   │
                    │  • Swagger UI  /docs      │
                    │  • Central Bank client    │
                    │  • Heartbeat every 25 min │
                    └────────────┬─────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
  ┌───────▼──────┐     ┌─────────▼──────┐     ┌────────▼───────┐
  │ user-service │     │account-service │     │transfer-service│
  │    :3001     │     │    :3002       │     │    :3003       │
  │  users.db    │     │  accounts.db   │     │  transfers.db  │
  └──────────────┘     └────────────────┘     └────────────────┘
```

| Service | Port | Responsibility |
|---|---|---|
| `gateway` | 3000 | Routing, auth, Swagger, Central Bank registration & heartbeat |
| `user-service` | 3001 | User registration, API key generation |
| `account-service` | 3002 | Account creation (`MIN` + 5 chars = 8 total), debit/credit |
| `transfer-service` | 3003 | Same-bank & cross-bank transfers, ES256 JWT, idempotency |

---

## Database Schema

### user-service — `users.db`
```sql
users ( id, full_name, email, api_key, created_at )
```

### account-service — `accounts.db`
```sql
accounts ( account_number, owner_id, owner_name, currency, balance, created_at )
-- account_number = "MIN" + 5 alphanumeric chars, e.g. MINA3K9Z
```

### transfer-service — `transfers.db`
```sql
transfers ( transfer_id, source_account, destination_account, amount, currency,
            converted_amount, exchange_rate, rate_captured_at,
            status, error_message, created_at, updated_at )
-- status: completed | pending | failed | failed_timeout
```

---

## Quick Start

### Docker (local)
```bash
git clone <repo>
cd bank-api
cp .env.example .env
docker compose up --build
```

### Without Docker (Windows)
```powershell
# Install deps
foreach ($d in "user-service","account-service","transfer-service","gateway") {
  cd $d; npm install; cd ..
}
# Start all
powershell -ExecutionPolicy Bypass -File start-all.ps1
```

---

## Deploying to Railway

Railway runs each microservice as a separate service in the same project.

### Step 1 — Push to GitHub
```bash
git init && git add . && git commit -m "init"
git remote add origin https://github.com/you/bank-api.git
git push -u origin main
```

### Step 2 — Create Railway project
1. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub repo
2. Create **4 services**, one per folder:
   - `gateway` → Root directory: `gateway`
   - `user-service` → Root directory: `user-service`
   - `account-service` → Root directory: `account-service`
   - `transfer-service` → Root directory: `transfer-service`

### Step 3 — Add the ES256 keys to Railway
The keys in `gateway/keys/` must be available to `gateway` and `transfer-service`.  
Easiest approach — paste key contents as environment variables:

```bash
# In your terminal:
cat gateway/keys/private.pem   # paste as PRIVATE_KEY_PEM
cat gateway/keys/public.pem    # paste as PUBLIC_KEY_PEM
```

Then in `gateway/index.js` and `transfer-service/index.js`, read from env if file missing:
> This is already handled — see the `RAILWAY KEYS NOTE` section below.

**Alternatively:** commit the keys to the repo (acceptable for a school project).

### Step 4 — Set environment variables per service

**gateway:**
```
BANK_ID=MIN001
BANK_NAME=MIN001 Branch Bank
BANK_ADDRESS=https://<your-gateway>.up.railway.app/api/v1
CENTRAL_BANK_URL=https://test.diarainfra.com/central-bank
USER_SERVICE_URL=http://user-service.railway.internal:3001
ACCOUNT_SERVICE_URL=http://account-service.railway.internal:3002
TRANSFER_SERVICE_URL=http://transfer-service.railway.internal:3003
JWT_PUBLIC_KEY_PATH=./keys/public.pem
PORT=3000
```

**transfer-service:**
```
BANK_ID=MIN001
CENTRAL_BANK_URL=https://test.diarainfra.com/central-bank
ACCOUNT_SERVICE_URL=http://account-service.railway.internal:3002
JWT_PRIVATE_KEY_PATH=./keys/private.pem
PORT=3003
```

**account-service:**
```
BANK_ID=MIN001
PORT=3002
```

**user-service:**
```
PORT=3001
```

### Step 5 — Deploy
Railway auto-deploys on push. Check logs per service in Railway dashboard.

---

## Environment Variables

| Variable | Used by | Description |
|---|---|---|
| `BANK_ID` | gateway, transfer, account | `MIN001` |
| `BANK_NAME` | gateway | Display name |
| `BANK_ADDRESS` | gateway | **Public** URL of gateway (Railway URL) |
| `CENTRAL_BANK_URL` | gateway, transfer | Central Bank API base |
| `USER_SERVICE_URL` | gateway | Internal URL to user-service |
| `ACCOUNT_SERVICE_URL` | gateway, transfer | Internal URL to account-service |
| `TRANSFER_SERVICE_URL` | gateway | Internal URL to transfer-service |
| `JWT_PUBLIC_KEY_PATH` | gateway | Path to ES256 public key |
| `JWT_PRIVATE_KEY_PATH` | transfer | Path to ES256 private key |
| `PORT` | all | Port to listen on (Railway sets this automatically) |

---

## API Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/health` | — | Health check |
| `POST` | `/users` | — | Register user, get `apiKey` |
| `GET` | `/users/{userId}` | — | Get user info |
| `POST` | `/users/{userId}/accounts` | Bearer | Create account |
| `GET` | `/users/{userId}/accounts` | Bearer | List accounts |
| `GET` | `/accounts/{accountNumber}` | — | Public account lookup |
| `POST` | `/transfers` | Bearer | Initiate transfer |
| `POST` | `/transfers/receive` | ES256 JWT in body | Receive cross-bank transfer |
| `GET` | `/transfers/{transferId}` | Bearer | Transfer status |
| `GET` | `/users/{userId}/transfers` | Bearer | Transfer history |
| `GET` | `/api-docs.json` | — | OpenAPI spec |

---

## Sample Flow

```bash
BASE=http://localhost:3000/api/v1

# 1. Register user
curl -s -X POST $BASE/users \
  -H "Content-Type: application/json" \
  -d '{"fullName":"Jane Doe","email":"jane@example.com"}' | tee user.json

# Copy userId and apiKey from output

# 2. Create account
curl -s -X POST $BASE/users/{userId}/accounts \
  -H "Authorization: Bearer {apiKey}" \
  -H "Content-Type: application/json" \
  -d '{"currency":"EUR"}' | tee account.json

# 3. Transfer
curl -s -X POST $BASE/transfers \
  -H "Authorization: Bearer {apiKey}" \
  -H "Content-Type: application/json" \
  -d '{
    "transferId":"550e8400-e29b-41d4-a716-446655440000",
    "sourceAccount":"{accountNumber}",
    "destinationAccount":"{otherAccount}",
    "amount":"50.00"
  }'
```

---

## Notes

- Balance stored as `TEXT` — no floating point issues
- Transfers idempotent via `transferId` (UUID)
- Account numbers: exactly 8 chars — `MIN` + 5 alphanumeric
- ES256 JWT only used for cross-bank `/transfers/receive`
- Heartbeat sent every 25 min (Central Bank timeout = 30 min)
- On 404/410 heartbeat response → auto re-registers with Central Bank
