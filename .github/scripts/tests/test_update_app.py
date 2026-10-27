"""Exercise real Git/worktrees with local remotes and offline curl/gh stand-ins."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
REAL_GIT = shutil.which("git")
FILES = ("Dockerfile", "docker-compose.yml", "docker-compose.coolify.yml", ".env.example", "README.md")
TARGETS = {"openwebui": {"Dockerfile"}, "searxng": set(FILES[1:]), "terminal": set(FILES[1:3])}
NEW_DIGEST = "sha256:" + "b" * 64

# Unknown URLs/commands fail: tests never fall back to a network service.
STUB = r'''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
args = sys.argv[1:]
kind = pathlib.Path(sys.argv[0]).name
with open(os.environ["TEST_CALLS"], "a") as stream:
    stream.write(json.dumps([kind, args]) + "\n")
data = json.loads(pathlib.Path(os.environ["TEST_DATA"]).read_text())
if kind == "git":
    args = [os.environ["TEST_REMOTE"] if arg == "https://github.com/test-owner/test-repo.git" else arg for arg in args]
    if data.get("fail_push") and "push" in args:
        sys.exit(17)
    sys.exit(subprocess.call([os.environ["TEST_GIT"], *args]))
if kind == "curl":
    url = args[-1]
    if "releases/latest" in url:
        app = "openwebui" if "/open-webui/releases/" in url else "terminal"
        print(json.dumps({"tag_name": data[app]}))
    elif url.startswith("https://ghcr.io/token?"):
        print(json.dumps({"token": data.get("registry_token", "anonymous-pull-token")}))
    elif url.startswith("https://ghcr.io/v2/open-webui/open-webui/manifests/"):
        assert "--config" in args and sys.stdin.read().startswith('header = "Authorization: Bearer ')
        print("HTTP/2 200\r\ndocker-content-digest: " + data["digest"] + "\r\n")
    elif url.startswith("https://hub.docker.com/v2/repositories/searxng/searxng/tags?"):
        print(json.dumps({"results": data["searxng"]}))
    else:
        raise SystemExit("Unexpected URL")
elif kind == "gh":
    command = args[:2]
    if command == ["repo", "view"]:
        print("main" if "defaultBranchRef" in args else "test-owner/test-repo")
    elif command == ["pr", "list"]:
        print(data.get("existing_pr", ""))
    elif command == ["issue", "list"]:
        print(json.dumps(data.get("issues", [])))
    elif command in (["pr", "create"], ["issue", "create"]):
        body = pathlib.Path(args[args.index("--body-file") + 1]).read_text()
        pathlib.Path(os.environ["TEST_BODY"]).write_text(body)
        print("https://github.com/test-owner/test-repo/pull/1")
    else:
        raise SystemExit("Unexpected gh command")
'''


class UpdaterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.repo = self.home / "repo"
        self.repo.mkdir()
        for filename in FILES:
            shutil.copy2(ROOT / filename, self.repo / filename)
        self.script = self.repo / ".github/scripts/update-app.sh"
        self.script.parent.mkdir(parents=True)
        shutil.copy2(ROOT / ".github/scripts/update-app.sh", self.script)
        (self.repo / ".gitignore").write_text(".env\nbackups/\n")
        self.env = {"PATH": os.environ["PATH"], "HOME": str(self.home), "TMPDIR": str(self.home),
                    "LANG": "C.UTF-8", "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
                    "GIT_TERMINAL_PROMPT": "0", "GH_TOKEN": "dummy-updater-token",
                    "GITHUB_REPOSITORY": "test-owner/test-repo"}
        self.git("init", "-q", "-b", "main")
        self.git("add", ".")
        self.commit("fixture")
        self.remote = self.home / "remote.git"
        self.git("init", "-q", "--bare", str(self.remote))
        self.git("push", "-q", str(self.remote), "main")
        self.base = self.git("rev-parse", "HEAD")
        self.data = {"openwebui": "v0.99.0", "terminal": "v0.99.0", "digest": NEW_DIGEST,
                     "searxng": [{"name": "2026.12.30-abcdef", "last_updated": "2026-12-30"},
                                 {"name": "2026.01.01-aaaa", "last_updated": "2026-12-31"}]}
        self.datafile = self.home / "data.json"
        self.callsfile = self.home / "calls.jsonl"
        self.bodyfile = self.home / "body.md"
        bindir = self.home / "bin"
        bindir.mkdir()
        for name in ("curl", "gh", "git"):
            target = bindir / name
            target.write_text(STUB)
            target.chmod(0o755)
        self.env.update(PATH=str(bindir) + os.pathsep + os.environ["PATH"],
                        TEST_DATA=str(self.datafile), TEST_CALLS=str(self.callsfile),
                        TEST_REMOTE=str(self.remote), TEST_GIT=REAL_GIT, TEST_BODY=str(self.bodyfile))

    def git(self, *args):
        return subprocess.check_output([REAL_GIT, *args], cwd=self.repo, env=self.env,
                                       stderr=subprocess.PIPE, text=True).strip()

    def commit(self, message):
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", message)

    def run_app(self, app, dry=False, success=True):
        self.datafile.write_text(json.dumps(self.data))
        result = subprocess.run(["bash", str(self.script), app], cwd=self.repo,
                                env={**self.env, "DRY_RUN": "1" if dry else "0"},
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.assertNotIn("dummy-updater-token", result.stdout + result.stderr)
        self.assertEqual(len(self.git("worktree", "list", "--porcelain").split("worktree ")) - 1, 1)
        return result

    def calls(self, kind=None, command=None):
        rows = [json.loads(line) for line in self.callsfile.read_text().splitlines()] if self.callsfile.exists() else []
        self.assertNotIn("dummy-updater-token", json.dumps(rows))
        return [args for name, args in rows if (not kind or name == kind) and
                (not command or command in args)]

    def snapshot(self):
        return (self.git("rev-parse", "HEAD"), self.git("status", "--porcelain"),
                self.git("diff"), self.git("diff", "--cached"),
                (self.repo / ".git/config").read_bytes(),
                {str(p.relative_to(self.repo)): p.read_bytes() for p in self.repo.rglob("*")
                 if p.is_file() and ".git" not in p.relative_to(self.repo).parts})

    def branch(self, app):
        version = {"openwebui": self.data["openwebui"], "terminal": self.data["terminal"].removeprefix("v"),
                   "searxng": self.data["searxng"][0]["name"]}[app]
        return f"auto/subir-{app}-{version}" + ("-" + self.data["digest"][7:19] if app == "openwebui" else "")

    def test_dry_run_preserves_staged_unstaged_untracked_and_private_files(self):
        with (self.repo / "README.md").open("a") as stream:
            stream.write("\nLocal staged change\n")
        self.git("add", "README.md")
        with (self.repo / "Dockerfile").open("a") as stream:
            stream.write("\n# Local unstaged change\n")
        (self.repo / "untracked.txt").write_text("local")
        (self.repo / ".env").write_text("PRIVATE_TEST_VALUE=local-dummy-value\n")
        (self.repo / "backups").mkdir()
        (self.repo / "backups/private.txt").write_text("dummy backup")
        before = self.snapshot()
        for app in TARGETS:
            with self.subTest(app=app):
                self.run_app(app, dry=True)
                self.assertEqual(before, self.snapshot())
        self.assertFalse(self.calls("git", "push"))
        self.assertFalse(self.calls("gh", "create"))

    def test_proposals_only_commit_expected_files_and_leave_caller_untouched(self):
        (self.repo / ".env").write_text("PRIVATE_TEST_VALUE=local-dummy-value\n")
        before = self.snapshot()
        for app, expected in TARGETS.items():
            with self.subTest(app=app):
                self.run_app(app)
                ref = f"refs/heads/{self.branch(app)}"
                changed = self.git("--git-dir", str(self.remote), "diff", "--name-only", self.base, ref)
                self.assertEqual(set(changed.splitlines()), expected)
                tree = self.git("--git-dir", str(self.remote), "ls-tree", "-r", "--name-only", ref)
                self.assertNotIn(".env\n", tree)
                self.assertNotIn("backups/", tree)
                if app == "searxng":
                    readme = self.git("--git-dir", str(self.remote), "show", f"{ref}:README.md")
                    self.assertIn("searxng/searxng:2026.12.30-abcdef`", readme)
                self.assertEqual(before, self.snapshot())
        self.assertTrue(self.calls("git", "push"))
        self.assertFalse(any("--force" in call or "-f" in call for call in self.calls("git", "push")))

    def test_no_downgrade(self):
        self.data.update(openwebui="v0.1.0", terminal="v0.1.0", searxng=[{"name": "2020.01.01-abc", "last_updated": "2026-12-31"}])
        for app in TARGETS:
            self.run_app(app)
        self.assertFalse(self.calls("git", "push"))
        self.assertFalse(self.calls("gh", "create"))

    def test_same_version_digest_change_is_a_proposal(self):
        self.data["openwebui"] = next(line.split("=", 1)[1] for line in (self.repo / "Dockerfile").read_text().splitlines() if line.startswith("ARG OPENWEBUI_VERSION="))
        self.run_app("openwebui")
        content = self.git("--git-dir", str(self.remote), "show", f"refs/heads/{self.branch('openwebui')}:Dockerfile")
        self.assertIn("ARG OPENWEBUI_DIGEST=" + NEW_DIGEST, content)

    def test_current_versions_and_digest_are_a_noop(self):
        self.data["openwebui"] = next(line.split("=", 1)[1] for line in (self.repo / "Dockerfile").read_text().splitlines() if line.startswith("ARG OPENWEBUI_VERSION="))
        self.data["digest"] = next(line.split("=", 1)[1] for line in (self.repo / "Dockerfile").read_text().splitlines() if line.startswith("ARG OPENWEBUI_DIGEST="))
        self.run_app("openwebui")
        self.assertFalse(self.calls("gh", "create"))
        self.assertFalse(self.calls("git", "push"))

    def test_concurrent_base_update_does_not_create_stale_proposal(self):
        for filename in FILES[1:3]:
            path = self.repo / filename
            path.write_text(path.read_text().replace("open-terminal:0.14.5", "open-terminal:0.99.0"))
        self.git("add", *FILES[1:3])
        self.commit("concurrent upstream update")
        self.git("push", "-q", str(self.remote), "main")
        self.git("reset", "--hard", self.base)
        before = self.snapshot()
        self.run_app("terminal")
        self.assertFalse(self.calls("git", "push"))
        self.assertFalse(self.calls("gh", "create"))
        self.assertEqual(before, self.snapshot())

    def test_existing_pr_is_not_recreated_even_when_closed(self):
        self.data["existing_pr"] = "https://github.com/test-owner/test-repo/pull/12"
        self.run_app("terminal")
        self.assertIn("all", self.calls("gh", "list")[0])
        self.assertFalse(self.calls("git", "push"))
        self.assertFalse(self.calls("gh", "create"))

    def test_existing_branch_without_pr_is_not_overwritten(self):
        self.git("push", "-q", str(self.remote), f"HEAD:refs/heads/{self.branch('terminal')}")
        self.run_app("terminal", success=False)
        self.assertFalse(self.calls("git", "push"))

    def test_dirty_tree_is_rejected_without_changes(self):
        (self.repo / "README.md").write_text("unrelated local edit\n")
        before = self.snapshot()
        self.run_app("terminal", success=False)
        self.assertEqual(before, self.snapshot())
        self.assertFalse(self.calls("curl"))

    def test_malformed_upstream_is_rejected_without_changes(self):
        before = self.snapshot()
        for field, value in (("openwebui", "v1.2.3\nRUN injected"), ("digest", "sha256:invalid"),
                             ("registry_token", 'bad"\nheader = "injected')):
            with self.subTest(field=field):
                old = self.data.get(field)
                self.data[field] = value
                self.run_app("openwebui", success=False)
                self.assertEqual(before, self.snapshot())
                if old is None:
                    del self.data[field]
                else:
                    self.data[field] = old

    def test_issue_mode_creates_no_branch_and_deduplicates(self):
        self.script.write_text(self.script.read_text().replace("modo_issue=0", "modo_issue=1"))
        self.git("add", ".github/scripts/update-app.sh")
        self.commit("issue mode fixture")
        self.git("push", "-q", str(self.remote), "main")
        before = self.snapshot()
        self.run_app("terminal")
        self.assertEqual(before, self.snapshot())
        title = "Actualizar Open Terminal manualmente: hay imagen nueva (0.99.0)"
        self.data["issues"] = [{"title": title, "url": "https://github.com/test-owner/test-repo/issues/1"}]
        self.run_app("terminal")
        self.assertEqual(len(self.calls("gh", "create")), 1)
        self.assertFalse(self.calls("git", "push"))

    def test_remote_base_instead_of_callers_feature_is_used(self):
        (self.repo / "unrelated-feature.txt").write_text("committed local feature")
        self.git("add", "unrelated-feature.txt")
        self.commit("unrelated feature")
        before = self.snapshot()
        self.run_app("terminal")
        ref = f"refs/heads/{self.branch('terminal')}"
        tree = self.git("--git-dir", str(self.remote), "ls-tree", "-r", "--name-only", ref)
        self.assertNotIn("unrelated-feature.txt", tree)
        self.assertEqual(before, self.snapshot())

    def test_push_failure_cleans_worktree_and_does_not_create_pr(self):
        before = self.snapshot()
        self.data["fail_push"] = True
        self.run_app("terminal", success=False)
        self.assertEqual(before, self.snapshot())
        self.assertFalse(self.calls("gh", "create"))

    def test_workflow_calls_existing_executable_script(self):
        workflow = (ROOT / ".github/workflows/update-apps.yml").read_text()
        self.assertIn('run: .github/scripts/update-app.sh "${{ matrix.app }}"', workflow)
        self.assertTrue(os.access(ROOT / ".github/scripts/update-app.sh", os.X_OK))


if __name__ == "__main__":
    unittest.main()
