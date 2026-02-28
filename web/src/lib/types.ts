export type ComplianceStatus = "Compliant" | "At Risk" | "Overdue";

export type FilingType =
  | "Annual Budget"
  | "Reserve Study"
  | "Year-End Financial Statement"
  | "Insurance Summary"
  | "Board Meeting Minutes";

export interface CondoAssociation {
  id: string;
  legalName: string;
  city: string;
  state: string;
  county: string;
  zip: string | null;
  latitude: number | null;
  longitude: number | null;
  unitCount: number;
  managerEmail: string;
  complianceStatus: ComplianceStatus;
  nextDeadline: string;
  lastPublishedAt: string;
}

export interface Filing {
  id: string;
  condoId: string;
  type: FilingType;
  periodLabel: string;
  publishedAt: string;
  sourceLabel: string;
  sourceUrl: string;
}
