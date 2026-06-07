export const runtime = 'nodejs';

import { query } from '@/lib/oracle';
import type { LigneCommande, FragmentsResponse } from '@/lib/types';

const ROWS_SQL = (table: string) => `
  SELECT * FROM (
    SELECT IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE
    FROM   ${table}
    ORDER BY IDLIGNECOMMANDE DESC
  ) WHERE ROWNUM <= 20
`;

const COUNT_SQL = (table: string) =>
  `SELECT COUNT(*) AS TOTAL FROM ${table}`;

export async function GET() {
  const [s1Rows, s2Rows, s1Count, s2Count] = await Promise.allSettled([
    query<LigneCommande>('site1', ROWS_SQL('LIGNECOMMANDES1')),
    query<LigneCommande>('site2', ROWS_SQL('LIGNECOMMANDES2')),
    query<{ TOTAL: number }>('site1', COUNT_SQL('LIGNECOMMANDES1')),
    query<{ TOTAL: number }>('site2', COUNT_SQL('LIGNECOMMANDES2')),
  ]);

  const response: FragmentsResponse = {
    site1: s1Rows.status === 'fulfilled' ? s1Rows.value : [],
    site2: s2Rows.status === 'fulfilled' ? s2Rows.value : [],
    site1Total: s1Count.status === 'fulfilled' ? s1Count.value[0].TOTAL : 0,
    site2Total: s2Count.status === 'fulfilled' ? s2Count.value[0].TOTAL : 0,
  };

  return Response.json(response);
}
