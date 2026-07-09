FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/azure-search-api .

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/azure-search-api /azure-search-api
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/azure-search-api"]
