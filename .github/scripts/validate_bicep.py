import os
import re
import subprocess
import concurrent.futures
import threading

num_workers = 5

# Bicep load*() functions read files at compile time. Samples may load files
# that their scripts generate at run time and that are git-ignored, so those
# files are missing from a clean checkout. Stub them while validating.
load_function_pattern = re.compile(
    r"\b(loadTextContent|loadFileAsBase64|loadJsonContent|loadYamlContent)\(\s*'([^']+)'"
)
placeholder_contents = {
    "loadTextContent": "",
    "loadFileAsBase64": "",
    "loadJsonContent": "{}",
    "loadYamlContent": "{}",
}
repo_root = os.path.realpath(".")

# set the bicep binary name based on the OS
if os.name == 'nt':
    bicep_bin = 'bicep.exe'
    home_path = os.environ['USERPROFILE']
else:
    bicep_bin = 'bicep'
    home_path = os.environ['HOME']

# set the default Bicep path based on the runner
if os.environ.get("GITHUB_ACTIONS", "false") == "false":
    print("Running locally")
    bicep_path = os.path.join(home_path, '.rad', 'bin')
else:
    print("Running in GitHub Actions", flush=True)
    bicep_path = "."

# allow override through an environment variable
bicep_path = os.environ.get("BICEP_PATH", bicep_path)
bicep_executable = os.path.join(bicep_path, bicep_bin)

print(f"Using Bicep binary: {bicep_executable}", flush=True)

files = []
failures = []
warnings = []
restore_lock = threading.Lock()

# Walk the directory tree and find all .bicep files
for root, _, filenames in os.walk("."):
    for filename in filenames:
        if filename.endswith(".bicep"):
            files.append(os.path.join(root, filename))

def is_in_repo(path):
    try:
        return os.path.commonpath([repo_root, path]) == repo_root
    except ValueError:
        return False

def is_git_ignored(path):
    try:
        result = subprocess.run(
            ["git", "check-ignore", "--quiet", "--", path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        return False
    return result.returncode == 0

def create_placeholders(bicep_files, created_files, created_dirs):
    for f in bicep_files:
        with open(f, encoding="utf-8") as bicep_file:
            content = bicep_file.read()

        for function, relative_path in load_function_pattern.findall(content):
            path = os.path.realpath(os.path.join(os.path.dirname(f), relative_path))

            # Missing files that are not git-ignored are real errors, so let
            # Bicep report them.
            if os.path.exists(path) or not is_in_repo(path) or not is_git_ignored(path):
                continue

            missing_dirs = []
            parent = os.path.dirname(path)
            while not os.path.exists(parent):
                missing_dirs.append(parent)
                parent = os.path.dirname(parent)
            for directory in reversed(missing_dirs):
                os.mkdir(directory)
                created_dirs.append(directory)

            with open(path, "w", encoding="utf-8") as placeholder:
                placeholder.write(placeholder_contents[function])
            created_files.append(path)
            print(f"Using placeholder for git-ignored file {os.path.relpath(path)} loaded by {f}", flush=True)

def remove_placeholders(created_files, created_dirs):
    for path in created_files:
        try:
            os.remove(path)
        except OSError:
            pass

    for directory in reversed(created_dirs):
        try:
            os.rmdir(directory)
        except OSError:
            pass

def validate_file(f):
    print(f"Validating {f}...", flush=True)

    result = subprocess.run(
        [bicep_executable, "build", f, "--stdout"],
        stderr=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
    )
    stderr = result.stderr.decode("utf-8")
    exitcode = result.returncode

    if "Error BCP190" in stderr:
        print(f"Restoring external artifact for {f}...", flush=True)
        with restore_lock:
            restore_result = subprocess.run(
                [bicep_executable, "restore", f],
                stderr=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
            )

        if restore_result.returncode == 0:
            result = subprocess.run(
                [bicep_executable, "build", f, "--stdout"],
                stderr=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
            )
            stderr = result.stderr.decode("utf-8")
            exitcode = result.returncode
        else:
            stderr += restore_result.stderr.decode("utf-8")
            exitcode = restore_result.returncode
  
    if "Warning" in stderr:
        warnings.append(f)
        print(stderr, flush=True)

    if exitcode != 0 or "Error" in stderr:
        failures.append(f)
        print(stderr, flush=True)

placeholder_files = []
placeholder_dirs = []
try:
    create_placeholders(files, placeholder_files, placeholder_dirs)

    with concurrent.futures.ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = [executor.submit(validate_file, f) for f in files]
    concurrent.futures.wait(futures)
finally:
    remove_placeholders(placeholder_files, placeholder_dirs)

for f in failures:
    print(f"Failed: {f}", flush=True)

for f in warnings:
    print(f"Warning: {f}", flush=True)

exit(len(failures))
