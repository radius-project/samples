// Copyright 2026 The Radius Authors.
// Licensed under the Apache License, Version 2.0.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";

const workflow = readFileSync(
  new URL("../workflows/upmerge.yaml", import.meta.url),
  "utf8"
).replaceAll("\r\n", "\n");
const bash = process.env.UPMERGE_TEST_BASH || "bash";

function step(name) {
  const blocks = workflow
    .split(/^      - name: /m)
    .filter((block) => block.startsWith(`${name}\n`));
  assert.equal(blocks.length, 1, `Expected exactly one ${name} step`);
  return blocks[0];
}

// Execute the literal workflow scripts, not a separately maintained copy.
function script(name) {
  const match = step(name).match(
    /\n        run: \|\n((?:          [^\n]*\n|\n)+)/
  );
  assert.ok(match, `Missing literal run block for ${name}`);
  const result = match[1]
    .split("\n")
    .map((line) => line.slice(10))
    .join("\n");
  assert.ok(
    !result.includes("${{"),
    "Scripts must receive inputs through env"
  );
  return result;
}

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "samples-upmerge-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const cwd = join(root, "checkout");
  const remote = join(root, "origin.git");
  mkdirSync(cwd);
  const env = {
    ...process.env,
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_CONFIG_GLOBAL: join(root, "gitconfig"),
    GIT_AUTHOR_NAME: "Upmerge Fixture",
    GIT_AUTHOR_EMAIL: "fixture@example.test",
    GIT_COMMITTER_NAME: "Upmerge Fixture",
    GIT_COMMITTER_EMAIL: "fixture@example.test"
  };
  writeFileSync(env.GIT_CONFIG_GLOBAL, "");

  function git(...args) {
    const result = spawnSync("git", ["-c", "commit.gpgsign=false", ...args], {
      cwd,
      env,
      encoding: "utf8"
    });
    assert.ifError(result.error);
    assert.equal(
      result.status,
      0,
      `git ${args.join(" ")}\n${result.stdout}\n${result.stderr}`
    );
    return result.stdout.trim();
  }
  function write(path, content) {
    const target = join(cwd, path);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, content);
  }
  function commit() {
    git("add", "-A");
    git("commit", "-m", "Fixture");
    return git("rev-parse", "HEAD");
  }
  function run(name, extraEnv = {}, prefix = "") {
    const path = join(root, "step.sh");
    writeFileSync(path, `${prefix}\n${script(name)}`);
    const runEnv = {
      ...env,
      SOURCE_SHA: source,
      GITHUB_OUTPUT: join(root, "outputs").replaceAll("\\", "/"),
      ...extraEnv
    };
    for (const key of [
      "GIT_AUTHOR_NAME",
      "GIT_AUTHOR_EMAIL",
      "GIT_COMMITTER_NAME",
      "GIT_COMMITTER_EMAIL"
    ]) {
      delete runEnv[key];
    }
    const result = spawnSync(
      bash,
      ["--noprofile", "--norc", path.replaceAll("\\", "/")],
      {
        cwd,
        env: runEnv,
        encoding: "utf8"
      }
    );
    assert.ifError(result.error);
    return result;
  }
  function prepare(extraEnv, prefix) {
    return run("Upmerge samples", extraEnv, prefix);
  }
  function outputs() {
    const path = join(root, "outputs");
    return existsSync(path) ? readFileSync(path, "utf8") : "";
  }

  git("init", "--initial-branch=edge");
  git("init", "--bare", "--initial-branch=edge", remote);
  git("remote", "add", "origin", remote.replaceAll("\\", "/"));
  write("bicepconfig.json", "base configuration\n");
  write("shared.txt", "source=base\n\none\ntwo\nthree\n\nedge=base\n");
  const base = commit();
  git("checkout", "-b", "release");
  write("source.txt", "source only\n");
  write("shared.txt", "source=changed\n\none\ntwo\nthree\n\nedge=base\n");
  write("bicepconfig.json", "release configuration\n");
  let source = commit();
  git("checkout", "edge");
  write("edge.txt", "edge only\n");
  write("shared.txt", "source=base\n\none\ntwo\nthree\n\nedge=changed\n");
  write("bicepconfig.json", "edge configuration\n");
  const edge = commit();
  function publish() {
    source = git("rev-parse", "release");
    git("push", "origin", "edge", "release");
  }
  publish();
  return {
    root,
    cwd,
    git,
    write,
    commit,
    run,
    prepare,
    outputs,
    publish,
    base,
    edge
  };
}

function succeeds(result) {
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
}

function failsWithoutOutputs(f, result) {
  assert.notEqual(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assert.equal(f.outputs(), "");
}

test("squash preserves combined content without unsigned ancestry", (t) => {
  const f = fixture(t);
  const source = f.git("rev-parse", "release");
  assert.ok(!f.git("cat-file", "-p", source).includes("gpgsig "));
  succeeds(f.prepare());
  assert.equal(f.outputs(), "no-changes=false\nconflict=false\n");
  assert.equal(f.git("rev-parse", "HEAD"), f.edge);
  assert.equal(f.git("rev-parse", "release"), source);
  assert.equal(f.git("rev-list", "--count", `${f.edge}..HEAD`), "0");
  assert.equal(f.git("ls-files", "--unmerged"), "");
  assert.equal(f.git("show", ":edge.txt"), "edge only");
  assert.equal(f.git("show", ":source.txt"), "source only");
  assert.equal(
    f.git("show", ":shared.txt"),
    "source=changed\n\none\ntwo\nthree\n\nedge=changed"
  );
  assert.equal(f.git("show", ":bicepconfig.json"), "edge configuration");

  // Model the action's capture of the staged diff, without live App signing.
  f.git("commit", "-m", "Capture net diff");
  assert.equal(
    f.git("rev-list", "--parents", "-n", "1", "HEAD").split(" ").length,
    2
  );
  assert.equal(f.git("rev-parse", "HEAD^"), f.edge);
  assert.equal(f.git("rev-list", "--count", `${f.edge}..HEAD`), "1");
  assert.equal(f.git("rev-parse", "release"), source);
});

test("content conflicts become a marker-free draft snapshot", (t) => {
  const f = fixture(t);
  f.write("shared.txt", "source=conflicting edge edit\n");
  const edge = f.commit();
  f.publish();
  succeeds(f.prepare());
  assert.equal(f.outputs(), "no-changes=false\nconflict=true\n");
  assert.equal(f.git("rev-parse", "HEAD"), edge);
  assert.equal(f.git("ls-files", "--unmerged"), "");
  assert.equal(
    f.git("show", ":shared.txt"),
    f.git("show", "release:shared.txt")
  );
  assert.equal(f.git("show", ":bicepconfig.json"), "edge configuration");
  assert.doesNotMatch(f.git("diff", "--cached"), /^\+(?:<{7}|={7}|>{7})/m);
  f.git("commit", "-m", "Capture draft snapshot");
  assert.equal(f.git("rev-list", "--count", `${edge}..HEAD`), "1");
  assert.equal(f.git("rev-parse", "HEAD^"), edge);
});

test("source deletion conflicts produce a marker-free draft", (t) => {
  const f = fixture(t);
  f.git("checkout", "release");
  f.git("rm", "shared.txt");
  f.commit();
  f.git("checkout", "edge");
  f.publish();
  succeeds(f.prepare());
  assert.equal(f.outputs(), "no-changes=false\nconflict=true\n");
  assert.equal(f.git("ls-files", "--unmerged"), "");
  assert.equal(f.git("ls-files", "--", "shared.txt"), "");
  assert.equal(f.git("rev-parse", "HEAD"), f.edge);
});

test("an already-ancestor source is a real no-op", (t) => {
  const f = fixture(t);
  succeeds(f.prepare({ SOURCE_SHA: f.base }));
  assert.equal(f.outputs(), "no-changes=true\nconflict=false\n");
  assert.equal(f.git("status", "--porcelain"), "");
  assert.equal(f.git("rev-parse", "HEAD"), f.edge);
});

test("identical source and edge are a no-op", (t) => {
  const f = fixture(t);
  succeeds(f.prepare({ SOURCE_SHA: f.edge }));
  assert.equal(f.outputs(), "no-changes=true\nconflict=false\n");
  assert.equal(f.git("status", "--porcelain"), "");
});

test("edge config deletion survives clean and conflicting upmerges", async (t) => {
  for (const conflict of [false, true]) {
    await t.test(`conflict=${conflict}`, (t) => {
      const f = fixture(t);
      f.git("rm", "bicepconfig.json");
      if (conflict) f.write("shared.txt", "conflicting edge content\n");
      const edge = f.commit();
      f.publish();
      succeeds(f.prepare());
      assert.equal(f.outputs(), `no-changes=false\nconflict=${conflict}\n`);
      assert.equal(f.git("ls-files", "--", "bicepconfig.json"), "");
      assert.ok(!existsSync(join(f.cwd, "bicepconfig.json")));
      assert.equal(f.git("rev-parse", "HEAD"), edge);
    });
  }
});

test("config absence on both sides is preserved", (t) => {
  const f = fixture(t);
  f.git("rm", "bicepconfig.json");
  f.commit();
  f.git("checkout", "release");
  f.git("rm", "bicepconfig.json");
  f.commit();
  f.git("checkout", "edge");
  f.publish();
  succeeds(f.prepare());
  assert.equal(f.outputs(), "no-changes=false\nconflict=false\n");
  assert.equal(f.git("ls-files", "--", "bicepconfig.json"), "");
});

test("a source config deletion cannot delete edge's config", (t) => {
  const f = fixture(t);
  f.git("checkout", "release");
  f.git("rm", "bicepconfig.json");
  f.commit();
  f.git("checkout", "edge");
  f.publish();
  succeeds(f.prepare());
  assert.equal(f.outputs(), "no-changes=false\nconflict=false\n");
  assert.equal(f.git("show", ":bicepconfig.json"), "edge configuration");
});

test("only edge-owned config changes are a no-op", (t) => {
  const f = fixture(t);
  f.git("checkout", "-b", "config-only", f.base);
  f.write("bicepconfig.json", "another release configuration\n");
  const source = f.commit();
  f.git("push", "origin", "config-only");
  f.git("checkout", "edge");
  succeeds(f.prepare({ SOURCE_SHA: source }));
  assert.equal(f.outputs(), "no-changes=true\nconflict=false\n");
  assert.equal(f.git("status", "--porcelain"), "");
});

test("fetch failures are not draft conflicts or no-ops", (t) => {
  const f = fixture(t);
  f.git("remote", "set-url", "origin", join(f.root, "missing-origin"));
  failsWithoutOutputs(f, f.prepare({ SOURCE_SHA: "0".repeat(40) }));
  assert.equal(f.git("rev-parse", "HEAD"), f.edge);
});

test("dirty checkouts and invalid source IDs fail before merge", async (t) => {
  for (const dirty of [false, true]) {
    await t.test(`dirty=${dirty}`, (t) => {
      const f = fixture(t);
      if (dirty) f.write("unexpected.txt", "do not touch\n");
      failsWithoutOutputs(
        f,
        f.prepare(dirty ? {} : { SOURCE_SHA: "--bad-ref" })
      );
    });
  }
});

test("Git errors without conflicts must not produce a draft", async (t) => {
  for (const status of [1, 128]) {
    await t.test(`merge exit=${status}`, (t) => {
      const f = fixture(t);
      failsWithoutOutputs(
        f,
        f.prepare(
          {},
          `git() {
  if [[ "$1" == "merge" ]]; then return ${status}; fi
  command git "$@"
}`
        )
      );
      assert.equal(f.git("status", "--porcelain"), "");
    });
  }
});

test("index inspection and diff failures propagate", async (t) => {
  for (const command of ["ls-files", "diff"]) {
    await t.test(command, (t) => {
      const f = fixture(t);
      failsWithoutOutputs(
        f,
        f.prepare(
          {},
          `git() {
  if [[ "$1" == "${command}" ]]; then return 128; fi
  command git "$@"
}`
        )
      );
    });
  }
});

test("output I/O failures fail the step", (t) => {
  const f = fixture(t);
  failsWithoutOutputs(
    f,
    f.prepare({ GITHUB_OUTPUT: f.root.replaceAll("\\", "/") })
  );
});

test("workflow delegates signing and PR lifecycle to the pinned action", () => {
  const token = step("Get App Token");
  assert.match(token, /permission-contents: write/);
  assert.match(token, /permission-pull-requests: write/);
  assert.match(token, /permission-workflows: write/);
  assert.match(token, /repositories: samples/);
  assert.match(step("Checkout edge"), /ref: edge/);
  assert.match(step("Checkout edge"), /fetch-depth: 0/);
  assert.match(step("Upmerge samples"), /SOURCE_SHA: \$\{\{ github\.sha \}\}/);
  assert.doesNotMatch(
    script("Upmerge samples"),
    /\bgit (?:commit|push|reset)\b/
  );

  const create = step("Create pull request");
  assert.match(create, /if: steps\.prepare\.outputs\.no-changes != 'true'/);
  assert.match(
    create,
    /uses: peter-evans\/create-pull-request@5f6978faf089d4d20b00c7766989d076bb2fc7f1 # v8\.1\.1/
  );
  assert.match(create, /token: \$\{\{ steps\.app-token\.outputs\.token \}\}/);
  assert.match(create, /sign-commits: true/);
  assert.doesNotMatch(create, /^\s+(?:author|committer|branch-token):/m);
  assert.match(
    create,
    /Signed-off-by: \$\{\{ steps\.bot-details\.outputs\.name \}\} <\$\{\{ steps\.bot-details\.outputs\.email \}\}>/
  );
  assert.match(
    create,
    /branch: upmerge\/\$\{\{ github\.run_id \}\}-\$\{\{ github\.run_attempt \}\}/
  );
  assert.match(create, /base: edge/);
  assert.match(create, /draft: \$\{\{ steps\.prepare\.outputs\.conflict \}\}/);
  assert.match(create, /provisional source snapshot, not a resolved merge/);
  assert.match(create, /edge-only changes may be absent/);
  const guard = step("Require signed pull request");
  assert.match(guard, /if: steps\.prepare\.outputs\.no-changes != 'true'/);
  assert.match(
    guard,
    /COMMITS_VERIFIED: \$\{\{ steps\.pull-request\.outputs\.pull-request-commits-verified \}\}/
  );
  for (const [variable, output] of [
    ["PR_NUMBER", "pull-request-number"],
    ["PR_URL", "pull-request-url"],
    ["PR_HEAD_SHA", "pull-request-head-sha"]
  ]) {
    assert.ok(
      guard.includes(
        `${variable}: \${{ steps.pull-request.outputs.${output} }}`
      )
    );
  }
  assert.match(
    workflow,
    /needs: test\n    if: github\.event_name == 'workflow_dispatch'/
  );
});

test("the output guard rejects unsigned or missing action outputs", async (t) => {
  const good = {
    COMMITS_VERIFIED: "true",
    PR_NUMBER: "123",
    PR_URL: "https://github.com/radius-project/samples/pull/123",
    PR_HEAD_SHA: "a".repeat(40)
  };
  const f = fixture(t);
  succeeds(f.run("Require signed pull request", good));
  for (const name of Object.keys(good)) {
    await t.test(`missing ${name}`, () => {
      assert.notEqual(
        f.run("Require signed pull request", { ...good, [name]: "" }).status,
        0
      );
    });
  }
  assert.notEqual(
    f.run("Require signed pull request", {
      ...good,
      COMMITS_VERIFIED: "false"
    }).status,
    0
  );
});
