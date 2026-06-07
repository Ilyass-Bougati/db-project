import oracledb from 'oracledb';
import type { NodeAlias } from './types';

// Persist pool state across Next.js hot reloads in development
const g = globalThis as typeof globalThis & { _oraPools?: Set<string> };
if (!g._oraPools) g._oraPools = new Set();

const configs: Record<NodeAlias, () => { connectString: string; user: string; password: string }> = {
  global: () => ({
    connectString: process.env.GLOBAL_CONNECT_STRING!,
    user: process.env.DB_USER!,
    password: process.env.DB_PASSWORD!,
  }),
  site1: () => ({
    connectString: process.env.SITE1_CONNECT_STRING!,
    user: process.env.DB_USER!,
    password: process.env.DB_PASSWORD!,
  }),
  site2: () => ({
    connectString: process.env.SITE2_CONNECT_STRING!,
    user: process.env.DB_USER!,
    password: process.env.DB_PASSWORD!,
  }),
  backup: () => ({
    connectString: process.env.BACKUP_CONNECT_STRING!,
    user: process.env.DB_USER!,
    password: process.env.DB_PASSWORD!,
  }),
};

async function ensurePool(alias: NodeAlias) {
  if (g._oraPools!.has(alias)) return;
  try {
    await oracledb.createPool({
      poolAlias: alias,
      ...configs[alias](),
      poolMin: 0,
      poolMax: 4,
      poolIncrement: 1,
      poolTimeout: 60,
      connectTimeout: 5, // seconds — oracledb handles cleanup; avoids connection leaks
    });
    g._oraPools!.add(alias);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    // Pool already exists from a previous hot-reload cycle
    if (msg.includes('NJS-046') || msg.includes('already exists')) {
      g._oraPools!.add(alias);
    } else {
      throw err;
    }
  }
}

export async function query<T = Record<string, unknown>>(
  alias: NodeAlias,
  sql: string,
  binds: unknown[] = [],
): Promise<T[]> {
  await ensurePool(alias);
  const conn = await oracledb.getConnection(alias);
  try {
    const result = await conn.execute(sql, binds, {
      outFormat: oracledb.OUT_FORMAT_OBJECT,
    });
    return (result.rows ?? []) as T[];
  } finally {
    await conn.close();
  }
}

export async function run(
  alias: NodeAlias,
  sql: string,
  binds: unknown[] = [],
): Promise<void> {
  await ensurePool(alias);
  const conn = await oracledb.getConnection(alias);
  try {
    await conn.execute(sql, binds, { autoCommit: true });
  } finally {
    await conn.close();
  }
}

