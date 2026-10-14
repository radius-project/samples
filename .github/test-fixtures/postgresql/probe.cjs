// Run via kubectl exec -i in the candidate demo container.
const assert = require('node:assert/strict');
const { createFactory } = require(`${process.cwd()}/dist/db/repository`);
const { Pool } = require(`${process.cwd()}/node_modules/pg`);

async function main() {
    for (const name of ['RADIUS_DEMO_POSTGRESQL_TLS', 'RADIUS_DEMO_POSTGRESQL_CA_FILE', 'PGSSLMODE']) {
        assert.equal(process.env[name], undefined, `${name} must be absent in this compatibility test`);
    }
    assert.equal(process.env.CONNECTION_POSTGRESQL_TLS, 'required');
    const factory = createFactory();
    assert.equal(factory.constructor.name, 'PostgresFactory');
    const repository = await factory.create();
    assert.equal(repository.isRealDatabase(), true);
    const verifier = new Pool({
        host: process.env.CONNECTION_POSTGRESQL_HOST,
        port: Number(process.env.CONNECTION_POSTGRESQL_PORT),
        user: process.env.CONNECTION_POSTGRESQL_USERNAME,
        password: process.env.CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD || process.env.CONNECTION_POSTGRESQL_PASSWORD,
        database: process.env.CONNECTION_POSTGRESQL_DATABASE,
    });
    let id;
    try {
        const item = await repository.create({ title: 'postgresql-compatibility', done: false });
        id = item.id;
        assert.equal((await repository.get(id)).title, item.title);
        assert.ok((await repository.list()).some(row => row.id === id));
        let result = await verifier.query('SELECT title, done FROM items WHERE id = $1', [id]);
        assert.deepEqual(result.rows, [{ title: item.title, done: false }]);
        await repository.update({ id, title: 'persisted-update', done: true });
        result = await verifier.query('SELECT title, done FROM items WHERE id = $1', [id]);
        assert.deepEqual(result.rows, [{ title: 'persisted-update', done: true }]);

        // A second connection sees the writes, and the actual repository connection is plaintext.
        result = await repository.pool.query('SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()');
        assert.deepEqual(result.rows, [{ ssl: false }]);
        await repository.delete(id);
        assert.equal(await repository.get(id), null);
        result = await verifier.query('SELECT count(*)::int AS count FROM items WHERE id = $1', [id]);
        assert.equal(result.rows[0].count, 0);
        const response = await fetch('http://localhost:3000/api/todos');
        assert.equal(response.status, 200);
        assert.equal((await response.json()).message, null);
        console.log(JSON.stringify({
            backend: 'PostgreSQL', node: process.version, projectedTls: 'required',
            explicitTls: 'absent', ssl: false, crud: 'passed', persistedRows: 'verified',
        }));
    } finally {
        try {
            if (id) await repository.delete(id);
        } finally {
            await Promise.all([repository.dispose(), verifier.end()]);
        }
    }
}

main().catch(error => {
    // Avoid printing database errors that could contain connection material.
    console.error(`PostgreSQL compatibility probe failed (${error.code || error.name}).`);
    process.exitCode = 1;
});
