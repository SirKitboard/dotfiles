# Sync

Syncthing manages `~/Sync/` across devices over Tailscale. No cloud middleman —
files sync P2P directly between machines.

## Directory structure

```
~/Sync/
├── secrets/        # .env files, API keys, tokens
├── saves/          # game save directories
└── link-saves.sh   # private script — creates symlinks from game dirs into saves/
```

`link-saves.sh` lives in `~/Sync/` (not in this repo) so game names and paths
stay private. It syncs automatically to any device you add to Syncthing.

## Setting up symlinks

Once Syncthing has connected and `~/Sync` has synced:

```bash
bash ~/Sync/link-saves.sh
```

`install.sh` calls this automatically if the file exists, otherwise prints a
reminder to run it after Syncthing connects.

## Secrets

Drop `.env` files into `~/Sync/secrets/`. Then symlink into projects:

```bash
ln -sf ~/Sync/secrets/.env.myproject ~/Projects/myproject/.env
```

## File versioning

Enable **Staggered versioning** on the `~/Sync` folder in the Syncthing UI:
- Folder → Edit → File Versioning → Staggered
- Keeps hourly snapshots for 1 day, daily for 1 month, weekly beyond that
- Old versions stored in `~/Sync/.stversions/`

## Syncthing setup on a new device

1. Install: `brew install --cask syncthing-app`
2. Open the app — web UI at **http://localhost:8384**
3. Add remote device using the existing machine's Device ID (Actions → Show ID)
4. Accept the connection on the existing machine
5. Share the `~/Sync` folder, set path to `~/Sync`
6. Once synced, run `bash ~/Sync/link-saves.sh`
