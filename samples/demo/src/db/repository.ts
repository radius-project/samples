import { MongoFactory  } from './mongo';
import { RedisFactory } from './redis';
import { InMemoryFactory } from './inmemory';
import { DaprFactory } from './dapr';
import { CommunicationProtocolEnum } from '@dapr/dapr';

export interface Item {
    id: string | undefined
    title: string | undefined
    done: boolean | undefined
}

export interface RepositoryFactory {
    create(): Promise<Repository>
}

export interface Repository {
    dispose(): Promise<void>
    isRealDatabase(): boolean
    get(id: string): Promise<Item | null>
    list() : Promise<Item[]>
    update(item: Item) : Promise<Item | null>
    create(item: Item): Promise<Item>
    delete(id: string): Promise<void>
}

export function createFactory(): RepositoryFactory {
    if (process.env.CONNECTION_STATESTORE_COMPONENTNAME) {
      console.log(`Using Dapr state store: found component name '${process.env.CONNECTION_STATESTORE_COMPONENTNAME}'in environment variable CONNECTION_STATESTORE_COMPONENTNAME`);
      return new DaprFactory(process.env.CONNECTION_STATESTORE_COMPONENTNAME, { communicationProtocol: CommunicationProtocolEnum.GRPC });
    }

    if (process.env.CONNECTION_MONGODB_CONNECTIONSTRING) {
      console.log("Using MongoDB: found connection string in environment variable CONNECTION_MONGODB_CONNECTIONSTRING");
      return new MongoFactory(process.env.CONNECTION_MONGODB_CONNECTIONSTRING);
    }

    if (process.env.CONNECTION_REDIS_URL) {
      console.log("Using Redis: found url in environment variable CONNECTION_REDIS_URL");
      return new RedisFactory(process.env.CONNECTION_REDIS_URL);
    }

    if (process.env.CONNECTION_REDIS_HOST) {
      console.log("Using Redis: found hostname in environment variable CONNECTION_REDIS_HOST");
      const connection = { 
        host: process.env.CONNECTION_REDIS_HOST!, 
        port: process.env.CONNECTION_REDIS_PORT!,
        username: process.env.CONNECTION_REDIS_USERNAME || '',
        password: process.env.CONNECTION_REDIS_PASSWORD || '',
      }
  
      let scheme = "redis"
      if (connection.port === "6380") {
        scheme = "rediss"
      }
  
      let usernamePass = "";
      if (connection.username !== "" || connection.password !== "") {
        usernamePass = `${connection.username}:${connection.password}@`
      }
  
      const url = `${scheme}://${usernamePass}${connection.host}:${connection.port}`
      return new RedisFactory(url);
    }
  
    console.log("Using in-memory store: no connection string found");
    return new InMemoryFactory();
  }