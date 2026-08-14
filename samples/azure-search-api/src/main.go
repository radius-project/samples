package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"
)

const (
	defaultPort      = "8080"
	defaultIndexName = "radius-sample"
)

func main() {
	logger := log.New(os.Stdout, "azure-search-api: ", log.LstdFlags)

	port := getenvDefault("PORT", defaultPort)
	indexName := getenvDefault("SEARCH_INDEX_NAME", defaultIndexName)
	client := NewSearchClient(
		os.Getenv("CONNECTION_SEARCH_ENDPOINT"),
		os.Getenv("CONNECTION_SEARCH_APIKEY"),
		indexName,
		&http.Client{Timeout: 30 * time.Second},
	)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	if err := client.EnsureIndex(ctx); err != nil {
		logger.Printf("warning: unable to ensure search index %q at startup: %v", indexName, err)
	} else {
		logger.Printf("search index %q is ready", indexName)
	}
	cancel()

	addr := ":" + port
	logger.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, NewServer(client, logger)); err != nil {
		logger.Fatalf("server stopped: %v", err)
	}
}

func getenvDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
