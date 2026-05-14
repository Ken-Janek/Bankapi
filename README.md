# MIN001 Branch Bank API

Microservices-based branch bank API for the Central Bank integration assignment.

Project status: live deployment available on Railway.

Live URLs:
- API base: `https://bankapi-production-a99e.up.railway.app/api/v1`
- Swagger UI: `https://bankapi-production-a99e.up.railway.app/docs`
- OpenAPI JSON: `https://bankapi-production-a99e.up.railway.app/api-docs.json`
- Health check: `https://bankapi-production-a99e.up.railway.app/api/v1/health`

## Technologies

- Node.js 20
- Express.js
- SQLite with `better-sqlite3`
- `jose` for ES256 JWT signing and verification
- Swagger UI via `swagger-ui-express`
- Docker and Railway

## Microservices Architecture

The system is split into four independently deployable services:

- `gateway` on port `3000`: public API, API-key authentication, Swagger UI, Central Bank registration and heartbeat
- `user-service` on port `3001`: user registration, user lookup, API key lookup
- `account-service` on port `3002`: account creation, account lookup, debit and credit operations
- `transfer-service` on port `3003`: local transfers, cross-bank transfers, transfer history, ES256 JWT handling

Service communication is done over internal REST calls. Each service owns its own SQLite database file and business logic.

## Database Schema

`user-service/data/users.db`

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  api_key TEXT UNIQUE NOT NULL,
  created_at TEXT NOT NULL
);
```

`account-service/data/accounts.db`

```sql
CREATE TABLE accounts (
  account_number TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  currency TEXT NOT NULL,
  balance TEXT NOT NULL DEFAULT '0.00',
  created_at TEXT NOT NULL
);
```

`transfer-service/data/transfers.db`

```sql
CREATE TABLE transfers (
  transfer_id TEXT PRIMARY KEY,
  source_account TEXT NOT NULL,
  destination_account TEXT NOT NULL,
  amount TEXT NOT NULL,
  currency TEXT NOT NULL,
  converted_amount TEXT,
  exchange_rate TEXT,
  rate_captured_at TEXT,
  status TEXT NOT NULL,
  error_message TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

## Implemented Features

- User registration and lookup
- Bearer authentication using generated API keys
- Account creation and account listing per user
- Public account lookup
- Same-bank transfers
- Cross-bank transfers with ES256-signed JWT payloads
- Transfer history and transfer status lookup
- Central Bank registration
- 25-minute heartbeat refresh
- Central Bank bank-directory caching
- Central Bank exchange-rate caching
- Swagger UI connected to the live implementation
- Transfer idempotency with `transferId`

## API Endpoints

All public endpoints are exposed under `/api/v1`.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/health` | No | Service health |
| `POST` | `/users` | No | Register a user |
| `GET` | `/users/{userId}` | No | Fetch user details |
| `POST` | `/users/{userId}/accounts` | Bearer | Create an account for the authenticated user |
| `GET` | `/users/{userId}/accounts` | Bearer | List authenticated user's accounts |
| `GET` | `/accounts/{accountNumber}` | No | Public account lookup |
| `POST` | `/transfers` | Bearer | Start a same-bank or cross-bank transfer |
| `POST` | `/transfers/receive` | No | Receive signed transfer from another bank |
| `GET` | `/transfers/{transferId}` | Bearer | Get transfer status for owned transfer |
| `GET` | `/users/{userId}/transfers` | Bearer | Get transfer history for user's accounts |

Swagger UI is available at `/docs`.

## Local Run

### Option 1: Docker Compose

```bash
git clone https://github.com/Ken-Janek/Bankapi
cd Bankapi
docker compose up --build
```

Public local URLs:

- `http://localhost:3000/docs`
- `http://localhost:3000/api/v1`

### Option 2: Windows without Docker

```powershell
foreach ($d in "user-service","account-service","transfer-service","gateway") {
  Set-Location $d
  npm install
  Set-Location ..
}

powershell -ExecutionPolicy Bypass -File start-all.ps1
```

## Environment Variables

### gateway

```env
BANK_ID=MIN001
BANK_NAME=MIN001 Branch Bank
BANK_ADDRESS=https://bankapi-production-a99e.up.railway.app/api/v1
CENTRAL_BANK_URL=https://test.diarainfra.com/central-bank
USER_SERVICE_URL=http://user-service.railway.internal:3001
ACCOUNT_SERVICE_URL=http://account-service.railway.internal:3002
TRANSFER_SERVICE_URL=http://transfer-service.railway.internal:3003
JWT_PUBLIC_KEY_PATH=./keys/public.pem
PORT=3000
```

### transfer-service

```env
BANK_ID=MIN001
CENTRAL_BANK_URL=https://test.diarainfra.com/central-bank
ACCOUNT_SERVICE_URL=http://account-service.railway.internal:3002
JWT_PRIVATE_KEY_PATH=./keys/private.pem
PORT=3003
```

### account-service

```env
BANK_ID=MIN001
PORT=3002
```

### user-service

```env
PORT=3001
```

Optional env-based key injection:

- `PUBLIC_KEY_CONTENT` for `gateway`
- `PRIVATE_KEY_CONTENT` for `transfer-service`

The current repository also includes key files for school-project deployment.

## Railway Deployment

Deploy as four separate Railway services from the same repository:

1. Create a Railway project connected to the GitHub repository.
2. Create four services with these root directories:
- `gateway`
- `user-service`
- `account-service`
- `transfer-service`
3. Set the environment variables for each service.
4. Expose `gateway` publicly.
5. Use Railway private networking for service-to-service URLs.

The repository already contains:

- `Dockerfile` in each service directory
- `railway.json` in each service directory

## Example Requests

### 1. Register a user

```bash
curl -X POST https://bankapi-production-a99e.up.railway.app/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"fullName":"Jane Doe","email":"jane@example.com"}'
```

Example response:

```json
{
  "userId": "user-550e8400-e29b-41d4-a716-446655440000",
  "fullName": "Jane Doe",
  "email": "jane@example.com",
  "apiKey": "generated-api-key",
  "createdAt": "2026-05-14T12:00:00.000Z"
}
```

### 2. Create an account

```bash
curl -X POST https://bankapi-production-a99e.up.railway.app/api/v1/users/{userId}/accounts \
  -H "Authorization: Bearer {apiKey}" \
  -H "Content-Type: application/json" \
  -d '{"currency":"EUR"}'
```

### 3. Fund an account for testing

This endpoint exists only for demo and testing:

```bash
curl -X POST https://bankapi-production-a99e.up.railway.app/api/v1/accounts/{accountNumber}/fund \
  -H "Content-Type: application/json" \
  -d '{"amount":1000}'
```

### 4. Make a transfer

```bash
curl -X POST https://bankapi-production-a99e.up.railway.app/api/v1/transfers \
  -H "Authorization: Bearer {apiKey}" \
  -H "Content-Type: application/json" \
  -d '{
    "transferId":"550e8400-e29b-41d4-a716-446655440000",
    "sourceAccount":"MINA3K9Z",
    "destinationAccount":"MINB4L0W",
    "amount":"50.00"
  }'
```

### 5. Read transfer status

```bash
curl https://bankapi-production-a99e.up.railway.app/api/v1/transfers/{transferId} \
  -H "Authorization: Bearer {apiKey}"
```

## Central Bank Integration

Implemented Central Bank interactions:

- `POST /api/v1/banks` for registration
- `GET /api/v1/banks` for bank directory cache
- `POST /api/v1/banks/{bankId}/heartbeat` for heartbeat
- `GET /api/v1/exchange-rates` for FX conversion

Cross-bank incoming transfers are verified with ES256 public-key JWT validation. Outgoing cross-bank transfers are signed with the private key using `jose`.

## Testing Summary

Manual scenarios covered:

- Create user
- Fetch user
- Create account
- List user accounts
- Same-bank transfer
- Transfer status lookup
- Transfer history lookup
- Swagger UI access on live deployment
- Central Bank registration and heartbeat on startup

Known practical note:

- Cross-bank transfer testing requires another working branch-bank implementation registered in the Central Bank directory.

## Security Notes

- API keys are used as Bearer tokens for user-authenticated endpoints.
- Transfer status is restricted to transfers involving the authenticated user's accounts.
- Cross-bank requests are signed and verified with ES256 JWTs.
- Duplicate transfers are blocked by `transferId`.

## Repository

GitHub repository:

- `https://github.com/Ken-Janek/Bankapi`
