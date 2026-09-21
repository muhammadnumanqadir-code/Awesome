// Shared data model for ACORD 25 (Certificate of Liability Insurance) and
// ACORD 27 (Certificate/Evidence of Property Insurance) autofill.

export interface Address {
  street: string;
  city: string;
  state: string;
  zip: string;
}

export interface Producer {
  name: string;
  address: Address;
  contactName: string;
  phone: string;
  fax: string;
  email: string;
}

export interface Insured {
  name: string;
  dba: string;
  address: Address;
}

export interface CertificateHolder {
  name: string;
  address: Address;
}

/** Insurer letter as printed on the ACORD 25 "INSURER(S) AFFORDING COVERAGE" grid. */
export type InsurerLetter = 'A' | 'B' | 'C' | 'D' | 'E' | 'F';

export interface Insurer {
  letter: InsurerLetter;
  name: string;
  naic: string;
}

export type Acord25CoverageType =
  | 'GENERAL_LIABILITY'
  | 'AUTOMOBILE_LIABILITY'
  | 'UMBRELLA_EXCESS'
  | 'WORKERS_COMP_EMPLOYERS_LIABILITY'
  | 'OTHER';

/** General Liability sub-selections (checkboxes on the form). */
export interface GeneralLiabilityOptions {
  claimsMade: boolean;
  occur: boolean;
  aggregateLimitAppliesPer: 'POLICY' | 'PROJECT' | 'LOC' | 'OTHER' | null;
}

/** Automobile Liability sub-selections. */
export interface AutoLiabilityOptions {
  anyAuto: boolean;
  ownedAutosOnly: boolean;
  scheduledAutos: boolean;
  hiredAutosOnly: boolean;
  nonOwnedAutosOnly: boolean;
}

/** Umbrella/Excess sub-selections. */
export interface UmbrellaExcessOptions {
  umbrella: boolean;
  excess: boolean;
  occur: boolean;
  claimsMade: boolean;
  deductible: string;
  retention: string;
}

/** Workers Comp sub-selections. */
export interface WorkersCompOptions {
  anyProprietorExcluded: 'Y' | 'N' | null;
  perStatute: boolean;
  otherLimit: boolean;
}

export interface CoverageLimits {
  eachOccurrence?: string;
  damageToRentedPremises?: string;
  medExp?: string;
  personalAdvInjury?: string;
  generalAggregate?: string;
  productsCompOpAgg?: string;
  combinedSingleLimit?: string;
  bodilyInjuryPerPerson?: string;
  bodilyInjuryPerAccident?: string;
  propertyDamage?: string;
  eachOccurrenceUmbrella?: string;
  aggregateUmbrella?: string;
  elEachAccident?: string;
  elDiseaseEaEmployee?: string;
  elDiseasePolicyLimit?: string;
  otherDescription?: string;
  otherLimit?: string;
}

export interface Acord25CoverageLine {
  id: string;
  insurerLetter: InsurerLetter;
  coverageType: Acord25CoverageType;
  policyNumber: string;
  /** MM/DD/YYYY */
  effectiveDate: string;
  /** MM/DD/YYYY */
  expirationDate: string;
  limits: CoverageLimits;
  generalLiabilityOptions?: GeneralLiabilityOptions;
  autoLiabilityOptions?: AutoLiabilityOptions;
  umbrellaExcessOptions?: UmbrellaExcessOptions;
  workersCompOptions?: WorkersCompOptions;
  additionalInsured: boolean;
  subrogationWaived: boolean;
}

export type Acord27CauseOfLossType = 'BASIC' | 'BROAD' | 'SPECIAL';

export interface Acord27CoverageLimits {
  building?: string;
  businessPersonalProperty?: string;
  businessIncome?: string;
  other?: string;
}

export interface Acord27CoverageLine {
  id: string;
  description: string;
  amountOfInsurance: string;
  deductible: string;
}

export interface MortgageeLossPayee {
  type: 'MORTGAGEE' | 'LOSS_PAYEE' | 'LENDERS_LOSS_PAYABLE' | 'ADDITIONAL_INSURED';
  name: string;
  address: Address;
  loanNumber: string;
}

export interface Acord27Data {
  causeOfLoss: Acord27CauseOfLossType | null;
  insurerName: string;
  policyNumber: string;
  effectiveDate: string;
  expirationDate: string;
  continuedUntilTerminated: boolean;
  propertyLocationDescription: string;
  coverageLines: Acord27CoverageLine[];
  limits: Acord27CoverageLimits;
  remarks: string;
  mortgagee: MortgageeLossPayee | null;
}

export interface CertificateData {
  producer: Producer;
  insured: Insured;
  certificateHolder: CertificateHolder;
  insurers: Insurer[];
  certificateNumber: string;
  revisionNumber: string;
  certificateDate: string;
  acord25CoverageLines: Acord25CoverageLine[];
  descriptionOfOperations: string;
  acord27: Acord27Data;
  generateAcord25: boolean;
  generateAcord27: boolean;
}

export function emptyAddress(): Address {
  return { street: '', city: '', state: '', zip: '' };
}

export function emptyCertificateData(): CertificateData {
  return {
    producer: {
      name: '',
      address: emptyAddress(),
      contactName: '',
      phone: '',
      fax: '',
      email: '',
    },
    insured: { name: '', dba: '', address: emptyAddress() },
    certificateHolder: { name: '', address: emptyAddress() },
    insurers: [],
    certificateNumber: '',
    revisionNumber: '',
    certificateDate: '',
    acord25CoverageLines: [],
    descriptionOfOperations: '',
    acord27: {
      causeOfLoss: null,
      insurerName: '',
      policyNumber: '',
      effectiveDate: '',
      expirationDate: '',
      continuedUntilTerminated: false,
      propertyLocationDescription: '',
      coverageLines: [],
      limits: {},
      remarks: '',
      mortgagee: null,
    },
    generateAcord25: true,
    generateAcord27: false,
  };
}
