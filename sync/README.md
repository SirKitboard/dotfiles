# Sync

Syncthing manages `~/Sync/` across devices over Tailscale. No cloud middleman —
files sync P2P directly between machines.

## Directory structure

```
~/Sync/
├── secrets/        # .env files, API keys, tokens
└── saves/
    └── pokemon-infinite-fusion/   # symlinked from Wine AppData
```

## Symlink map

| Syncthing path | Symlinked from | Notes |
|----------------|---------------|-------|
| `~/Sync/saves/pokemon-infinite-fusion/` | `~/.wine/drive_c/users/$USER/AppData/Roaming/infinitefusion/` | Set up automatically by install.sh |

## Secrets

Drop `.env` files into `~/Sync/secrets/`. Then symlink them into projects:

```bash
ln -sf ~/Sync/secrets/.env.myproject ~/Projects/myproject/.env
```

## Setup on a new machine

`install.sh` handles the symlinks automatically. After running it:

1. Open Syncthing at **http://localhost:8384**
2. On the existing machine, go to **Add Remote Device** and paste the new machine's Device ID
3. Accept the connection request on the new machine
4. Share the `~/Sync` folder with the new device

Both machines need to be reachable — either on the same network or connected via Tailscale.

## Syncthing tips

- **Conflict files**: if the same file is edited on both machines while offline, Syncthing creates a `.sync-conflict` file — keep the one you want and delete the other
- **Ignore patterns**: add a `.stignore` file inside `~/Sync/` to exclude files (e.g. `*.tmp`)
- **Status**: run `brew services info syncthing` to check the daemon is running
