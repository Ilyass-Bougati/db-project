export type NodeAlias = 'global' | 'site1' | 'site2' | 'backup';
export type Scenario = 1 | 2;

export interface TriggerRow {
  TRIGGER_NAME: string;
  STATUS: string;
}

export interface BackupStats {
  lastSync: string | null;
  rowCount: number;
}

export interface HealthResponse {
  global: { ok: boolean; triggers: TriggerRow[] };
  site1: { ok: boolean };
  site2: { ok: boolean };
  backup: { ok: boolean; stats?: BackupStats };
}

export interface LigneCommande {
  IDLIGNECOMMANDE: number;
  IDCOMMANDE: number;
  IDPRODUIT: number;
  QUANTITE: number;
  REMISE: number;
}

export interface FragmentsResponse {
  site1: LigneCommande[];
  site2: LigneCommande[];
  site1Total: number;
  site2Total: number;
}

export interface Produit {
  IDPRODUIT: number;
  DESIGNATION: string;
  IDCATEG: number;
  PRIXUNITAIRE: number;
}

export interface Commande {
  IDCOMMANDE: number;
  IDCLIENT: number;
}

export interface LookupResponse {
  produits: Produit[];
  commandes: Commande[];
}

export interface InsertRequest {
  scenario: Scenario;
  idcommande: number;
  idproduit: number;
  quantite: number;
  remise: number;
}

export interface InsertResponse {
  idlignecommande?: number;
  site: 'site1' | 'site2' | 'both' | 'none';
  row?: LigneCommande;
  error?: string;
}
