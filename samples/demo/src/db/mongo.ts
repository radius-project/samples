import {  MongoClient } from "mongodb";
import { Item, Repository, RepositoryFactory } from "./repository";
import { v4 as uuidv4 } from 'uuid';

export class MongoFactory implements RepositoryFactory {
    constructor(connectionString: string) {
        this.connectionString = connectionString;
    }

    readonly connectionString: string;

    async create(): Promise<Repository> {
        const client = new MongoClient(this.connectionString);
        await client.connect()
        return new MongoRepository(client);
    }
}

export class MongoRepository implements Repository {
    constructor(client: MongoClient) {
        this.client = client;
    }

    client: MongoClient

    isRealDatabase(): boolean {
        return true;
    }
    async get(id: string): Promise<Item | null> {
        const collection = this.client.db("todos").collection("todos");
        const item = await collection.findOne({ id: id });
        return item as Item | null;
    }
    async list(): Promise<Item[]> {
        const collection = this.client.db("todos").collection("todos");
        const items = await collection.find({}).toArray();
        return items as unknown as Item[];
    }
    async update(item: Item): Promise<Item | null> {
        const collection = this.client.db("todos").collection("todos");
        const result = await collection.findOneAndReplace(
            { id: item.id, }, 
            {
                id: item.id,
                title: item.title,
                done: item.done,
            });
        return result?.value as Item | null;
    }
    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;

        const collection = this.client.db("todos").collection("todos");
        const result = await collection.insertOne(item);
        return item;
    }
    async delete(id: string): Promise<void> {
        const collection = this.client.db("todos").collection("todos");
        await collection.findOneAndDelete({ id: id });
    }
    async dispose(): Promise<void> {
        await this.client.close();
    }
}
