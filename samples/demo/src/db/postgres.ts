import { Pool, PoolConfig } from 'pg';
import { readFileSync } from 'node:fs';
import { X509Certificate } from 'node:crypto';
import { Repository, Item, RepositoryFactory } from './repository';
import { v4 as uuidv4 } from 'uuid';

export function postgresTlsConfig(): PoolConfig['ssl'] {
    const mode = process.env.RADIUS_DEMO_POSTGRESQL_TLS;
    const caFile = process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE;
    if (mode === undefined && caFile === undefined) {
        return undefined;
    }
    if (mode !== 'verify-full') {
        throw new Error('Set RADIUS_DEMO_POSTGRESQL_TLS=verify-full when configuring PostgreSQL TLS; omit both TLS settings for legacy behavior.');
    }
    if (!caFile) {
        throw new Error('RADIUS_DEMO_POSTGRESQL_CA_FILE is required with RADIUS_DEMO_POSTGRESQL_TLS=verify-full.');
    }

    let ca: string;
    try {
        ca = readFileSync(caFile, 'utf8');
    } catch {
        throw new Error('Cannot read RADIUS_DEMO_POSTGRESQL_CA_FILE; provide a readable PEM CA bundle.');
    }

    const certificates = ca.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g);
    try {
        if (!certificates?.length ||
            ca.replace(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g, '').trim() ||
            certificates.some(certificate => !new X509Certificate(certificate).ca)) {
            throw new Error('Invalid CA bundle');
        }
    } catch {
        throw new Error('RADIUS_DEMO_POSTGRESQL_CA_FILE must contain a nonempty, valid PEM CA certificate bundle.');
    }
    return { ca, rejectUnauthorized: true };
}

export class PostgresFactory implements RepositoryFactory {
    constructor(private config: PoolConfig) {}

    async create(): Promise<Repository> {
        const pool = new Pool(this.config);
        try {
            await pool.query(`
                CREATE TABLE IF NOT EXISTS items (
                    id UUID PRIMARY KEY,
                    title TEXT NOT NULL,
                    done BOOLEAN NOT NULL
                );
            `);
        } catch (error) {
            try {
                await pool.end();
            } catch {
                console.warn('Failed to close PostgreSQL pool after initialization failed.');
            }
            throw error;
        }

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