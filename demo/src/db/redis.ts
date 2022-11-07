import { Item, Repository } from "./repository";
import { createClient } from 'redis';
import { v4 as uuidv4 } from 'uuid';

type RedisClientType = ReturnType<typeof createClient>;

export class RedisFactory implements RedisFactory {
    constructor(connectionString: string) {
        this.connectionString = connectionString;
    }

    readonly connectionString: string;

    async create(): Promise<Repository> {
        let client = createClient({
            url: this.connectionString,
        });

        client.on('error', (err) => console.log('Redis Error', err));
        client.connect();

        await client.ping();
        return new RedisRepository(client)
    }
}

export class RedisRepository implements Repository {
    constructor(client: RedisClientType) {
        this.client = client;
    }

    readonly client: RedisClientType;

    isRealDatabase(): boolean {
        return true;
    }
    async get(id: string): Promise<Item | null> {
        let result = await this.client.hGet('items', id);
        if (result) {
            return JSON.parse(result) as Item;
        }

        return null;
    }
    async list(): Promise<Item[]> {
        let result = await this.client.hVals('items');
        return result.map(s => JSON.parse(s) as Item);
    }
    async update(item: Item): Promise<Item | null> {
        if (!await this.client.hExists('items', item.id!)) {
            return null
        }

        await this.client.hSet('items', item.id!, JSON.stringify(item));
        return item;
    }
    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;
        await this.client.hSet('items', item.id!, JSON.stringify(item));
        return item;
    }
    async delete(id: string): Promise<void> {
        await this.client.hDel('items', id);
    }
    async dispose(): Promise<void> {
        await this.client.quit()
    }
}