import type { InsertResponse } from '@/lib/types';

interface Props {
  result: InsertResponse;
}

const siteLabel: Record<InsertResponse['site'], string> = {
  site1: 'Site 1',
  site2: 'Site 2',
  both: 'Both sites',
  none: 'Neither site (check triggers)',
};

const siteColor: Record<InsertResponse['site'], string> = {
  site1: 'bg-blue-50 border-blue-300 text-blue-800',
  site2: 'bg-orange-50 border-orange-300 text-orange-800',
  both: 'bg-purple-50 border-purple-300 text-purple-800',
  none: 'bg-red-50 border-red-300 text-red-800',
};

export default function ResultBanner({ result }: Props) {
  if (result.error) {
    return (
      <div className="rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-800">
        <span className="font-semibold">Insert failed:</span> {result.error}
      </div>
    );
  }

  return (
    <div className={`rounded-lg border px-4 py-3 text-sm ${siteColor[result.site]}`}>
      <div className="flex items-center gap-2">
        <span className="text-base">{result.site === 'none' ? '✗' : '✓'}</span>
        <span>
          Row <span className="font-mono font-semibold">#{result.idlignecommande}</span>{' '}
          was routed to{' '}
          <span className="font-semibold">{siteLabel[result.site]}</span>
        </span>
      </div>
      {result.row && (
        <p className="mt-1 font-mono text-xs opacity-75">
          COMMANDE={result.row.IDCOMMANDE} · PRODUIT={result.row.IDPRODUIT} ·
          QTÉ={result.row.QUANTITE} · REMISE={result.row.REMISE}
        </p>
      )}
    </div>
  );
}
