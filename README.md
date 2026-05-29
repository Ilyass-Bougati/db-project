# Distributed Oracle Database — EShop

Academic project implementing horizontal fragmentation, stored procedures, and query optimisation across three Oracle XE instances running in Docker.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      maroc-db-net                       │
│                                                         │
│  ┌──────────────┐   DB link    ┌──────────────────────┐ │
│  │  oracle-site-1 │ ─────────▶ │   oracle-global      │ │
│  │  S1_PDB        │            │   G_PDB              │ │
│  │  port 1522     │ ◀───────── │   port 1521          │ │
│  └──────────────┘   triggers   │                      │ │
│                                │  Full EShop dataset  │ │
│  ┌──────────────┐   DB link    │  + sync triggers     │ │
│  │  oracle-site-2 │ ─────────▶ │                      │ │
│  │  S2_PDB        │            └──────────────────────┘ │
│  │  port 1523     │ ◀────────────────────────────────── │
│  └──────────────┘   triggers                            │
└─────────────────────────────────────────────────────────┘
```

| Node | Container | Port | PDB | Role |
|---|---|---|---|---|
| Global | `oracle-global` | 1521 | `G_PDB` | Full dataset, sync triggers |
| Site 1 | `oracle-site-1` | 1522 | `S1_PDB` | Fragment R1 |
| Site 2 | `oracle-site-2` | 1523 | `S2_PDB` | Fragment R2 *(disabled — see below)* |

## Fragmentation (Scenario 1)

The `LigneCommandes` table is horizontally fragmented based on product category and order quantity:

| Fragment | Site | Rule |
|---|---|---|
| R1 | Site 1 | `IDCATEG = 50  AND  QUANTITE > 100` |
| R2 | Site 2 | `IDCATEG = 35  AND  QUANTITE > 50` |

Each site holds a consistent local copy of only the rows that satisfy its rule, together with the related `PRODUITS`, `COMMANDES`, and `CLIENTS` rows.

## Running the project

```bash
docker compose up -d --build
```

Startup order is enforced: Site 1 waits for the Global DB healthcheck to pass before initialising. Initialisation scripts run automatically from the `scripts-*/` directories mounted into each container.

> **Note:** Site 2 (`oracle-site-2`) is currently commented out in `compose.yaml` and will not start. Re-enable it when you are ready to run the full three-node setup.

## Connecting to the databases

```bash
# Global DB
docker exec -it oracle-global sqlplus pdb_admin/Admin123@//localhost:1521/G_PDB

# Site 1
docker exec -it oracle-site-1 sqlplus pdb_admin/Admin123@//localhost:1522/S1_PDB

# Site 2 (when enabled)
docker exec -it oracle-site-2 sqlplus pdb_admin/Admin123@//localhost:1523/S2_PDB
```

## Hard reset

```bash
# Remove everything (containers, volumes, networks) and start fresh
./purge.sh

# Rebuild Site 1 only (faster than a full purge)
./rsite-1.sh
```

## Script inventory

### Global DB (`scripts-global/`)

| File | Purpose |
|---|---|
| `01_create_schema.sql` | Creates PDB `G_PDB`, users `s1_user` and `s2_user` |
| `02_create_table.sql` | Full EShop schema: CLIENTS, FOURNISSEURS, EMPLOYES, CATEGORIES, COMMANDES, PRODUITS, LIGNECOMMANDES |
| `03_insert_rows.sql` | Seeds all tables with initial data |
| `04_create_roles.sql` | Grants SELECT on all tables to `s1_user` and `s2_user` |
| `05_create_procedures.sql` | `insert_ligne_commande` procedure on the global LIGNECOMMANDES |
| `06_create_triggers.sql` | DB links to sites + sync triggers `SYC_INSERT_LIGNE`, `SYC_DELETE_LIGNE`, `SYC_UPDATE_LIGNE` |
| `07_query_analysis.sql` | Orders-per-client query, EXPLAIN PLAN before/after indexes, index creation |
| `08_distributed_query.sql` | Distributed revenue query via DB links (UNION ALL across both sites) |

### Site 1 (`scripts-site-1/`)

| File | Purpose |
|---|---|
| `01_create_schema.sql` | Creates PDB `S1_PDB`, users `g_user`, `s1_user`, `s2_user` |
| `02_link_table.sql` | DB link `link_to_global` + synonyms for all global tables |
| `03_create_tables.sql` | Fragment tables: LIGNECOMMANDES1, PRODUITS1, COMMANDES1, CLIENTS1 (with all PKs and FKs) |
| `04_create_procedures.sql` | `insertligne`, `deleteligne`, `updateligne` on the fragment tables |

### Site 2 (`scripts-site-2/`)

| File | Purpose |
|---|---|
| `01_create_schema.sql` | Creates PDB `S2_PDB`, users `g_user`, `s1_user` |
| `02_link_table.sql` | DB link `link_to_global` + synonyms for all global tables |
| `03_create_tables.sql` | Fragment tables: LIGNECOMMANDES2, PRODUITS2, COMMANDES2, CLIENTS2 (with all PKs and FKs) |
| `04_create_procedures.sql` | `insertligne`, `deleteligne`, `updateligne` on the fragment tables |

## Known issues

- **Site 2 disabled** — the `db-site-2` service in `compose.yaml` is commented out. Re-enable and fix its healthcheck (currently references `XEPDB1` instead of `S2_PDB`) before testing the full distributed setup.
- **Site 1 healthcheck** — also references `XEPDB1` instead of `S1_PDB`. The container still starts correctly but the healthcheck will always fail.
- **Sync trigger consistency** — the triggers use `PRAGMA AUTONOMOUS_TRANSACTION`, so a rollback on the global side will not roll back a write already committed on a site. A production system would require XA two-phase commit or Oracle Advanced Queuing.
