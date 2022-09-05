export interface Item {
    id: string | undefined
    title: string | undefined
    done: boolean | undefined
}

export interface RepostoryFactory {
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