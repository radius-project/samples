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
EXPOSE 3000

#command to start the sqsgo server and listen at port 3000
CMD [ "./sqsgo" ]