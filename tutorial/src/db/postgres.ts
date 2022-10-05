import { Client as PostgresClient } from "pg";
import { Item, Repository, RepostoryFactory } from "./repository";
import { v4 as uuidv4 } from 'uuid';

export class PostgresRepositoryFactory implements RepostoryFactory {
    constructor(connectionString: string) {
        this.connectionString = connectionString;
    }

    readonly connectionString: string;

    async create(): Promise<Repository> {
        console.log("connecting to Postgres");
        
        const client = new PostgresClient(this.connectionString);
        await client.connect();
        console.log("connected to Postgres");
        client.query("CREATE TABLE IF NOT EXISTS todos (id text PRIMARY KEY, title text, done boolean);");
        return new PostgresRepository(client);
    }
}

export class PostgresRepository implements Repository {
    constructor(client: PostgresClient) {
        this.client = client;
    }

    client: PostgresClient

    isRealDatabase(): boolean {
        return true;
    }
    async get(id: string): Promise<Item | null> {
        const res = await this.client.query("SELECT * FROM todos WHERE id = $1", [id]);
        console.log(res)
        return res.rows[0] as Item | null;
    }
    async list(): Promise<Item[]> {
        const res = await this.client.query("SELECT * FROM todos");
        console.log(res)
        return res.rows as Item[];
    }
    async update(item: Item): Promise<Item | null> {
        const res = await this.client.query("UPDATE todos SET id=$1, title=$2, done=$3 WHERE id=$1", [item.id, item.title, item.done]);
        console.log(res)
        return res.rows[0] as Item | null;
    }
    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;

        const res = await this.client.query("INSERT INTO todos (id, title, done) VALUES ($1, $2, $3)", [id, item.title, item.done]);
        console.log(res)
        return item;
    }
    async delete(id: string): Promise<void> {
        const res = await this.client.query("DELETE FROM todos WHERE id = $1", [id]);
        console.log(res);
        return
    }
    async dispose(): Promise<void> {
        await this.client.end();
    }
}
