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