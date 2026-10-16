const assert = require("node:assert/strict");
const { randomBytes } = require("node:crypto");
const { Pool } = require("pg");

async function main() {
  const env = process.env;
  assert.equal(env.PGSSLMODE, "disable");
  for (const key of ["HOST", "PORT", "USERNAME", "DATABASE"]) {
    assert(env[`CONNECTION_POSTGRESQL_${key}`], `Missing PostgreSQL ${key}`);
  }
  assert(env.CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD, "Missing authored Secret password projection");
  const password = env.CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD;
  assert(/^[a-f0-9]{64}$/.test(password), "Expected generated URI-safe demo password");
  // Exactly the demo's URI and Pool configuration; no explicit ssl override.
  const connectionString = `postgresql://${env.CONNECTION_POSTGRESQL_USERNAME}:${password}@${env.CONNECTION_POSTGRESQL_HOST}:${env.CONNECTION_POSTGRESQL_PORT}/${env.CONNECTION_POSTGRESQL_DATABASE}`;
  const pool = new Pool({ connectionString, connectionTimeoutMillis: 5000, query_timeout: 5000 });
  let id;
  async function request(method, path, body, status = 200) {
    const response = await fetch(`http://127.0.0.1:3000/api/todos${path}`, {
      method,
      headers: { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(10_000),
    });
    assert.equal(response.status, status, `HTTP ${method} ${path}`);
    return status === 204 ? undefined : response.json();
  }
  async function mustReject(options, check, reason) {
    const attempt = new Pool({ connectionString, connectionTimeoutMillis: 5000, ...options });
    try {
      await assert.rejects(attempt.query("SELECT 1"), check, reason);
    } finally {
      await attempt.end();
    }
  }
  try {
    const client = await pool.connect();
    try {
      assert.equal((await client.query("SHOW ssl")).rows[0].ssl, "off");
      const transport = await client.query("SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()");
      assert.equal(transport.rowCount, 1);
      assert.equal(transport.rows[0].ssl, false, "Same-configuration Node connection must use plaintext");
    } finally {
      client.release();
    }
    await mustReject({ connectionString: connectionString.replace(`:${password}@`, `:${randomBytes(32).toString("hex")}@`) },
      (error) => error.code === "28P01", "Wrong password must fail with invalid_password, not a network failure");
    // ssl=true is used only for this negative test; pg still verifies certificates by default.
    await mustReject({ ssl: true },
      (error) => error.message === "The server does not support SSL connections",
      "Forced TLS must fail because PostgreSQL has SSL disabled");

    const title = `persisted-${randomBytes(12).toString("hex")}`;
    const created = await request("POST", "", { title, done: false });
    id = created.id;
    assert.match(id, /^[a-f0-9-]{36}$/i);
    assert.equal((await request("GET", `/${id}`)).title, title);
    const listed = await request("GET", "");
    assert.equal(listed.message, null, "In-memory fallback is not acceptance");
    assert(listed.items.some((item) => item.id === id));
    const persisted = await pool.query("SELECT title, done FROM items WHERE id = $1", [id]);
    assert.deepEqual(persisted.rows, [{ title, done: false }]);
    await request("PUT", `/${id}`, { title, done: true });
    assert.equal((await pool.query("SELECT done FROM items WHERE id = $1", [id])).rows[0].done, true);
    await request("DELETE", `/${id}`, undefined, 204);
    assert.equal((await pool.query("SELECT id FROM items WHERE id = $1", [id])).rowCount, 0);
    id = undefined;
    console.log("PASS: ssl=off, same-config Node pg_stat_ssl=false, password enforced, expected forced-TLS rejection, persisted HTTP CRUD");
  } finally {
    try {
      if (id) await request("DELETE", `/${id}`, undefined, 204);
    } finally {
      await pool.end();
    }
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
