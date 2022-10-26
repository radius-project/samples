FROM golang:1.19 as builder

WORKDIR /usr/src/app

# Download necessary Go modules
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY *.go ./

# create the go binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/sqsgo .

FROM scratch

WORKDIR /usr/src/app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/src/app/bin/sqsgo ./

# sqsgo server configuration
ENV AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, HTTP_SERVER_PORT

#command to start the sqsgo server and listen at PORT
CMD [ "./sqsgo" ]