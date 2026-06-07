export const runtime = 'nodejs';

import { query } from '@/lib/oracle';
import type { Produit, Commande, LookupResponse } from '@/lib/types';

export async function GET() {
  const [produits, commandes] = await Promise.all([
    query<Produit>(
      'global',
      `SELECT IDPRODUIT, DESIGNATION, IDCATEG, PRIXUNITAIRE
       FROM   PRODUITS
       ORDER BY IDPRODUIT`,
    ),
    query<Commande>(
      'global',
      `SELECT * FROM (
         SELECT IDCOMMANDE, IDCLIENT
         FROM   COMMANDES
         ORDER BY IDCOMMANDE DESC
       ) WHERE ROWNUM <= 50`,
    ),
  ]);

  const response: LookupResponse = { produits, commandes };
  return Response.json(response);
}
