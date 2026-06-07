import type { LigneCommande } from '@/lib/types';

interface Props {
  title: string;
  rows: LigneCommande[];
  highlightId?: number;
  color: 'blue' | 'orange';
}

export default function FragmentPanel({ title, rows, highlightId, color }: Props) {
  const headerColor =
    color === 'blue'
      ? 'bg-blue-600 text-white'
      : 'bg-orange-500 text-white';

  return (
    <div className="flex flex-col rounded-xl overflow-hidden border border-gray-200">
      <div className={`px-4 py-2 flex items-center justify-between ${headerColor}`}>
        <span className="font-semibold text-sm">{title}</span>
        <span className="text-xs opacity-80">{rows.length} rows</span>
      </div>

      <div className="overflow-auto max-h-72">
        {rows.length === 0 ? (
          <p className="text-sm text-gray-400 text-center py-6">No rows yet</p>
        ) : (
          <table className="w-full text-xs">
            <thead className="bg-gray-50 sticky top-0">
              <tr>
                {['ID', 'COMMANDE', 'PRODUIT', 'QTÉ', 'REMISE'].map((h) => (
                  <th
                    key={h}
                    className="px-3 py-1.5 text-left font-medium text-gray-500 border-b border-gray-200"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr
                  key={row.IDLIGNECOMMANDE}
                  className={
                    row.IDLIGNECOMMANDE === highlightId
                      ? 'bg-yellow-50 font-semibold'
                      : 'even:bg-gray-50'
                  }
                >
                  <td className="px-3 py-1 font-mono">
                    {row.IDLIGNECOMMANDE === highlightId && (
                      <span className="mr-1 text-yellow-600">★</span>
                    )}
                    {row.IDLIGNECOMMANDE}
                  </td>
                  <td className="px-3 py-1 font-mono">{row.IDCOMMANDE}</td>
                  <td className="px-3 py-1 font-mono">{row.IDPRODUIT}</td>
                  <td className="px-3 py-1 font-mono">{row.QUANTITE}</td>
                  <td className="px-3 py-1 font-mono">{row.REMISE}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
