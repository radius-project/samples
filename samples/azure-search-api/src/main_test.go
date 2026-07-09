package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

const testAPIKey = "super-secret-test-key"

type recordedRequest struct {
	Method string
	Path   string
	Query  string
	APIKey string
	Body   []byte
}

type recordingUpstream struct {
	t        *testing.T
	server   *httptest.Server
	mu       sync.Mutex
	requests []recordedRequest
}

func newRecordingUpstream(t *testing.T) *recordingUpstream {
	t.Helper()
	ru := &recordingUpstream{t: t}
	ru.server = httptest.NewServer(http.HandlerFunc(ru.handle))
	t.Cleanup(ru.server.Close)
	return ru
}

func (ru *recordingUpstream) handle(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		ru.t.Errorf("read body: %v", err)
	}
	ru.mu.Lock()
	ru.requests = append(ru.requests, recordedRequest{
		Method: r.Method,
		Path:   r.URL.Path,
		Query:  r.URL.RawQuery,
		APIKey: r.Header.Get("api-key"),
		Body:   body,
	})
	ru.mu.Unlock()

	if r.URL.Query().Get("api-version") != searchAPIVersion {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"bad api-version"}`))
		return
	}
	if r.Header.Get("api-key") != testAPIKey {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":"bad api-key"}`))
		return
	}

	switch {
	case r.Method == http.MethodPut && r.URL.Path == "/indexes/test-index":
		w.WriteHeader(http.StatusCreated)
	case r.Method == http.MethodPost && r.URL.Path == "/indexes/test-index/docs/index":
		w.Header().Set("content-type", "application/json")
		_, _ = w.Write([]byte(`{"value":[{"key":"doc-1","status":true}]}`))
	case r.Method == http.MethodPost && r.URL.Path == "/indexes/test-index/docs/search":
		w.Header().Set("content-type", "application/json")
		_, _ = w.Write([]byte(`{"value":[{"id":"doc-1","content":"hello world"}]}`))
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

func (ru *recordingUpstream) lastRequest(t *testing.T) recordedRequest {
	t.Helper()
	ru.mu.Lock()
	defer ru.mu.Unlock()
	if len(ru.requests) == 0 {
		t.Fatal("expected at least one upstream request")
	}
	return ru.requests[len(ru.requests)-1]
}

func (ru *recordingUpstream) requestCount() int {
	ru.mu.Lock()
	defer ru.mu.Unlock()
	return len(ru.requests)
}

func testClient(endpoint string) *SearchClient {
	return NewSearchClient(endpoint, testAPIKey, "test-index", &http.Client{Timeout: 5 * time.Second})
}

func TestHealthzDoesNotCallUpstream(t *testing.T) {
	ru := newRecordingUpstream(t)
	handler := NewServer(testClient(ru.server.URL), log.New(io.Discard, "", 0))

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if strings.TrimSpace(rec.Body.String()) != `{"status":"ok"}` {
		t.Fatalf("body = %q", rec.Body.String())
	}
	if got := ru.requestCount(); got != 0 {
		t.Fatalf("upstream request count = %d, want 0", got)
	}
}

func TestEnsureIndexIssuesCorrectPUT(t *testing.T) {
	ru := newRecordingUpstream(t)
	client := testClient(ru.server.URL)

	if err := client.EnsureIndex(context.Background()); err != nil {
		t.Fatalf("EnsureIndex() error = %v", err)
	}

	got := ru.lastRequest(t)
	if got.Method != http.MethodPut {
		t.Fatalf("method = %s, want PUT", got.Method)
	}
	if got.Path != "/indexes/test-index" {
		t.Fatalf("path = %s", got.Path)
	}
	if got.Query != "api-version=2024-07-01" {
		t.Fatalf("query = %s", got.Query)
	}
	if got.APIKey != testAPIKey {
		t.Fatalf("api-key header = %q", got.APIKey)
	}

	var payload struct {
		Name   string `json:"name"`
		Fields []struct {
			Name       string `json:"name"`
			Type       string `json:"type"`
			Key        bool   `json:"key"`
			Searchable bool   `json:"searchable"`
		} `json:"fields"`
	}
	if err := json.Unmarshal(got.Body, &payload); err != nil {
		t.Fatalf("unmarshal body: %v", err)
	}
	if payload.Name != "test-index" || len(payload.Fields) != 2 {
		t.Fatalf("unexpected index payload: %+v", payload)
	}
	if payload.Fields[0].Name != "id" || payload.Fields[0].Type != "Edm.String" || !payload.Fields[0].Key || payload.Fields[0].Searchable {
		t.Fatalf("unexpected id field: %+v", payload.Fields[0])
	}
	if payload.Fields[1].Name != "content" || payload.Fields[1].Type != "Edm.String" || payload.Fields[1].Key || !payload.Fields[1].Searchable {
		t.Fatalf("unexpected content field: %+v", payload.Fields[1])
	}
}

func TestPostDocumentsForwardsMergeOrUpload(t *testing.T) {
	ru := newRecordingUpstream(t)
	handler := NewServer(testClient(ru.server.URL), log.New(io.Discard, "", 0))

	req := httptest.NewRequest(http.MethodPost, "/documents", strings.NewReader(`{"id":"doc-1","content":"hello world"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	got := ru.lastRequest(t)
	if got.Method != http.MethodPost || got.Path != "/indexes/test-index/docs/index" || got.Query != "api-version=2024-07-01" {
		t.Fatalf("unexpected upstream request: %+v", got)
	}

	var payload struct {
		Value []map[string]string `json:"value"`
	}
	if err := json.Unmarshal(got.Body, &payload); err != nil {
		t.Fatalf("unmarshal upload body: %v", err)
	}
	if len(payload.Value) != 1 || payload.Value[0]["@search.action"] != "mergeOrUpload" || payload.Value[0]["id"] != "doc-1" || payload.Value[0]["content"] != "hello world" {
		t.Fatalf("unexpected upload body: %+v", payload)
	}
}

func TestSearchForwardsQueryAndReturnsResults(t *testing.T) {
	ru := newRecordingUpstream(t)
	handler := NewServer(testClient(ru.server.URL), log.New(io.Discard, "", 0))

	req := httptest.NewRequest(http.MethodGet, "/search?q=hello", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.TrimSpace(rec.Body.String()) != `{"value":[{"id":"doc-1","content":"hello world"}]}` {
		t.Fatalf("unexpected search response: %s", rec.Body.String())
	}
	got := ru.lastRequest(t)
	if got.Method != http.MethodPost || got.Path != "/indexes/test-index/docs/search" || got.Query != "api-version=2024-07-01" {
		t.Fatalf("unexpected upstream request: %+v", got)
	}
	var payload map[string]string
	if err := json.Unmarshal(got.Body, &payload); err != nil {
		t.Fatalf("unmarshal search body: %v", err)
	}
	if payload["search"] != "hello" {
		t.Fatalf("search payload = %+v", payload)
	}
}

func TestAPIKeyIsNotLoggedOrReturnedOnErrors(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"do not expose ` + testAPIKey + `"}`))
	}))
	defer upstream.Close()

	var logs bytes.Buffer
	handler := NewServer(testClient(upstream.URL), log.New(&logs, "", 0))

	req := httptest.NewRequest(http.MethodPost, "/documents", strings.NewReader(`{"id":"doc-1","content":"hello"}`))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadGateway {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadGateway)
	}
	if strings.Contains(rec.Body.String(), testAPIKey) {
		t.Fatalf("response exposed api key: %s", rec.Body.String())
	}
	if strings.Contains(logs.String(), testAPIKey) {
		t.Fatalf("logs exposed api key: %s", logs.String())
	}
}

func TestEnsureIndexErrorDoesNotContainAPIKey(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"` + testAPIKey + `"}`))
	}))
	defer upstream.Close()

	err := testClient(upstream.URL).EnsureIndex(context.Background())
	if err == nil {
		t.Fatal("expected error")
	}
	if strings.Contains(err.Error(), testAPIKey) {
		t.Fatalf("error exposed api key: %v", err)
	}
}
