# Nix Store Usage Guidelines

This project uses a complex Nix store setup. Depending on the context of your task (building, fixing, or running derivations), you MUST choose the appropriate Nix store and privileges. Please strictly follow the rules below when executing `nix` commands or inspecting store paths.

## 1. xmuhpc Store (Specific Users)

**Condition:** You are asked to interact with, fix, or build a derivation (`.drv`) or store path that resides in `/data/gpfs01/xxx/.nix/store`, where `xxx` is usually one of `wlin`, `jykang`, or `hwang`.

**Action:** 
- You MUST use `sudo` to call `nix`.
- You MUST append the `--store` parameter pointing to the specific user's local store configuration.

**Command Template:**
```bash
sudo nix --store 'local?store=/data/gpfs01/xxx/.nix/store&state=/data/gpfs01/xxx/.nix/state&log=/data/gpfs01/xxx/.nix/log' <command> <arguments>
```
*(Note: Replace `xxx` with the actual username found in the path, e.g., `wlin`)*

## 2. Chroot Store (`/nix/tf`)

**Condition:** You are attempting to build a derivation (without intending to run it locally), or you need to search/inspect store contents for other non-xmuhpc parts of the system. 

**Action:** 
- Do NOT look in the default `/nix/store`. Instead, look in `/nix/tf/nix/store` (the chroot store).
- When executing nix commands for these builds, you MUST use `sudo` and specify the store appropriately (e.g., `--store /nix/tf`).

**Command Template:**
```bash
sudo nix --store /nix/tf <command> <arguments>
```

## 3. Standard Local Store

**Condition:** You are building a derivation specifically to **run it on the local machine**.

**Action:**
- Use the standard default Nix store.
- Do NOT use `sudo`.
- Do NOT pass any custom `--store` arguments.

**Command Template:**
```bash
nix <command> <arguments>
```

---
**Summary Checklist before running Nix:**
1. Is this path `/data/gpfs01/...`? -> Use `sudo` + xmuhpc `--store 'local?...'`
2. Are we just building/inspecting (not running locally)? -> Use `sudo` + `--store /nix/tf`
3. Are we building to run locally right now? -> Use normal user + default store.

## 4. Packaging Preferences (`overlay/packages`)

When asked to package new software (especially Python packages), adhere to the following stylistic and architectural preferences based on existing practices in this repository:

1. **Directory Structure**: Place new package expressions (e.g., `my-package.nix`) inside `overlay/packages/`.
2. **Registration**: 
   - Standard packages should be instantiated in `overlay/packages/default.nix` using `pkgs.callPackage`.
   - **Python Packages** MUST be placed inside the `pythonOverlay = python3Packages: { ... }` block. Use `python3Packages.callPackage`.
3. **Source Management**:
   - Prefer using flake inputs (`src = self.inputs.foo;` or `self.src.foo`) if the source is managed at the flake level.
   - If fetching directly from GitHub within the `.nix` file, use `fetchFromGitHub` and provide a proper SRI base32 hash (`sha256 = "..."`).
4. **Build System**: For Python packages, use `buildPythonPackage` with `pyproject = true` and define the appropriate `build-system` (e.g., `setuptools`, `wheel`, `poetry-core`).
5. **Tests**: If the test suite requires network access, heavy external I/O, or broken transitive cloud dependencies (like AWS SDKs), it is perfectly acceptable and common to set `doCheck = false;` to bypass flaky tests.
## 5. Declarative Service Configuration Preferences

When writing NixOS service configurations (especially for Nginx, PostgreSQL, and SOPS secrets), **DO NOT** blindly use the standard NixOS options (e.g., `services.nginx.virtualHosts` or raw `services.postgresql.ensureUsers`). 

This repository has heavily abstracted and wrapped these common services into custom modules (usually under the `nixos.services.*` namespace) to unify routing, security, and internal logic.

**Action:**
- **Always Search First:** Before writing or modifying a service, `grep` or `read` other modules in `nixosConfigurations/` (e.g., `nas/wechat.nix`, `nas/home-assistant.nix`) to see how similar services are deployed.
- **Nginx Examples:** Use the custom HTTPS wrapper syntax:
  `nixos.services.nginx.https."domain.moe".location."/".proxy.upstream = "http://127.0.0.1:port";`
- **PostgreSQL Examples:** Use the instance manager:
  `nixos.services.postgresql.instances.<name>.extensions = [ ... ];`
- **SOPS Examples:** Follow the repository's established SOPS template and secret inclusion patterns rather than raw `sops.secrets`.
