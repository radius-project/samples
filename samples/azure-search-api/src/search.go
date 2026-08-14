package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const searchAPIVersion = "2024-07-01"

// SearchClient is a small Azure AI Search REST client.
type SearchClient struct {
	endpoint   string
	apiKey     string
	indexName  string
	httpClient *http.Client
}

// Document is the JSON payload accepted by POST /documents.
type Document struct {
	ID      string `json:"id"`
	Content string `json:"content"`
}

func NewSearchClient(endpoint, apiKey, indexName string, httpClient *http.Client) *SearchClient {
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 30 * time.Second}
	}
	return &SearchClient{
		endpoint:   strings.TrimRight(strings.TrimSpace(endpoint), "/"),
		apiKey:     apiKey,
		indexName:  indexName,
		httpClient: httpClient,
	}
}

func (c *SearchClient) EnsureIndex(ctx context.Context) error {
	body := map[string]any{
		"name": c.indexName,
		"fields": []map[string]any{
			{
				"name":       "id",
				"type":       "Edm.String",
				"key":        true,
				"searchable": false,
			},
			{
				"name":       "content",
				"type":       "Edm.String",
				"searchable": true,
			},
		},
	}

	status, _, err := c.doJSON(ctx, http.MethodPut, "/indexes/"+url.PathEscape(c.indexName), body)
	if err != nil {
		return err
	}
	if status == http.StatusOK || status == http.StatusCreated || status == http.StatusNoContent {
		return nil
	}
	return fmt.Errorf("ensure index failed: upstream returned HTTP %d", status)
}

func (c *SearchClient) UploadDocument(ctx context.Context, doc Document) error {
	body := map[string]any{
		"value": []map[string]any{
			{
				"@search.action": "mergeOrUpload",
				"id":             doc.ID,
				"content":        doc.Content,
			},
		},
	}

	status, _, err := c.doJSON(ctx, http.MethodPost, "/indexes/"+url.PathEscape(c.indexName)+"/docs/index", body)
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return fmt.Errorf("upload document failed: upstream returned HTTP %d", status)
	}
	return nil
}

func (c *SearchClient) Search(ctx context.Context, query string) ([]byte, error) {
	body := map[string]string{"search": query}
	status, responseBody, err := c.doJSON(ctx, http.MethodPost, "/indexes/"+url.PathEscape(c.indexName)+"/docs/search", body)
	if err != nil {
		return nil, err
	}
	if status != http.StatusOK {
		return nil, fmt.Errorf("search failed: upstream returned HTTP %d", status)
	}
	return responseBody, nil
}

func (c *SearchClient) doJSON(ctx context.Context, method, path string, payload any) (int, []byte, error) {
	if c.endpoint == "" {
		return 0, nil, errors.New("search endpoint is not configured")
	}
	if c.apiKey == "" {
		return 0, nil, errors.New("search api key is not configured")
	}
	if c.indexName == "" {
		return 0, nil, errors.New("search index name is not configured")
	}

	requestURL, err := c.url(path)
	if err != nil {
		return 0, nil, err
	}

	var body bytes.Buffer
	if err := json.NewEncoder(&body).Encode(payload); err != nil {
		return 0, nil, fmt.Errorf("encode search request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, method, requestURL, &body)
	if err != nil {
		return 0, nil, fmt.Errorf("create search request: %w", err)
	}
	req.Header.Set("api-key", c.apiKey)
	req.Header.Set("accept", "application/json")
	req.Header.Set("content-type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, nil, fmt.Errorf("call search service: %w", err)
	}
	defer resp.Body.Close()

	responseBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return resp.StatusCode, nil, fmt.Errorf("read search response: %w", err)
	}
	return resp.StatusCode, responseBody, nil
}

func (c *SearchClient) url(path string) (string, error) {
	u, err := url.Parse(c.endpoint)
	if err != nil {
		return "", fmt.Errorf("parse search endpoint: %w", err)
	}
	if u.Scheme == "" || u.Host == "" {
		return "", errors.New("search endpoint must be an absolute URL")
	}
	u.Path = strings.TrimRight(u.Path, "/") + path
	q := u.Query()
	q.Set("api-version", searchAPIVersion)
	u.RawQuery = q.Encode()
	return u.String(), nil
}
