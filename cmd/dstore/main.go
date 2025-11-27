package main

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"os"

	_ "github.com/duckdb/duckdb-go/v2"
)

func main() {
	// open database
	db, err := sql.Open("duckdb", "")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Initialize schema from file

	schema, err := os.ReadFile("schema.sql")
	if err != nil {
		log.Fatal("failed to read schema.sql: ", err)
	}
	if _, err := db.Exec(string(schema)); err != nil {
		log.Fatal("failed to execute schema: ", err)
	}

	// Insert a transaction
	txHash := "0x123abc"
	address := "0xUser1"
	token := "USDC"
	height := 100
	credit := "100.00"
	debit := "0.00"
	balance := "500.00"
	participants := "['0xUser1', '0xUser2']"
	txSignatures := "['sig1', 'sig2']"

	_, err = db.Exec(`
		INSERT INTO transactions (hash, address, token, height, credit, debit, balance, participants, signatures)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, txHash, address, token, height, credit, debit, balance, participants, txSignatures)
	if err != nil {
		log.Fatal("failed to insert transaction: ", err)
	}
	fmt.Println("Inserted transaction:", txHash)

	// Insert a signature
	sigHash := txHash
	participant := "0xUser1"
	signatureVal := "sig1_payload"

	_, err = db.Exec(`
		INSERT INTO signatures (hash, participant, signature)
		VALUES (?, ?, ?)
	`, sigHash, participant, signatureVal)
	if err != nil {
		log.Fatal("failed to insert signature: ", err)
	}
	fmt.Println("Inserted signature for:", participant)

	// Query the transaction
	var (
		qHash         string
		qAddress      string
		qToken        string
		qHeight       int
		qCredit       string
		qDebit        string
		qBalance      string
		qParticipants string
		qSignatures   string
	)

	row := db.QueryRow(`
		SELECT hash, address, token, height, credit, debit, balance, participants, signatures 
		FROM transactions 
		WHERE hash = ?
	`, txHash)

	err = row.Scan(&qHash, &qAddress, &qToken, &qHeight, &qCredit, &qDebit, &qBalance, &qParticipants, &qSignatures)
	if errors.Is(err, sql.ErrNoRows) {
		log.Println("no transaction found")
	} else if err != nil {
		log.Fatal("query transaction error: ", err)
	} else {
		fmt.Printf("\nFetched Transaction:\nHash: %s\nAddress: %s\nToken: %s\nHeight: %d\nBalance: %s\n",
			qHash, qAddress, qToken, qHeight, qBalance)
	}

	// Query the signature
	var (
		sHash        string
		sParticipant string
		sSignature   string
	)

	row = db.QueryRow(`
		SELECT hash, participant, signature
		FROM signatures
		WHERE hash = ? AND participant = ?
	`, sigHash, participant)

	err = row.Scan(&sHash, &sParticipant, &sSignature)
	if errors.Is(err, sql.ErrNoRows) {
		log.Println("no signature found")
	} else if err != nil {
		log.Fatal("query signature error: ", err)
	} else {
		fmt.Printf("\nFetched Signature:\nHash: %s\nParticipant: %s\nSignature: %s\n",
			sHash, sParticipant, sSignature)
	}
}
