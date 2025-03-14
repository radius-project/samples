import { Pool } from 'pg';
import { Repository, Item, RepositoryFactory } from './repository';
import { v4 as uuidv4 } from 'uuid';

export class PostgresFactory implements RepositoryFactory {
    private connectionString: string;

    constructor(connectionString: string) {
        this.connectionString = connectionString;
    }

    async create(): Promise<Repository> {
        const pool = new Pool({
            connectionString: this.connectionString,
        });

        // Ensure the table exists
        await pool.query(`
            CREATE TABLE IF NOT EXISTS items (
                id UUID PRIMARY KEY,
                title TEXT NOT NULL,
                done BOOLEAN NOT NULL
            );
        `);

        return new PostgresRepository(pool);
    }
}

export class PostgresRepository implements Repository {
    private pool: Pool;

    constructor(pool: Pool) {
        this.pool = pool;
    }

    async dispose(): Promise<void> {
        await this.pool.end();
    }

    isRealDatabase(): boolean {
        return true;
    }

    async get(id: string): Promise<Item | null> {
        const result = await this.pool.query('SELECT * FROM items WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return null;
        }
        return result.rows[0];
    }

    async list(): Promise<Item[]> {
        const result = await this.pool.query('SELECT * FROM items');
        return result.rows;
    }

    async update(item: Item): Promise<Item | null> {
        const result = await this.pool.query('UPDATE items SET title = $1, done = $2 WHERE id = $3 RETURNING *', [item.title, item.done, item.id]);
        if (result.rows.length === 0) {
            return null;
        }
        return result.rows[0];
    }

    async create(item: Item): Promise<Item> {
        const id = uuidv4();
        item.id = id;
        const result = await this.pool.query('INSERT INTO items (id, title, done) VALUES ($1, $2, $3) RETURNING *', [item.id, item.title, item.done]);
        return result.rows[0];
    }

    async delete(id: string): Promise<void> {
        await this.pool.query('DELETE FROM items WHERE id = $1', [id]);
    }
}