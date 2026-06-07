'use client';

import { useState, useMemo } from 'react';
import type { Produit, Commande, InsertRequest, Scenario } from '@/lib/types';

interface Props {
  produits: Produit[];
  commandes: Commande[];
  scenario: Scenario;
  onInsert: (req: InsertRequest) => Promise<void>;
  loading: boolean;
}

function predictSite(produit: Produit | undefined, quantite: number, scenario: Scenario) {
  if (!produit || !quantite) return null;
  if (scenario === 1) {
    if (produit.IDCATEG === 50 && quantite > 100) return 'Site 1';
    if (produit.IDCATEG === 35 && quantite > 50) return 'Site 2';
    return 'None (row won\'t be fragmented)';
  }
  return quantite >= 100 ? 'Site 1' : 'Site 2';
}

export default function InsertForm({ produits, commandes, scenario, onInsert, loading }: Props) {
  const [idcommande, setIdcommande] = useState('');
  const [idproduit, setIdproduit] = useState('');
  const [quantite, setQuantite] = useState('');
  const [remise, setRemise] = useState('0');

  const selectedProduit = useMemo(
    () => produits.find((p) => p.IDPRODUIT === Number(idproduit)),
    [produits, idproduit],
  );

  const prediction = predictSite(selectedProduit, Number(quantite), scenario);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    await onInsert({
      scenario,
      idcommande: Number(idcommande),
      idproduit: Number(idproduit),
      quantite: Number(quantite),
      remise: Number(remise),
    });
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-gray-600">IDCOMMANDE</label>
          <select
            required
            value={idcommande}
            onChange={(e) => setIdcommande(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
          >
            <option value="">— select —</option>
            {commandes.map((c) => (
              <option key={c.IDCOMMANDE} value={c.IDCOMMANDE}>
                #{c.IDCOMMANDE} (client {c.IDCLIENT})
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-gray-600">IDPRODUIT</label>
          <select
            required
            value={idproduit}
            onChange={(e) => setIdproduit(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
          >
            <option value="">— select —</option>
            {produits.map((p) => (
              <option key={p.IDPRODUIT} value={p.IDPRODUIT}>
                #{p.IDPRODUIT} {p.DESIGNATION} (catég. {p.IDCATEG})
              </option>
            ))}
          </select>
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-gray-600">QUANTITE</label>
          <input
            type="number"
            required
            min={1}
            value={quantite}
            onChange={(e) => setQuantite(e.target.value)}
            placeholder="e.g. 150"
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
          />
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-gray-600">REMISE (0–1)</label>
          <input
            type="number"
            required
            min={0}
            max={1}
            step={0.05}
            value={remise}
            onChange={(e) => setRemise(e.target.value)}
            placeholder="e.g. 0.1"
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
          />
        </div>
      </div>

      <div className="flex items-center gap-4">
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-blue-600 px-5 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {loading ? 'Inserting…' : 'Insert'}
        </button>

        {prediction && (
          <p className="text-sm text-gray-500">
            Expected destination:{' '}
            <span className={`font-semibold ${
              prediction.startsWith('Site 1') ? 'text-blue-600' :
              prediction.startsWith('Site 2') ? 'text-orange-500' :
              'text-gray-400'
            }`}>
              {prediction}
            </span>
          </p>
        )}
      </div>
    </form>
  );
}
