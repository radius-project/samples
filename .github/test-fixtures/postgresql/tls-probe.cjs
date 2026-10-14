// Run with kubectl exec -i in the deployed demo, passing only public test inputs.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createFactory } = require(`${process.cwd()}/dist/db/repository`);
const { Pool } = require(`${process.cwd()}/node_modules/pg`);

async function main() {
    const [mode, expectedHost, serviceIp, wrongCaBase64] = process.argv.slice(2);
    assert.equal(process.env.RADIUS_DEMO_POSTGRESQL_TLS, 'verify-full');
    assert.equal(process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE, '/etc/postgresql-ca/ca.crt');
    assert.equal(process.env.CONNECTION_POSTGRESQL_HOST, expectedHost);
    const factory = createFactory();
    assert.equal(factory.constructor.name, 'PostgresFactory');
    if (mode === 'old-server') {
        await assert.rejects(factory.create(), /server does not support SSL/i);
        console.log('Verified client rejected the old plaintext server without downgrade.');
        return;
    }
    assert.equal(mode, 'tls');
    const ca = fs.readFileSync(process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE, 'utf8');
    assert.deepEqual(fs.readdirSync('/etc/postgresql-ca').filter(name => !name.startsWith('..')), ['ca.crt']);
    assert.ok(!ca.includes('PRIVATE KEY'));
    assert.throws(() => fs.writeFileSync('/etc/postgresql-ca/write-probe', 'test'), { code: 'EROFS' });
    const options = {
        host: expectedHost,
        port: Number(process.env.CONNECTION_POSTGRESQL_PORT),
        user: process.env.CONNECTION_POSTGRESQL_USERNAME,
        password: process.env.CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD || process.env.CONNECTION_POSTGRESQL_PASSWORD,
        database: process.env.CONNECTION_POSTGRESQL_DATABASE,
        connectionTimeoutMillis: 5000,
        ssl: { ca, rejectUnauthorized: true },
    };
    const repository = await factory.create();
    assert.equal(repository.isRealDatabase(), true);
    const verifier = new Pool(options);
    let id;
    try {
        const response = await fetch('http://localhost:3000/api/todos', {
            method: 'POST', headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ title: 'verified-tls-persistence', done: false }),
        });
        assert.equal(response.status, 200);
        const item = await response.json();
        id = item.id;
        assert.equal((await repository.get(id)).title, item.title);
        let result = await verifier.query('SELECT title, done FROM items WHERE id = $1', [id]);
        assert.deepEqual(result.rows, [{ title: item.title, done: false }]);
        const update = await fetch(`http://localhost:3000/api/todos/${id}`, {
            method: 'PUT', headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ title: 'verified-tls-update', done: true }),
        });
        assert.equal(update.status, 200);
        result = await verifier.query('SELECT title, done FROM items WHERE id = $1', [id]);
        assert.deepEqual(result.rows, [{ title: 'verified-tls-update', done: true }]);
        result = await repository.pool.query('SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()');
        assert.deepEqual(result.rows, [{ ssl: true }]);
        const list = await fetch('http://localhost:3000/api/todos');
        const body = await list.json();
        assert.equal(body.message, null);
        assert.ok(body.items.some(row => row.id === id));
        const deleted = await fetch(`http://localhost:3000/api/todos/${id}`, { method: 'DELETE' });
        assert.equal(deleted.status, 204);
        result = await verifier.query('SELECT count(*)::int AS count FROM items WHERE id = $1', [id]);
        assert.equal(result.rows[0].count, 0);
        console.log(JSON.stringify({ backend: 'PostgreSQL', node: process.version, ssl: true, httpCrud: 'passed', persistedRows: 'verified', caMount: 'read-only' }));
    } finally {
        try {
            if (id) await repository.delete(id);
        } finally {
            await Promise.all([repository.dispose(), verifier.end()]);
        }
    }
    const plaintext = new Pool({ ...options, ssl: false });
    try {
        await assert.rejects(plaintext.query('SELECT 1'), { code: '28000' });
    } finally {
        await plaintext.end();
    }
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'postgresql-ca-test-'));
    const caFile = process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE;
    try {
        const wrongCa = path.join(directory, 'wrong-ca.crt');
        fs.writeFileSync(wrongCa, Buffer.from(wrongCaBase64, 'base64'));
        process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE = wrongCa;
        await assert.rejects(createFactory().create(), error =>
            ['SELF_SIGNED_CERT_IN_CHAIN', 'UNABLE_TO_VERIFY_LEAF_SIGNATURE', 'UNABLE_TO_GET_ISSUER_CERT_LOCALLY'].includes(error.code));
        process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE = caFile;
        process.env.CONNECTION_POSTGRESQL_HOST = serviceIp;
        await assert.rejects(createFactory().create(), { code: 'ERR_TLS_CERT_ALTNAME_INVALID' });
        console.log('Wrong CA, wrong hostname/SAN, and plaintext clients rejected without downgrade.');
    } finally {
        process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE = caFile;
        process.env.CONNECTION_POSTGRESQL_HOST = expectedHost;
        fs.rmSync(directory, { recursive: true });
    }
}

main().catch(error => {
    console.error(`PostgreSQL TLS probe failed (${error.code || error.name}).`);
    process.exitCode = 1;
});
