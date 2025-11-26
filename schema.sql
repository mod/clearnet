-- DuckDB Schema
CREATE TABLE IF NOT EXISTS transactions (
    hash TEXT PRIMARY KEY,
    address TEXT NOT NULL,
    token TEXT NOT NULL,
    height INTEGER NOT NULL,
    credit TEXT NOT NULL,
    debit TEXT NOT NULL,
    balance TEXT NOT NULL,
    participants TEXT NOT NULL,
    signatures TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (address, token, height)
);

CREATE TABLE IF NOT EXISTS signatures (
    hash TEXT NOT NULL,
    participant TEXT NOT NULL,
    signature TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (hash, participant)
);
