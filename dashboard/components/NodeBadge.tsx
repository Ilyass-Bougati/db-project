import type { TriggerRow, BackupStats } from '@/lib/types';

interface Props {
  label: string;
  ok: boolean | null;
  triggers?: TriggerRow[];
  rowCount?: number;
  backupStats?: BackupStats;
}

export default function NodeBadge({ label, ok, triggers, rowCount, backupStats }: Props) {
  const statusColor =
    ok === null
      ? 'bg-gray-200 text-gray-500'
      : ok
        ? 'bg-green-100 text-green-800 border border-green-300'
        : 'bg-red-100 text-red-800 border border-red-300';

  const dotColor =
    ok === null ? 'text-gray-400' : ok ? 'text-green-500' : 'text-red-500';

  return (
    <div className={`rounded-xl p-4 flex flex-col gap-1 ${statusColor}`}>
      <div className="flex items-center gap-2">
        <span className={`text-sm ${dotColor}`}>⬤</span>
        <span className="font-semibold text-sm">{label}</span>
      </div>

      {ok === false && (
        <p className="text-xs mt-1">Unreachable</p>
      )}

      {triggers && triggers.length > 0 && (
        <div className="mt-1 space-y-0.5">
          {triggers.map((t) => (
            <div key={t.TRIGGER_NAME} className="flex items-center gap-1 text-xs">
              <span className={t.STATUS === 'ENABLED' ? 'text-green-600' : 'text-red-600'}>
                {t.STATUS === 'ENABLED' ? '✓' : '✗'}
              </span>
              <span className="font-mono">{t.TRIGGER_NAME}</span>
            </div>
          ))}
        </div>
      )}

      {rowCount !== undefined && (
        <p className="text-xs mt-1 font-mono">{rowCount} rows</p>
      )}

      {backupStats && (
        <div className="mt-1 space-y-0.5 text-xs">
          <p className="font-mono">{backupStats.rowCount} rows</p>
          <p>
            Last sync:{' '}
            <span className="font-mono">
              {backupStats.lastSync ?? 'never'}
            </span>
          </p>
        </div>
      )}
    </div>
  );
}
