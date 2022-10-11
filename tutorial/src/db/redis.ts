import { Item, Repository } from "./repository";
import { v4 as uuidv4 } from 'uuid';
import { Cluster as RedisCluster } from 'ioredis';

type RedisClientType = RedisCluster

export class RedisRepositoryFactory implements RedisRepositoryFactory {
    constructor(connectionString: string) {
        this.connectionString = connectionString;
    }

    readonly connectionString: string;

    async create(): Promise<Repository> {
        const redisOptions = this.connectionString.startsWith('rediss') ? {
            tls: {}
        } : undefined
        const client = new RedisCluster([this.connectionString], {
            dnsLookup: (address, callback) => callback(null, address),
            redisOptions
        })
        client.on('error', (err) => console.log('Redis Error', err));
        try {
            await client.connect();
        } catch (err) {
            if (err instanceof Error && err.message.includes('Redis is already connecting/connected')) {
                console.log('Reconnecting to Redis');
            } else {
                console.error('Redis Error', err);
            }
        }
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
        let result = await this.client.hget('items', id);
        if (result) {
            return JSON.parse(result) as Item;
        }

        return null;
    }
    async list(): Promise<Item[]> {
        let result = await this.client.hvals('items');
        return result.map(s => JSON.parse(s) as Item);
    }
    async update(item: Item): Promise<Item | null> {
        if (!await this.client.hexists('items', item.id!)) {
            return null
        }

        await this.client.hset('items', item.id!, JSON.stringify(item));
        return item;
    }
    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;
        await this.client.hset('items', item.id!, JSON.stringify(item));
        return item;
    }
    async delete(id: string): Promise<void> {
        await this.client.hdel('items', id);
    }
    async dispose(): Promise<void> {
        this.client.quit()
    }
}