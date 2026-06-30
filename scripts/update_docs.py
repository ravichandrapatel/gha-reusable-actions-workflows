import os
import shutil
import subprocess  # nosec
import re
import shlex

# Configuration for documentation sources
# ... (rest of the config)
DOCS_CONFIG = {
    "github-actions": {
        "repo": "https://github.com/github/docs.git",
        "sparse_path": "content/actions",
        "source_subpath": "content/actions",
        "target_dir": "rulebooks/github-actions",
        "tool_name": "github-actions",
        "cleanup_patterns": ["01-introduction.md", "02-writing-components.md", "03-dev-hooks.md", "04-local-testing.md", "05-release-checklist.md", "06-inline-policy-skips.md"]
    },
    "terraform-core": {
        "repo": "https://github.com/hashicorp/web-unified-docs.git",
        "sparse_path": "content/terraform",
        "source_subpath": "content/terraform/v1.15.x/docs", # Note: Update version as needed
        "target_dir": "rulebooks/terraform",
        "tool_name": "terraform",
        "subdirs": ["cli", "intro", "language"]
    },
    "terraform-provider-aws": {
        "repo": "https://github.com/hashicorp/terraform-provider-aws.git",
        "sparse_path": "website/docs",
        "source_subpath": "website/docs",
        "target_dir": "rulebooks/terraform/aws",
        "tool_name": "terraform-aws"
    },
    "terraform-provider-azure": {
        "repo": "https://github.com/hashicorp/terraform-provider-azurerm.git",
        "sparse_path": "website/docs",
        "source_subpath": "website/docs",
        "target_dir": "rulebooks/terraform/azure",
        "tool_name": "terraform-azurerm"
    },
    "terraform-provider-gcp": {
        "repo": "https://github.com/hashicorp/terraform-provider-google.git",
        "sparse_path": "website/docs",
        "source_subpath": "website/docs",
        "target_dir": "rulebooks/terraform/gcp",
        "tool_name": "terraform-google"
    },
    "terraform-provider-kubernetes": {
        "repo": "https://github.com/hashicorp/terraform-provider-kubernetes.git",
        "sparse_path": "docs",
        "source_subpath": "docs",
        "target_dir": "rulebooks/terraform/kubernetes",
        "tool_name": "terraform-kubernetes"
    },
    "kubernetes-core": {
        "repo": "https://github.com/kubernetes/website.git",
        "sparse_path": "content/en/docs",
        "source_subpath": "content/en/docs",
        "target_dir": "rulebooks/kubernetes",
        "tool_name": "kubernetes",
        "subdirs": ["concepts", "setup", "tasks", "tutorials", "reference"]
    },
    "owasp-spvs": {
        "repo": "https://github.com/OWASP/www-project-spvs.git",
        "sparse_path": "1.5",
        "source_subpath": "1.5",
        "target_dir": "rulebooks/owasp-spvs",
        "tool_name": "owasp-spvs"
    }
}

def run_command(command, cwd=None):
    print(f"Running: {command}")
    # Split the command string into a list for subprocess.run with shell=False
    cmd_list = shlex.split(command)
    result = subprocess.run(cmd_list, shell=False, cwd=cwd, capture_output=True, text=True)  # nosec
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
    return result.returncode == 0

def add_okf_frontmatter(filepath, tool_name):
    okf_frontmatter = f"""---
type: official_reference
tool: {tool_name}
authority: external_reference
---

"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Remove existing frontmatter if it exists
        if content.startswith('---'):
            match = re.search(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
            if match:
                content = content[match.end():]
        
        new_content = okf_frontmatter + content
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
    except Exception as e:
        print(f"Failed to process {filepath}: {e}")

def process_docs():
    temp_dir = "temp_docs_clone"
    
    for name, config in DOCS_CONFIG.items():
        print(f"--- Processing {name} ---")
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
            
        # Clone repo with sparse checkout
        clone_cmd = f"git clone --depth 1 --filter=blob:none --sparse {config['repo']} {temp_dir}"
        if not run_command(clone_cmd):
            continue
            
        sparse_cmd = f"git sparse-checkout set {config['sparse_path']}"
        if not run_command(sparse_cmd, cwd=temp_dir):
            continue
            
        # Prepare target directory
        os.makedirs(config['target_dir'], exist_ok=True)
        
        # Copy files
        source_base = os.path.join(temp_dir, config['source_subpath'])
        
        if "subdirs" in config:
            for subdir in config["subdirs"]:
                src = os.path.join(source_base, subdir)
                dst = os.path.join(config['target_dir'], subdir)
                if os.path.exists(src):
                    if os.path.exists(dst):
                        shutil.rmtree(dst)
                    shutil.copytree(src, dst)
        else:
            # Copy all files from source_subpath to target_dir
            for item in os.listdir(source_base):
                s = os.path.join(source_base, item)
                d = os.path.join(config['target_dir'], item)
                if os.path.isdir(s):
                    if os.path.exists(d):
                        shutil.rmtree(d)
                    shutil.copytree(s, d)
                else:
                    shutil.copy2(s, d)
                    
        # Cleanup specific files if needed
        if "cleanup_patterns" in config:
            for pattern in config["cleanup_patterns"]:
                p = os.path.join(config['target_dir'], pattern)
                if os.path.exists(p):
                    os.remove(p)
                    
        # Convert to OKF format
        for root, _, files in os.walk(config['target_dir']):
            for filename in files:
                if filename.endswith(('.md', '.mdx', '.markdown')) and filename != '_router.md':
                    add_okf_frontmatter(os.path.join(root, filename), config['tool_name'])
                    
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    process_docs()
