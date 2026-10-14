const { test, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { rootCertificates } = require('node:tls');
const pg = require('pg');
const OriginalPool = pg.Pool;
const { createFactory } = require('../dist/db/repository');
const { PostgresFactory } = require('../dist/db/postgres');

const originalEnvironment = { ...process.env };
let directory;
let caFile;
let pools;

beforeEach(t => {
    for (const name of Object.keys(process.env)) {
        if (name.startsWith('CONNECTION_') || name.startsWith('PG') || name.startsWith('RADIUS_DEMO_POSTGRESQL_')) {
            delete process.env[name];
        }
    }
    process.env.CONNECTION_POSTGRESQL_HOST = 'postgresql.example.test';
    directory = fs.mkdtempSync(path.join(os.tmpdir(), 'radius-pg-test-'));
    caFile = path.join(directory, 'ca.pem');
    fs.writeFileSync(caFile, rootCertificates[0]);
    pools = [];
    t.mock.method(console, 'log', () => {});
    pg.Pool = class {
        constructor(config) {
            this.config = config;
            this.endCalls = 0;
            this.queries = [];
            pools.push(this);
        }
        async query(sql) {
            this.queries.push(sql);
            return { rows: [] };
        }
        async end() {
            this.endCalls++;
        }
    };
});

afterEach(() => {
    pg.Pool = OriginalPool;
    process.env = { ...originalEnvironment };
    fs.rmSync(directory, { recursive: true });
});

async function config() {
    const repository = await createFactory().create();
    assert.equal(repository.isRealDatabase(), true);
    await repository.dispose();
    return pools[0].config;
}

function enableTls() {
    process.env.RADIUS_DEMO_POSTGRESQL_TLS = 'verify-full';
    process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE = caFile;
}

test('legacy mode omits ssl even when the old Recipe projects required', async () => {
    process.env.CONNECTION_POSTGRESQL_TLS = 'required';
    const options = await config();
    assert.equal(Object.hasOwn(options, 'ssl'), false);
    assert.equal(Object.hasOwn(options, 'connectionString'), false);
    assert.equal(new pg.Client(options).connectionParameters.ssl, false);
});

for (const mode of ['disable', 'no-verify', 'require', 'verify-full']) {
    test(`legacy mode preserves ambient PGSSLMODE=${mode}`, async () => {
        process.env.PGSSLMODE = mode;
        const options = await config();
        assert.equal(Object.hasOwn(options, 'ssl'), false);
        assert.deepEqual(
            new pg.Client(options).connectionParameters.ssl,
            new pg.Client({ host: options.host }).connectionParameters.ssl
        );
    });
    test(`verified TLS overrides ambient PGSSLMODE=${mode}`, async () => {
        process.env.PGSSLMODE = mode;
        enableTls();
        const options = await config();
        assert.deepEqual(options.ssl, { ca: rootCertificates[0], rejectUnauthorized: true });
        assert.deepEqual(new pg.Client(options).connectionParameters.ssl, options.ssl);
        assert.equal(Object.hasOwn(options.ssl, 'servername'), false);
        assert.equal(Object.hasOwn(options.ssl, 'checkServerIdentity'), false);
    });
}

test('accepts a bundle of CA certificates', async () => {
    enableTls();
    const bundle = `${rootCertificates[0]}\n${rootCertificates[1]}\n`;
    fs.writeFileSync(caFile, bundle);
    assert.equal((await config()).ssl.ca, bundle);
});

for (const mode of ['', 'required', 'disable', 'no-verify', 'VERIFY-FULL']) {
    test(`rejects unsupported explicit mode ${JSON.stringify(mode)}`, () => {
        process.env.RADIUS_DEMO_POSTGRESQL_TLS = mode;
        assert.throws(createFactory, /RADIUS_DEMO_POSTGRESQL_TLS=verify-full/);
        assert.equal(pools.length, 0);
    });
}

test('rejects a CA setting without an explicit mode, including an empty setting', () => {
    for (const value of [caFile, '']) {
        process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE = value;
        assert.throws(createFactory, /RADIUS_DEMO_POSTGRESQL_TLS=verify-full/);
    }
});

test('requires a CA file with explicit TLS', () => {
    process.env.RADIUS_DEMO_POSTGRESQL_TLS = 'verify-full';
    assert.throws(createFactory, /CA_FILE is required/);
    process.env.RADIUS_DEMO_POSTGRESQL_CA_FILE = '';
    assert.throws(createFactory, /CA_FILE is required/);
});

test('missing and unreadable CA files produce a nonsecret diagnostic', t => {
    enableTls();
    fs.unlinkSync(caFile);
    assert.throws(createFactory, { message: 'Cannot read RADIUS_DEMO_POSTGRESQL_CA_FILE; provide a readable PEM CA bundle.' });
    t.mock.method(fs, 'readFileSync', () => {
        throw new Error('EACCES: sensitive path and content');
    });
    assert.throws(createFactory, { message: 'Cannot read RADIUS_DEMO_POSTGRESQL_CA_FILE; provide a readable PEM CA bundle.' });
});

for (const contents of ['', ' \n', 'not a certificate', '-----BEGIN CERTIFICATE-----\nbad\n-----END CERTIFICATE-----',
    `${rootCertificates[0]}\nprivate or malformed trailing material`,
    `${rootCertificates[0]}\n-----BEGIN CERTIFICATE-----\nbad\n-----END CERTIFICATE-----`]) {
    test(`rejects invalid CA material (${contents.length} bytes)`, () => {
        enableTls();
        fs.writeFileSync(caFile, contents);
        assert.throws(createFactory, /nonempty, valid PEM CA certificate bundle/);
        assert.equal(pools.length, 0);
    });
}

test('connection fields preserve reserved characters without URI or SSL query interpretation', async () => {
    enableTls();
    const user = 'user:@/%?#&=';
    const password = 'password:@/%?#&=sslmode=no-verify';
    const database = 'database?sslmode=disable&sslrootcert=other';
    Object.assign(process.env, {
        CONNECTION_POSTGRESQL_PORT: '5433',
        CONNECTION_POSTGRESQL_USERNAME: user,
        CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD: password,
        CONNECTION_POSTGRESQL_DATABASE: database,
    });
    const options = await config();
    const parsed = new pg.Client(options).connectionParameters;
    assert.equal(parsed.host, 'postgresql.example.test');
    assert.equal(parsed.port, 5433);
    assert.equal(parsed.user, user);
    assert.equal(parsed.password, password);
    assert.equal(parsed.database, database);
    assert.deepEqual(parsed.ssl, options.ssl);
    assert.equal(Object.hasOwn(options, 'connectionString'), false);
});

for (const [secret, legacy, expected, warnings] of [
    ['authored-password', 'legacy-password', 'authored-password', 1],
    ['same-password', 'same-password', 'same-password', 0],
    ['authored-password', undefined, 'authored-password', 0],
    [undefined, 'legacy-password', 'legacy-password', 0],
    ['', 'legacy-password', 'legacy-password', 0],
    [undefined, undefined, '', 0],
]) {
    test(`password precedence: secret=${secret !== undefined}, legacy=${legacy !== undefined}, warnings=${warnings}`, async t => {
        if (secret !== undefined) process.env.CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD = secret;
        if (legacy !== undefined) process.env.CONNECTION_POSTGRESQL_PASSWORD = legacy;
        const warn = t.mock.method(console, 'warn', () => {});
        assert.equal((await config()).password, expected);
        assert.equal(warn.mock.callCount(), warnings);
        for (const call of warn.mock.calls) {
            assert.deepEqual(call.arguments, [
                'Conflicting PostgreSQL passwords found; using CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD instead of CONNECTION_POSTGRESQL_PASSWORD',
            ]);
        }
    });
}

test('preserves all driver priorities and parses TLS only for PostgreSQL', () => {
    Object.assign(process.env, {
        CONNECTION_STATESTORE_COMPONENTNAME: 'state',
        CONNECTION_MONGODB_CONNECTIONSTRING: 'mongodb://localhost',
        CONNECTION_REDIS_URL: 'redis://url-host:6379',
        CONNECTION_REDIS_HOST: 'redis-host',
        CONNECTION_REDIS_PORT: '6379',
        RADIUS_DEMO_POSTGRESQL_TLS: 'invalid',
        RADIUS_DEMO_POSTGRESQL_CA_FILE: 'nonexistent',
    });
    for (const [variable, factory] of [
        ['CONNECTION_STATESTORE_COMPONENTNAME', 'DaprFactory'],
        ['CONNECTION_MONGODB_CONNECTIONSTRING', 'MongoFactory'],
        ['CONNECTION_REDIS_URL', 'RedisFactory'],
        ['CONNECTION_REDIS_HOST', 'RedisFactory'],
    ]) {
        assert.equal(createFactory().constructor.name, factory);
        delete process.env[variable];
    }
    assert.throws(createFactory, /RADIUS_DEMO_POSTGRESQL_TLS/);
    delete process.env.CONNECTION_POSTGRESQL_HOST;
    assert.equal(createFactory().constructor.name, 'InMemoryFactory');
    assert.equal(pools.length, 0);
});

test('successful initialization retains the pool until repository disposal', async () => {
    const repository = await createFactory().create();
    assert.match(pools[0].queries[0], /CREATE TABLE IF NOT EXISTS items/);
    assert.equal(pools[0].endCalls, 0);
    await repository.dispose();
    assert.equal(pools[0].endCalls, 1);
});

for (const cleanupFails of [false, true]) {
    test(`failed initialization closes its pool and preserves the primary error (cleanup fails=${cleanupFails})`, async t => {
        const primary = new Error('initialization failed');
        let endCalls = 0;
        let queryCalls = 0;
        const warn = t.mock.method(console, 'warn', () => {});
        pg.Pool = class {
            async query() {
                queryCalls++;
                throw primary;
            }
            async end() {
                endCalls++;
                if (cleanupFails) throw new Error('sensitive cleanup detail');
            }
        };
        await assert.rejects(new PostgresFactory({ host: 'localhost' }).create(), error => error === primary);
        assert.equal(endCalls, 1);
        assert.equal(queryCalls, 1);
        assert.equal(warn.mock.callCount(), cleanupFails ? 1 : 0);
        if (cleanupFails) {
            assert.deepEqual(warn.mock.calls[0].arguments, [
                'Failed to close PostgreSQL pool after initialization failed.',
            ]);
        }
    });
}
