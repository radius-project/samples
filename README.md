# Radius Samples

This repository contains the source code for quickstarts, reference apps, and tutorials for Radius.

To try out one of these samples, visit https://docs.radapp.io

## Codespace

The current repository offers a codespace setup with Radius and its dependencies installed.  Try it out for free!

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/radius-project/samples)

## Samples

| Sample | Description |
|--------|-------------|
| **demo** | The "swiss army knife" sample for Radius. Displays environment variables, networking information, Radius connections, and more.
| **aws** | A simple app to interact with AWS S3
| **aws-sqs** | A simple app to interact with AWS SQS
| **dapr** | A 2-tier app leveraging Dapr building blocks
| **eshop** | A Rad-ified version of eShop on Containers, the .NET reference app
| **eshop-dapr** | A Rad-ified version of eShop on Dapr
| **volumes** | An app to interact with mounted volumes

### Resource type samples

Each of these samples connects a real third-party application to a cloud resource provisioned through a Radius resource type wired directly to a standard Azure Verified Module (AVM). Every directory is self-contained (`app.bicep`, `env-azure.bicep`, `bicepconfig.json`, and any application source) with its own README.

| Sample | Resource type | Application |
|--------|---------------|-------------|
| **kafka-ui** | `Radius.Messaging/kafka` (Azure Event Hubs) | Kafbat Kafka UI |
| **berriai-litellm** | `Radius.AI/models` (Azure OpenAI) | LiteLLM proxy |
| **mongo-express-mongo-express** | `Radius.Data/mongoDatabases` (Azure Cosmos DB for MongoDB) | mongo-express |
| **dockersamples-todo-list-app** | `Radius.Data/mySqlDatabases` (Azure MySQL) | Docker todo-list-app |
| **sosedoff-pgweb** | `Radius.Data/postgreSqlDatabases` (Azure PostgreSQL) | pgweb, built from source and run |
| **warpstreamlabs-bento** | `Radius.Messaging/rabbitMQ` (Azure Service Bus) | Bento streaming pipeline, built from source |
| **radius-project-samples-demo** | `Radius.Data/redisCaches` (Azure Managed Redis) | Radius samples demo app |
| **sqlpad-sqlpad** | `Radius.Data/sqlServerDatabases` (Azure SQL) | SQLPad SQL client UI, built from source |
| **azure-search-api** | `Radius.AI/search` (Azure AI Search) | Go search API service, built from source |
| **drakkan-sftpgo** | `Radius.Storage/objectStorage` (Azure Blob Storage) | SFTPGo |
