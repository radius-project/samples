package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awsutil"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
)

var queueUrl = os.Getenv("SQS_QUEUE_URL")

const visibilityTimeout = 0 * time.Second

var sess *session.Session

func send(w http.ResponseWriter, req *http.Request) {
	svc := sqs.New(sess)
	_, err := svc.SendMessage(&sqs.SendMessageInput{
		DelaySeconds: aws.Int64(10),
		MessageAttributes: map[string]*sqs.MessageAttributeValue{
			"Title": {
				DataType:    aws.String("String"),
				StringValue: aws.String("The Whistler"),
			},
			"Author": {
				DataType:    aws.String("String"),
				StringValue: aws.String("John Grisham"),
			},
			"WeeksOn": {
				DataType:    aws.String("Number"),
				StringValue: aws.String("6"),
			},
		},
		MessageBody: aws.String("Information about current NY Times fiction bestseller for week of 12/11/2016."),
		QueueUrl:    aws.String(queueUrl),
	})

	if err != nil {
		fmt.Fprintln(w, "error receiving sqs message request: "+err.Error())
		return
	}
	fmt.Fprintln(w, "sqs message sent to "+queueUrl)
}

// Message encapsulates all the information to publish in a message
type Message struct {
	Body              json.RawMessage            `json:"body"`
	Headers           map[string]json.RawMessage `json:"headers"`
	Environment       string                     `json:"env"`
	PublishTime       int64                      `json:"publishTime"`
	MessageAttributes []Attributes               `json:"messageAttributes"`
}

type Attributes struct {
	Title   string `json:"title"`
	Author  string `json:"author"`
	WeeksOn string `json:"weeksOn"`
}

func receive(w http.ResponseWriter, req *http.Request) {
	svc := sqs.New(sess)
	resp, err := svc.ReceiveMessage(&sqs.ReceiveMessageInput{
		AttributeNames: []*string{
			aws.String(sqs.MessageSystemAttributeNameSentTimestamp),
		},
		MessageAttributeNames: []*string{
			aws.String(sqs.QueueAttributeNameAll),
		},
		QueueUrl:            aws.String(queueUrl),
		MaxNumberOfMessages: aws.Int64(1),
		VisibilityTimeout:   aws.Int64(int64(visibilityTimeout.Seconds())),
	})
	if err != nil {
		fmt.Fprintln(w, "error receiving sqs message request: "+err.Error())
		return
	}

	for _, msg := range resp.Messages {
		fmt.Fprintln(w, awsutil.Prettify(*msg))
	}

}

func main() {

	http.HandleFunc("/send", send)
	http.HandleFunc("/receive", receive)

	sess = session.Must(session.NewSession())

	_ = http.ListenAndServe(":3000", nil)
}
