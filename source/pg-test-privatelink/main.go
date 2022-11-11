package main

import (
	"context"
	"database/sql"

	"github.com/aws/aws-lambda-go/lambda"
	_ "github.com/lib/pq"
)

type Connections struct {
	PostgresUri string `json:"postgres_uri"`
}

type Response struct {
	Status string `json:"status"`
}

func HandleRequest(ctx context.Context, c Connections) (Response, error) {
	res := &Response{
		Status: CheckDatabase(c.PostgresUri),
	}

	return *res, nil
}

func CheckDatabase(connStr string) string {
	if connStr == "" {
		return "Database not configured. Skipping."
	}

	db, err := sql.Open("postgres", connStr+"?connect_timeout=5")

	if err != nil {
		return err.Error()
	}

	if err = db.Ping(); err != nil {
		return err.Error()
	}

	return "Successfully connected."
}

func main() {
	lambda.Start(HandleRequest)
}
