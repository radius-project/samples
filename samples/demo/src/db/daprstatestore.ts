import { Item, Repository } from './repository';
import { DaprClient } from "@dapr/dapr";
import { v4 as uuidv4 } from 'uuid';

export class DaprStateStoreFactory implements DaprStateStoreFactory {
    constructor(daprComponent: string) {
        this.daprComponent = daprComponent;
    }

    readonly daprComponent: string;
    readonly daprPort: string = process.env.DAPR_HTTP_PORT || '3500';

    async create(): Promise<Repository> {
        const client = new DaprClient({
            daprPort: this.daprPort
        });
        return new DaprStateStoreRepository(client, this.daprComponent);
    }
}

export class DaprStateStoreRepository implements Repository {
    constructor(client: DaprClient, daprComponent: string) {
        this.client = client;
        this.daprComponent = daprComponent;
    }

    client: DaprClient;
    readonly daprComponent: string;

    isRealDatabase(): boolean {
        return true;
    }
    async get(id: string): Promise<Item | null> {
        const items = await this.client.state.get(this.daprComponent, 'todos');
        const item = (items as Item[]).find((i: Item) => i.id === id);
        return item as Item | null;
    }
    async list(): Promise<Item[]> {
        const items = await this.client.state.get(this.daprComponent, 'todos');
        return items as unknown as Item[];
    }
    async update(item: Item): Promise<Item | null> {
        const items = await this.client.state.get(this.daprComponent, 'todos');
        const index = (items as Item[]).findIndex((i: Item) => i.id === item.id);
        if (index < 0) {
            return null;
        }

        (items as Item[])[index] = item;

        await this.client.state.save(
            this.daprComponent,
            [
                {
                    key: 'todos',
                    value: items,
                }
            ]
        );

        return item;
    }
    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;1

        let items = await this.client.state.get(this.daprComponent, 'todos');
        if (!items) {
            items = [item];
        }
        else {
            (items as Item[]).push(item);
        }

        await this.client.state.save(
            this.daprComponent,
            [
                {
                    key: 'todos',
                    value: items,
                }
            ]
        );
        
        return item;
    }
    async delete(id: string): Promise<void> {
        const items = await this.client.state.get(this.daprComponent, 'todos');
        const index = (items as Item[]).findIndex((i: Item) => i.id === id);
        if (index < 0) {
            return;
        }

        (items as Item[]).splice(index, 1);

        await this.client.state.save(
            this.daprComponent,
            [
                {
                    key: 'todos',
                    value: items,
                }
            ]
        );
    }
    async dispose(): Promise<void> {
        await this.client.stop();
    }
}