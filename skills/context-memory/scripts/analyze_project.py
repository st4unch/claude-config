#!/usr/bin/env python3
"""
analyze_project.py

Proje kökünü tarar ve Claude'un memory kategorilerini belirlemesine
yardımcı olacak yapısal ipuçlarını JSON olarak döner. Kategorileri bu script
BELİRLEMEZ — Claude bu JSON'a bakıp kendisi karar verir (proje özgü mantık
gerektirdiği için). Bu script sadece objektif sinyalleri toplar:
  * Üst düzey klasörler ve boyutları
  * Manifest dosyaları (package.json, requirements.txt, go.mod, ...)
  * Framework/tool ipuçları (Dockerfile, .github/workflows, migrations/, ...)
  * README'nin ilk birkaç yüz satırı
  * Gözden kaçmayan dosya sayımları (dil bazında)

Kullanım:
    python3 analyze_project.py [<project_root>]

project_root verilmezse cwd kullanılır.
"""

import json
import os
import sys
from collections import Counter
from pathlib import Path

# Göz ardı edilecek yollar (tarama sırasında)
IGNORE_DIRS = {
    ".git", "node_modules", ".next", ".nuxt", "dist", "build", "out",
    ".venv", "venv", "env", "__pycache__", ".pytest_cache", ".tox",
    ".mypy_cache", ".ruff_cache", "target", "vendor", ".gradle",
    ".idea", ".vscode", ".DS_Store", "coverage", ".nyc_output",
    ".cache", ".parcel-cache", ".turbo", ".svelte-kit",
}

# Dosya adından dilin tespiti
EXT_TO_LANG = {
    ".py": "Python", ".js": "JavaScript", ".jsx": "JavaScript",
    ".ts": "TypeScript", ".tsx": "TypeScript", ".go": "Go",
    ".rs": "Rust", ".java": "Java", ".kt": "Kotlin",
    ".rb": "Ruby", ".php": "PHP", ".cs": "C#",
    ".c": "C", ".cpp": "C++", ".h": "C/C++",
    ".swift": "Swift", ".m": "Objective-C",
    ".vue": "Vue", ".svelte": "Svelte",
    ".sql": "SQL", ".graphql": "GraphQL", ".gql": "GraphQL",
    ".proto": "Protobuf", ".sh": "Shell", ".yaml": "YAML", ".yml": "YAML",
    ".tf": "Terraform", ".hcl": "HCL", ".dockerfile": "Dockerfile",
}

# Manifest dosyaları ve ne belirttikleri
MANIFESTS = {
    "package.json": "Node.js/JS/TS",
    "pnpm-workspace.yaml": "pnpm monorepo",
    "lerna.json": "Lerna monorepo",
    "turbo.json": "Turborepo",
    "nx.json": "Nx monorepo",
    "requirements.txt": "Python (pip)",
    "pyproject.toml": "Python (PEP 621)",
    "Pipfile": "Python (pipenv)",
    "poetry.lock": "Python (poetry)",
    "go.mod": "Go module",
    "Cargo.toml": "Rust crate",
    "pom.xml": "Java/Maven",
    "build.gradle": "Gradle",
    "build.gradle.kts": "Gradle (Kotlin DSL)",
    "Gemfile": "Ruby",
    "composer.json": "PHP",
    "mix.exs": "Elixir",
    "deno.json": "Deno",
    "bun.lockb": "Bun",
}

# Sinyal ipuçları: varlık → ne anlama geliyor
SIGNAL_FILES = {
    "Dockerfile": "containerization",
    "docker-compose.yml": "local multi-service stack",
    "docker-compose.yaml": "local multi-service stack",
    "Makefile": "make-based task runner",
    ".dockerignore": "containerization",
    "kubernetes": "kubernetes",  # klasör
    "k8s": "kubernetes",          # klasör
    "helm": "helm charts",        # klasör
    "terraform": "terraform IaC", # klasör
    "migrations": "DB migrations",# klasör
    "prisma": "Prisma ORM",       # klasör
    "schema.prisma": "Prisma ORM",
    ".github/workflows": "GitHub Actions CI",
    ".gitlab-ci.yml": "GitLab CI",
    "Jenkinsfile": "Jenkins CI",
    ".circleci": "CircleCI",
    "tsconfig.json": "TypeScript",
    "tailwind.config.js": "Tailwind CSS",
    "tailwind.config.ts": "Tailwind CSS",
    "next.config.js": "Next.js",
    "next.config.ts": "Next.js",
    "nuxt.config.ts": "Nuxt",
    "vite.config.js": "Vite",
    "vite.config.ts": "Vite",
    "svelte.config.js": "Svelte",
    "astro.config.mjs": "Astro",
    "remix.config.js": "Remix",
    "angular.json": "Angular",
    "vue.config.js": "Vue CLI",
    "webpack.config.js": "Webpack",
    "jest.config.js": "Jest",
    "vitest.config.ts": "Vitest",
    "playwright.config.ts": "Playwright E2E",
    "cypress.config.js": "Cypress E2E",
    "manage.py": "Django",
    "alembic.ini": "Alembic (SQLAlchemy migrations)",
    "hardhat.config.js": "Hardhat (Solidity)",
    "foundry.toml": "Foundry (Solidity)",
    "supabase": "Supabase",
    "firebase.json": "Firebase",
    "vercel.json": "Vercel deploy",
    "netlify.toml": "Netlify deploy",
    "fly.toml": "Fly.io deploy",
    "railway.json": "Railway deploy",
    "serverless.yml": "Serverless Framework",
    "sst.config.ts": "SST",
    "amplify.yml": "AWS Amplify",
}

# Üst düzey klasör isimlerinin "anlamı" — Claude'un kategori kararına ipucu
DIR_HINTS = {
    "frontend": "frontend", "client": "frontend", "web": "frontend",
    "webapp": "frontend", "ui": "frontend", "app": "frontend-or-full",
    "apps": "monorepo-apps",
    "backend": "backend", "server": "backend", "api": "api/backend",
    "services": "backend-services", "service": "backend-service",
    "db": "database", "database": "database", "migrations": "db-migrations",
    "schema": "db-schema", "models": "data-models", "prisma": "prisma-orm",
    "tests": "tests", "test": "tests", "__tests__": "tests",
    "e2e": "e2e-tests", "integration": "integration-tests",
    "infra": "infrastructure", "infrastructure": "infrastructure",
    "deploy": "deployment", "deployment": "deployment",
    "terraform": "terraform", "k8s": "kubernetes", "kubernetes": "kubernetes",
    "helm": "helm", "ansible": "ansible",
    "packages": "monorepo-packages", "libs": "shared-libs",
    "shared": "shared-code", "common": "shared-code", "core": "core-domain",
    "components": "ui-components", "pages": "pages/routes",
    "routes": "pages/routes", "views": "pages/views",
    "public": "static-assets", "static": "static-assets",
    "assets": "static-assets", "docs": "documentation",
    "scripts": "utility-scripts", "tools": "utility-scripts",
    "config": "configuration", "configs": "configuration",
    "auth": "authentication", "middleware": "middleware",
    "hooks": "react-hooks-or-git-hooks", "utils": "utilities",
    "lib": "libraries", "src": "source-root",
    "cmd": "go-entrypoints", "internal": "go-internal",
    "pkg": "go-packages",
    "contracts": "smart-contracts", "chaincode": "smart-contracts",
}


def should_ignore(path: Path) -> bool:
    return path.name in IGNORE_DIRS or path.name.startswith(".") and path.name not in {
        ".github", ".gitlab-ci.yml", ".circleci"
    }


def scan_top_level(root: Path) -> list:
    """Üst düzey klasörleri ve her birinin kabaca dosya sayısını döner."""
    out = []
    try:
        for child in sorted(root.iterdir()):
            if not child.is_dir():
                continue
            if should_ignore(child):
                continue
            # Alt dosya sayısını kabaca hesapla (rekürsif)
            file_count = 0
            sample_files = []
            for p in child.rglob("*"):
                if any(part in IGNORE_DIRS for part in p.parts):
                    continue
                if p.is_file():
                    file_count += 1
                    if len(sample_files) < 5:
                        try:
                            sample_files.append(str(p.relative_to(root)))
                        except ValueError:
                            sample_files.append(p.name)
                    if file_count > 5000:  # çok büyük klasörlerde dur
                        break

            hint = DIR_HINTS.get(child.name.lower(), None)
            out.append({
                "path": child.name,
                "file_count": file_count,
                "hint": hint,
                "sample_files": sample_files,
            })
    except PermissionError:
        pass
    return out


def scan_manifests(root: Path) -> list:
    """Projede bulunan paket manifest dosyalarını döner."""
    found = []
    # Sadece 2 seviyeye kadar in — monorepo için yeterli
    for depth in [0, 1, 2]:
        pattern = "/".join(["*"] * depth) if depth > 0 else ""
        for name, meaning in MANIFESTS.items():
            if depth == 0:
                paths = [root / name]
            else:
                paths = list(root.glob(f"{pattern}/{name}")) if pattern else []
            for p in paths:
                if not p.exists() or not p.is_file():
                    continue
                if any(part in IGNORE_DIRS for part in p.parts):
                    continue
                try:
                    rel = str(p.relative_to(root))
                except ValueError:
                    continue
                found.append({"path": rel, "type": meaning})
    # Deduplicate
    seen = set()
    unique = []
    for item in found:
        if item["path"] not in seen:
            seen.add(item["path"])
            unique.append(item)
    return unique


def scan_signal_files(root: Path) -> list:
    """Framework/tool ipucu veren dosya ve klasörler."""
    found = []
    for name, meaning in SIGNAL_FILES.items():
        # "/" içeren patternler glob ile aranır
        if "/" in name:
            candidates = list(root.glob(name))
        else:
            # Hem kökte hem 1 seviye altta
            candidates = [root / name]
            candidates.extend(root.glob(f"*/{name}"))
        for p in candidates:
            if not p.exists():
                continue
            if any(part in IGNORE_DIRS for part in p.parts):
                continue
            try:
                rel = str(p.relative_to(root))
            except ValueError:
                rel = p.name
            found.append({"path": rel, "meaning": meaning})
    # Dedup
    seen = set()
    out = []
    for item in found:
        k = item["path"]
        if k not in seen:
            seen.add(k)
            out.append(item)
    return out


def language_breakdown(root: Path, max_files: int = 20000) -> list:
    """Projedeki dilleri kaba dosya sayısıyla döner."""
    counter: Counter = Counter()
    count = 0
    for p in root.rglob("*"):
        if count >= max_files:
            break
        if any(part in IGNORE_DIRS for part in p.parts):
            continue
        if not p.is_file():
            continue
        ext = p.suffix.lower()
        lang = EXT_TO_LANG.get(ext)
        if lang:
            counter[lang] += 1
            count += 1
    return [{"language": lang, "files": n}
            for lang, n in counter.most_common(15)]


def read_readme(root: Path, max_chars: int = 4000) -> str:
    for name in ["README.md", "README.rst", "README.txt", "README"]:
        p = root / name
        if p.exists() and p.is_file():
            try:
                return p.read_text(encoding="utf-8", errors="replace")[:max_chars]
            except Exception:
                continue
    return ""


def existing_memories(root: Path) -> dict:
    mem_dir = root / ".claude" / "memories"
    if not mem_dir.exists():
        return {"exists": False, "files": []}
    files = []
    for p in sorted(mem_dir.rglob("*.md")):
        try:
            rel = str(p.relative_to(root))
            mtime = int(p.stat().st_mtime)
            files.append({"path": rel, "mtime": mtime, "size": p.stat().st_size})
        except Exception:
            continue
    return {"exists": True, "files": files}


def analyze(root_arg: str | None) -> dict:
    root = Path(root_arg).resolve() if root_arg else Path.cwd().resolve()
    if not root.exists() or not root.is_dir():
        return {"error": f"not a directory: {root}"}

    return {
        "root": str(root),
        "top_level_dirs": scan_top_level(root),
        "manifests": scan_manifests(root),
        "signals": scan_signal_files(root),
        "languages": language_breakdown(root),
        "readme_head": read_readme(root),
        "existing_memories": existing_memories(root),
    }


def main() -> int:
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    result = analyze(arg)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
