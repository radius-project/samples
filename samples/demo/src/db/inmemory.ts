import { Item, Repository, RepositoryFactory } from "./repository";
import { v4 as uuidv4 } from 'uuid';

export class InMemoryFactory implements RepositoryFactory {
    constructor() {
        this.items = [];
    }

    // Shared state across all instances
    readonly items: Item[];

    async create(): Promise<Repository> {
        return new InMemoryRepository(this.items)
    }
}

export class InMemoryRepository implements Repository {
    constructor(items: Item[]) {
        this.items = items;
    }

    // Shared state across all instances
    readonly items: Item[];

    isRealDatabase(): boolean {
        return false;
    }
    get(id: string): Promise<Item | null> {
        const item = this.items.find(i => i.id == id)
        return Promise.resolve<Item | null>(item ?? null);
    }
    list(): Promise<Item[]> {
        return Promise.resolve(this.items);
    }
    update(item: Item): Promise<Item | null> {
        const index = this.items.findIndex(i => i.id == item.id)
        if (index < 0) {
            return Promise.resolve(null);
        }

        this.items[index] = item;
        return Promise.resolve(item);
    }
    create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;
        this.items.push(item)
        return Promise.resolve(item);
    }
    delete(id: string): Promise<void> {
        const index = this.items.findIndex(i => i.id == id)
        if (index < 0) {
            return Promise.resolve();
        }

        this.items.splice(index, 1);
        return Promise.resolve();
    }
    dispose(): Promise<void> {
        return Promise.resolve();
    }
}