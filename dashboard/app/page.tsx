'use client';

import { useState, useEffect, useCallback } from 'react';
import NodeBadge from '@/components/NodeBadge';
import FragmentPanel from '@/components/FragmentPanel';
import InsertForm from '@/components/InsertForm';
import ResultBanner from '@/components/ResultBanner';
import type {
  HealthResponse,
  FragmentsResponse,
  LookupResponse,
  InsertRequest,
  InsertResponse,
  Scenario,
} from '@/lib/types';

const SCENARIO_RULES: Record<Scenario, string> = {
  1: 'R1: IDCATEG=50 ∧ QTÉ>100 → Site 1 · R2: IDCATEG=35 ∧ QTÉ>50 → Site 2',
  2: 'R1: QTÉ ≥ 100 → Site 1 · R2: QTÉ < 100 → Site 2',
};

export default function Dashboard() {
  const [scenario, setScenario] = useState<Scenario>(1);
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [fragments, setFragments] = useState<FragmentsResponse | null>(null);
  const [lookup, setLookup] = useState<LookupResponse | null>(null);
  const [insertResult, setInsertResult] = useState<InsertResponse | null>(null);
  const [inserting, setInserting] = useState(false);
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await fetch('/api/health');
      setHealth(await res.json());
    } catch {
      // network error — leave stale
    }
  }, []);

  const fetchFragments = useCallback(async () => {
    try {
      const res = await fetch(`/api/fragments?scenario=${scenario}`);
      setFragments(await res.json());
      setLastRefresh(new Date());
    } catch {
      // leave stale
    }
  }, [scenario]);

  const fetchLookup = useCallback(async () => {
    try {
      const res = await fetch('/api/lookup');
      setLookup(await res.json());
    } catch {
      // leave stale
    }
  }, []);

  useEffect(() => {
    fetchHealth();
    fetchFragments();
    fetchLookup();
    const id = setInterval(fetchHealth, 10_000);
    return () => clearInterval(id);
  }, [fetchHealth, fetchFragments, fetchLookup]);

  useEffect(() => {
    fetchFragments();
  }, [scenario, fetchFragments]);

  async function handleInsert(req: InsertRequest) {
    setInserting(true);
    setInsertResult(null);
    try {
      const res = await fetch('/api/insert', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(req),
      });
      const result: InsertResponse = await res.json();
      setInsertResult(result);
      await fetchFragments();
    } finally {
      setInserting(false);
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
        <div>
          <h1 className="text-lg font-bold tracking-tight">Oracle Distributed DB Dashboard</h1>
          <p className="text-xs text-gray-400 mt-0.5">{SCENARIO_RULES[scenario]}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex rounded-lg border border-gray-200 overflow-hidden text-sm">
            {([1, 2] as Scenario[]).map((s) => (
              <button
                key={s}
                onClick={() => setScenario(s)}
                className={`px-4 py-1.5 font-medium transition-colors ${
                  scenario === s
                    ? 'bg-blue-600 text-white'
                    : 'bg-white text-gray-600 hover:bg-gray-50'
                }`}
              >
                Scenario {s}
              </button>
            ))}
          </div>
          <button
            onClick={() => { fetchHealth(); fetchFragments(); }}
            className="text-sm text-gray-500 hover:text-gray-800 transition-colors px-2 py-1.5"
            title="Refresh"
          >
            ↺
          </button>
        </div>
      </header>

      <main className="px-6 py-6 space-y-6 max-w-7xl mx-auto">
        <section>
          <h2 className="text-xs font-semibold uppercase tracking-wide text-gray-400 mb-3">
            Node Health
          </h2>
          <div className="grid grid-cols-4 gap-4">
            <NodeBadge
              label="Global DB"
              ok={health?.global.ok ?? null}
              triggers={health?.global.triggers}
            />
            <NodeBadge
              label="Site 1"
              ok={health?.site1.ok ?? null}
              rowCount={fragments?.site1Total}
            />
            <NodeBadge
              label="Site 2"
              ok={health?.site2.ok ?? null}
              rowCount={fragments?.site2Total}
            />
            <NodeBadge
              label="Backup"
              ok={health?.backup.ok ?? null}
              backupStats={health?.backup.stats}
            />
          </div>
        </section>

        <section className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-sm font-semibold mb-4">Insert LIGNECOMMANDE</h2>
          {lookup ? (
            <InsertForm
              produits={lookup.produits}
              commandes={lookup.commandes}
              scenario={scenario}
              onInsert={handleInsert}
              loading={inserting}
            />
          ) : (
            <p className="text-sm text-gray-400">Loading data from global DB…</p>
          )}

          {insertResult && (
            <div className="mt-4">
              <ResultBanner result={insertResult} />
            </div>
          )}
        </section>

        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-gray-400">
              Fragment Tables
            </h2>
            {lastRefresh && (
              <span className="text-xs text-gray-400">
                Last refresh: {lastRefresh.toLocaleTimeString()}
              </span>
            )}
          </div>
          <div className="grid grid-cols-2 gap-4">
            <FragmentPanel
              title="Site 1 — LIGNECOMMANDES1"
              rows={fragments?.site1 ?? []}
              highlightId={
                insertResult?.site === 'site1' || insertResult?.site === 'both'
                  ? insertResult?.idlignecommande
                  : undefined
              }
              color="blue"
            />
            <FragmentPanel
              title="Site 2 — LIGNECOMMANDES2"
              rows={fragments?.site2 ?? []}
              highlightId={
                insertResult?.site === 'site2' || insertResult?.site === 'both'
                  ? insertResult?.idlignecommande
                  : undefined
              }
              color="orange"
            />
          </div>
        </section>
      </main>
    </div>
  );
}
