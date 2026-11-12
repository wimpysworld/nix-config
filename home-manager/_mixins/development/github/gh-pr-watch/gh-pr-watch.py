import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import time


def identity(url):
    match = re.fullmatch(
        r"https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)", url
    )
    if not match or any(part in (".", "..") for part in match.groups()[:2]):
        raise ValueError("expected https://github.com/OWNER/REPO/pull/NUMBER")
    return match.groups()


def request(*args, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise ValueError("GitHub read timed out")
    try:
        result = subprocess.run(
            ["gh-api-safe", *args], capture_output=True, text=True, timeout=min(60, remaining)
        )
    except subprocess.TimeoutExpired:
        raise ValueError("GitHub read timed out") from None
    if result.returncode:
        raise ValueError(f"GitHub read failed with exit code {result.returncode}")
    try:
        value = json.loads(result.stdout)
    except (ValueError, TypeError):
        raise ValueError("GitHub returned invalid JSON") from None
    if isinstance(value, dict) and value.get("errors"):
        raise ValueError("GitHub returned GraphQL errors")
    return value


def snapshot(url, deadline=None):
    deadline = deadline or time.monotonic() + 60

    def read(*args):
        return request(*args, deadline=deadline)

    owner, repo, number = identity(url)
    root = f'repository(owner:{json.dumps(owner)},name:{json.dumps(repo)})'
    pr = f"pullRequest(number:{number})"
    core = read(
        "graphql", "-f", "query={" + root + "{" + pr + "{"
        "state headRefOid isDraft reviewDecision mergeStateStatus "
        "commits(last:1){nodes{commit{statusCheckRollup{state}}}}"
        "}}}"
    )["data"]["repository"]["pullRequest"]
    if not isinstance(core, dict) or not core.get("headRefOid") or not core.get("state"):
        raise ValueError("GitHub returned no pull request")
    thread_pages = read(
        "graphql", "--paginate", "--slurp", "-f",
        "query=query($endCursor:String){" + root + "{" + pr + "{"
        "reviewThreads(first:100,after:$endCursor){"
        "nodes{id isResolved isOutdated}pageInfo{hasNextPage endCursor}}}}}"
    )
    threads = [
        thread
        for page in thread_pages
        for thread in page["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]
    ]
    endpoint = f"repos/{owner}/{repo}/pulls/{number}"
    reviews = read(endpoint + "/reviews", "--paginate", "--slurp")
    comments = read(endpoint + "/comments", "--paginate", "--slurp")
    requests = read(endpoint + "/requested_reviewers")
    selected_reviews = [
        {key: review.get(key) for key in ("id", "body", "state", "commit_id")}
        for page in reviews for review in page
    ]
    selected_comments = [
        {key: comment.get(key) for key in (
            "id", "body", "in_reply_to_id", "commit_id", "original_commit_id",
            "path", "line", "original_line", "position", "original_position"
        )}
        for page in comments for comment in page
    ]
    data = {
        "core": core,
        "threads": sorted(threads, key=lambda item: item["id"]),
        "reviews": sorted(selected_reviews, key=lambda item: item["id"]),
        "comments": sorted(selected_comments, key=lambda item: item["id"]),
        "users": sorted(user["login"] for user in requests["users"]),
        "teams": sorted(team["id"] for team in requests["teams"]),
    }
    digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()[:16]
    return {"digest": digest, "head": core["headRefOid"], "state": core["state"]}


def write_result(directory, value):
    path = directory / "result.pending"
    with path.open("w") as output:
        json.dump(value, output, sort_keys=True)
    path.chmod(0o600)
    path.replace(directory / "result.json")


def sample(url, directory):
    result = json.loads((directory / "result.json").read_text())
    if result.get("seed"):
        result.pop("seed")
        write_result(directory, result)
        print(result["digest"], flush=True)
        return
    try:
        result = snapshot(url)
    except (ValueError, KeyError, TypeError, OSError):
        result = {"error": "GitHub snapshot failed", "digest": "ERROR"}
    write_result(directory, result)
    print(result["digest"], flush=True)


def positive(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def main():
    parser = argparse.ArgumentParser(description="Wait for a pull request change with native watch. Requires a PTY.")
    parser.add_argument("url")
    parser.add_argument("--state-dir", type=Path, required=True)
    parser.add_argument("--timeout", type=positive, default=1800)
    parser.add_argument("--interval", type=positive, default=30)
    parser.add_argument("--sample", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    os.umask(0o077)
    identity(args.url)
    directory = args.state_dir
    if args.sample:
        sample(args.url, directory)
        return 0
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise ValueError("a pseudo-terminal is required")
    if not directory.is_absolute():
        raise ValueError("state directory must be absolute")
    directory.mkdir(mode=0o700)
    if stat.S_IMODE(directory.stat().st_mode) != 0o700:
        raise ValueError("state directory must be private")
    deadline = time.monotonic() + args.timeout
    try:
        result = snapshot(args.url, deadline)
    except (ValueError, KeyError, TypeError, OSError):
        expired = time.monotonic() >= deadline
        result = {"status": "timeout" if expired else "error", "error": "Initial GitHub snapshot failed"}
        write_result(directory, result)
        print(json.dumps(result), flush=True)
        return 124 if expired else 1
    result["seed"] = True
    baseline = result["digest"]
    write_result(directory, result)
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        result["status"] = "timeout"
        write_result(directory, result)
        print(json.dumps(result))
        return 124
    command = [
        "timeout", "--kill-after=5s", f"{remaining}s", "watch", "--no-title",
        "--no-rerun", "--chgexit", "--interval", str(args.interval), "--exec",
        sys.executable, str(Path(__file__).resolve()), args.url,
        "--state-dir", str(directory), "--sample",
    ]
    process = subprocess.Popen(
        command, start_new_session=True, env={**os.environ, "TERM": "xterm"}
    )
    def interrupted(_signum, _frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    try:
        code = process.wait()
    except KeyboardInterrupt:
        code = 130
    finally:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
    result = json.loads((directory / "result.json").read_text())
    result.pop("seed", None)
    if result.get("error") or (code == 0 and result.get("digest") == baseline):
        code = 1
    result["status"] = {0: "changed", 124: "timeout", 130: "interrupted"}.get(code, "error")
    write_result(directory, result)
    print(json.dumps(result), flush=True)
    return code if code in (0, 124, 130) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, TypeError, OSError):
        print("gh-pr-watch: invalid input, private state, or GitHub snapshot", file=sys.stderr)
        sys.exit(1)
