package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
)

// useFakeSQS points the SQS client at a server that answers every request with response,
// and returns a channel of the request bodies the server received.
func useFakeSQS(t *testing.T, response string) <-chan map[string]any {
	t.Helper()

	requests := make(chan map[string]any, 2)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request map[string]any
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Errorf("parsing request: %v", err)
		}
		requests <- request
		w.Header().Set("Content-Type", "application/x-amz-json-1.0")
		_, _ = io.WriteString(w, response)
	}))
	t.Cleanup(server.Close)

	sess = session.Must(session.NewSession(&aws.Config{
		Credentials: credentials.NewStaticCredentials("id", "secret", ""),
		Endpoint:    aws.String(server.URL),
		Region:      aws.String("us-east-1"),
	}))
	queueUrl = server.URL + "/queue"

	return requests
}

func TestReceiveEmptyQueue(t *testing.T) {
	useFakeSQS(t, `{}`)

	w := httptest.NewRecorder()
	receive(w, httptest.NewRequest(http.MethodGet, "/receive", nil))

	if got, want := w.Body.String(), "no messages in queue\n"; got != want {
		t.Errorf("body = %q, want %q", got, want)
	}
}

func TestReceiveLongPollsAndDeletesMessage(t *testing.T) {
	requests := useFakeSQS(t, `{"Messages":[{"Body":"hello","ReceiptHandle":"handle"}]}`)

	w := httptest.NewRecorder()
	receive(w, httptest.NewRequest(http.MethodGet, "/receive", nil))

	if got := w.Body.String(); !strings.Contains(got, "hello") {
		t.Errorf("body = %q, want it to contain the message", got)
	}
	if got, want := (<-requests)["WaitTimeSeconds"], float64(20); got != want {
		t.Errorf("ReceiveMessage WaitTimeSeconds = %v, want %v", got, want)
	}
	if got, want := (<-requests)["ReceiptHandle"], "handle"; got != want {
		t.Errorf("DeleteMessage ReceiptHandle = %v, want %v", got, want)
	}
}
