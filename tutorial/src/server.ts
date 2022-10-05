import express from 'express';
import path from 'path';
import * as routes from "./routes";
import { RepostoryFactory as RepositoryFactory } from "./db/repository";
import { MongoRepositoryFactory as MongoFactory } from './db/mongo';
import { RedisRepositoryFactory as RedisFactory } from './db/redis';
import { PostgresRepositoryFactory as PostgresFactory } from './db/postgres';
import { InMemoryFactory } from './db/inmemory';

export async function main(): Promise<void> {
  const app = express();
  const port = process.env.PORT || 3000;

  app.use(express.json());

  app.set("views", path.join(__dirname, "views"));
  app.set("view engine", "ejs");

  app.use(express.static(path.join(__dirname, "www")));

  routes.register(app, createFactory());

  function logError(err: any, req: any, res: any, next: any) {
    console.log(err)
    next()
  }
  app.use(logError)

  process.on('SIGINT', function () {
    console.log("\nGracefully shutting down from SIGINT (Ctrl-C)");
    process.exit(1);
  });

  app.listen(port, () =>
    console.log(`App listening on port ${port}!`),
  );
}

function createFactory(): RepositoryFactory {
  if (process.env.CONNECTION_ITEMSTORE_CONNECTIONSTRING) { // Used by tutorial
    console.log("Using MongoDB: found connection string in environment variable CONNECTION_ITEMSTORE_CONNECTIONSTRING");
    return new MongoFactory(process.env.CONNECTION_ITEMSTORE_CONNECTIONSTRING);
  }

  if (process.env.CONNECTION_MONGODB_CONNECTIONSTRING) {
    console.log("Using MongoDB: found connection string in environment variable CONNECTION_MONGODB_CONNECTIONSTRING");
    return new MongoFactory(process.env.CONNECTION_MONGODB_CONNECTIONSTRING);
  }

  if (process.env.CONNECTION_REDIS_CONNECTIONSTRING) {
    console.log("Using Redis: found connection string in environment variable CONNECTION_REDIS_CONNECTIONSTRING");
    return new RedisFactory(process.env.CONNECTION_REDIS_CONNECTIONSTRING);
  }

  if (process.env.CONNECTION_REDIS_HOST) {
    console.log("Using Redis: found hostname in environment variable CONNECTION_REDIS_HOST");
    const connection = { 
      host: process.env.CONNECTION_REDIS_HOST!, 
      port: process.env.CONNECTION_REDIS_PORT!,
      username: process.env.CONNECTION_REDIS_USERNAME,
      password: process.env.CONNECTION_REDIS_PASSWORD,
    }

    let scheme = "redis"
    if (connection.port === "6380") {
      scheme = "rediss"
    }

    let usernamePass = "";
    if (connection.username && connection.username !== "" && connection.password && connection.password !== "") {
      usernamePass = `${connection.username}:${connection.password}@`
    }

    const url = `${scheme}://${usernamePass}${connection.host}:${connection.port}`
    return new RedisFactory(url);
  }

  if (process.env.CONNECTION_POSTGRES_SERVER) {
    console.log("Using PostgreSQL: found connection string in environment variable CONNECTION_POSTGRES_SERVER");
    return new PostgresFactory(process.env.CONNECTION_POSTGRES_SERVER);
  }

  console.log("Using in-memory store: no connection string found");
  return new InMemoryFactory();
}

main()
