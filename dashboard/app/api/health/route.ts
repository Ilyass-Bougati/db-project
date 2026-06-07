export const runtime = 'nodejs';

import { query } from '@/lib/oracle';
import type { HealthResponse, TriggerRow, BackupStats } from '@/lib/types';

async function checkNode(alias: 'global' | 'site1' | 'site2' | 'backup') {
  try {
    await query(alias, 'SELECT 1 AS OK FROM DUAL');
    return true;
  } catch {
    return false;
  }
}

async function getBackupStats(): Promise<BackupStats> {
  const [syncRows, countRows] = await Promise.all([
    query<{ LAST_SYNC: string | null }>(
      'backup',
      `SELECT TO_CHAR(LAST_START_DATE, 'YYYY-MM-DD HH24:MI:SS') AS LAST_SYNC
       FROM   USER_SCHEDULER_JOBS
       WHERE  JOB_NAME = 'BACKUP_SYNC_JOB'`,
    ),
    query<{ TOTAL: number }>(
      'backup',
      'SELECT COUNT(*) AS TOTAL FROM LIGNECOMMANDES',
    ),
  ]);

  return {
    lastSync: syncRows[0]?.LAST_SYNC ?? null,
    rowCount: countRows[0]?.TOTAL ?? 0,
  };
}

export async function GET() {
  const [globalOk, site1Ok, site2Ok, backupOk] = await Promise.all([
    checkNode('global'),
    checkNode('site1'),
    checkNode('site2'),
    checkNode('backup'),
  ]);

  const [triggers, backupStats] = await Promise.all([
    globalOk
      ? query<TriggerRow>(
          'global',
          `SELECT trigger_name, status
           FROM   user_triggers
           WHERE  trigger_name LIKE 'SYC_%'
           ORDER BY trigger_name`,
        ).catch(() => [] as TriggerRow[])
      : Promise.resolve([] as TriggerRow[]),

    backupOk
      ? getBackupStats().catch(() => undefined)
      : Promise.resolve(undefined),
  ]);

  const response: HealthResponse = {
    global: { ok: globalOk, triggers },
    site1: { ok: site1Ok },
    site2: { ok: site2Ok },
    backup: { ok: backupOk, stats: backupStats },
  };

  return Response.json(response);
}
