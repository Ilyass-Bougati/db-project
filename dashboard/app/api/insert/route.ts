export const runtime = 'nodejs';

import { query, run } from '@/lib/oracle';
import type { InsertRequest, InsertResponse, LigneCommande } from '@/lib/types';

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function POST(request: Request) {
  const body: InsertRequest = await request.json();
  const { idcommande, idproduit, quantite, remise } = body;

  // Generate next PK
  const pkRows = await query<{ NEXTID: number }>(
    'global',
    'SELECT NVL(MAX(IDLIGNECOMMANDE), 0) + 1 AS NEXTID FROM LIGNECOMMANDES',
  );
  const idlignecommande = pkRows[0].NEXTID;

  // Insert into global — triggers fire automatically
  try {
    await run(
      'global',
      `INSERT INTO LIGNECOMMANDES (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
       VALUES (:1, :2, :3, :4, :5)`,
      [idlignecommande, idcommande, idproduit, quantite, remise],
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    const response: InsertResponse = { site: 'none', error: msg };
    return Response.json(response, { status: 500 });
  }

  // Wait for trigger propagation
  await sleep(700);

  // Check which site(s) received the row
  const findSql = (table: string) =>
    `SELECT IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE
     FROM ${table}
     WHERE IDLIGNECOMMANDE = :1`;

  const [s1Rows, s2Rows] = await Promise.allSettled([
    query<LigneCommande>('site1', findSql('LIGNECOMMANDES1'), [idlignecommande]),
    query<LigneCommande>('site2', findSql('LIGNECOMMANDES2'), [idlignecommande]),
  ]);

  const inS1 = s1Rows.status === 'fulfilled' && s1Rows.value.length > 0;
  const inS2 = s2Rows.status === 'fulfilled' && s2Rows.value.length > 0;

  let site: InsertResponse['site'] = 'none';
  let row: LigneCommande | undefined;

  if (inS1 && inS2) {
    site = 'both';
    row = (s1Rows as PromiseFulfilledResult<LigneCommande[]>).value[0];
  } else if (inS1) {
    site = 'site1';
    row = (s1Rows as PromiseFulfilledResult<LigneCommande[]>).value[0];
  } else if (inS2) {
    site = 'site2';
    row = (s2Rows as PromiseFulfilledResult<LigneCommande[]>).value[0];
  }

  const response: InsertResponse = { idlignecommande, site, row };
  return Response.json(response);
}
