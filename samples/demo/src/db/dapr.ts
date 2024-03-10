import { DaprClient, DaprClientOptions } from "@dapr/dapr";
import { v4 as uuidv4 } from 'uuid';
import { Item, Repository, RepositoryFactory } from "./repository";

interface Items {
    [key: string]: Item;
}

/**
 * Factory for creating a {@link Repository} that uses a Dapr state store.
 */
export class DaprFactory implements RepositoryFactory {
    private readonly name: string;
    private readonly options: Partial<DaprClientOptions> | undefined;

    /**
     * Creates a new instance of the factory.
     * @param name The name of the state store.
     * @param options The options for the Dapr client.
     */
    constructor(name: string, options: Partial<DaprClientOptions> | undefined) {
        this.name = name;
        this.options = options;
    }

    async create(): Promise<Repository> {
        const client = new DaprClient(this.options);
        return new DaprRepository(this.name, client);
    }
}

export class DaprRepository implements Repository {
    private readonly name: string;
    private readonly client: DaprClient;

    constructor(name: string, client: DaprClient) {
        this.name = name
        this.client = client;
    }
    dispose(): Promise<void> {
        return this.client.stop();
    }
    isRealDatabase(): boolean {
       return true;
    }
    async get(id: string): Promise<Item | null> {
        const obj = await this.client.state.get(this.name, "items");
        return null
    }
    async list(): Promise<Item[]> {
        const items = await this.read();
        return Object.values(items);
    }
    async update(item: Item): Promise<Item | null> {
        const items = await this.read();
        items[item.id!] = item;
        await this.client.state.save(this.name, [{key: "items", value: JSON.stringify(items)}]);
        return item;
    }
    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;

        const items = await this.read();
        items[item.id!] = item;
        await this.client.state.save(this.name, [{key: "items", value: JSON.stringify(items)}]);
        return item;
    }
    async delete(id: string): Promise<void> {
        const items = await this.read();
        delete items[id];
        await this.client.state.save(this.name, [{key: "items", value: JSON.stringify(items)}]);
    }

    async read(): Promise<Items> {
        const obj = await this.client.state.get(this.name, "items");
        if (obj === "") {
            return {};
        }

        return obj as Items;
    }
}