package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type Server struct {
	client *SearchClient
	logger *log.Logger
}

func NewServer(client *SearchClient, logger *log.Logger) http.Handler {
	if logger == nil {
		logger = log.Default()
	}
	server := &Server{client: client, logger: logger}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", server.healthz)
	mux.HandleFunc("/documents", server.documents)
	mux.HandleFunc("/search", server.search)
	return mux
}

func (s *Server) healthz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	w.Header().Set("content-type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s *Server) documents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	defer r.Body.Close()

	var doc Document
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&doc); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON document")
		return
	}
	if doc.ID == "" || doc.Content == "" {
		writeError(w, http.StatusBadRequest, "id and content are required")
		return
	}

	if err := s.client.UploadDocument(r.Context(), doc); err != nil {
		s.logger.Printf("document upload failed: %v", err)
		writeError(w, http.StatusBadGateway, "search service request failed")
		return
	}

	w.Header().Set("content-type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s *Server) search(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	query := r.URL.Query().Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "q query parameter is required")
		return
	}

	body, err := s.client.Search(r.Context(), query)
	if err != nil {
		s.logger.Printf("search failed: %v", err)
		writeError(w, http.StatusBadGateway, "search service request failed")
		return
	}

	w.Header().Set("content-type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(body)
}

func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("content-type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}
