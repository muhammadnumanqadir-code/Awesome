// Field placement coordinates for the ACORD 27 (2016/03) template.
// See coordinates25.ts for the CONFIRMED / ESTIMATED convention.

import type { Point } from './coordinates25';

export const ACORD27_PAGE = { width: 612, height: 792 };

export const acord27Coords = {
  date: { x: 530.8, y: 740.7 } as Point, // CONFIRMED

  agency: {
    name: { x: 21, y: 673.2 } as Point, // CONFIRMED
    addressLine1: { x: 21, y: 665.6 } as Point, // CONFIRMED
    cityStateZip: { x: 21, y: 658 } as Point, // CONFIRMED
    phone: { x: 171.6, y: 686.7 } as Point, // CONFIRMED
    fax: { x: 49.2, y: 625.5 } as Point, // CONFIRMED
    email: { x: 300, y: 625.5 } as Point, // ESTIMATED (mirrors fax row)
    code: { x: 55, y: 612 } as Point, // ESTIMATED
    subCode: { x: 210, y: 612 } as Point, // ESTIMATED
    customerId: { x: 70.8, y: 600.7 } as Point, // CONFIRMED
  },

  companyName: { x: 307.2, y: 676.8 } as Point, // CONFIRMED (insurer name)

  insured: {
    name: { x: 68.4, y: 590.4 } as Point, // CONFIRMED
    addressLine1: { x: 68.4, y: 581.4 } as Point, // CONFIRMED
    cityStateZip: { x: 68.4, y: 572.5 } as Point, // CONFIRMED
  },

  loanNumber: { x: 307.2, y: 579.3 } as Point, // CONFIRMED
  policyNumber: { x: 465.6, y: 579.6 } as Point, // CONFIRMED
  effectiveDate: { x: 328.6, y: 555.3 } as Point, // CONFIRMED
  expirationDate: { x: 415, y: 555.3 } as Point, // CONFIRMED
  continuedUntilTerminatedCheckbox: { x: 487, y: 553 } as Point, // ESTIMATED
  replacesPriorEvidenceDated: { x: 480, y: 540 } as Point, // ESTIMATED

  propertyLocationDescription: {
    x: 18.6,
    y: 499.4,
    maxWidth: 570,
    lineHeight: 10,
  } as Point & { maxWidth: number; lineHeight: number }, // CONFIRMED start position

  perilsCheckboxes: {
    basic: { x: 250, y: 397.7 } as Point, // ESTIMATED
    broad: { x: 300, y: 397.7 } as Point, // ESTIMATED
    special: { x: 354, y: 397.7 } as Point, // CONFIRMED
  },

  // Up to a handful of coverage/perils/forms line items, 9pt apart.
  coverageLineStartY: 365.1, // CONFIRMED (first row)
  coverageLineStep: 9,
  coverageColumns: {
    description: 23.4,
    amount: 496.9,
    deductible: 570.2,
  },

  remarks: { x: 20.4, y: 245, maxWidth: 570, lineHeight: 8.5 } as Point & {
    maxWidth: number;
    lineHeight: number;
  }, // CONFIRMED start position

  additionalInterest: {
    // Single row of four checkboxes sharing one y, ~86pt column spacing.
    additionalInsuredCheckbox: { x: 307, y: 115.7 } as Point, // ESTIMATED
    lendersLossPayableCheckbox: { x: 393, y: 115.7 } as Point, // CONFIRMED
    lossPayeeCheckbox: { x: 508, y: 115.7 } as Point, // ESTIMATED
    mortgageeCheckbox: { x: 307, y: 103.7 } as Point, // CONFIRMED
    name: { x: 83.4, y: 85.1 } as Point, // CONFIRMED
    addressLine1: { x: 83.4, y: 76.1 } as Point, // CONFIRMED
    cityStateZip: { x: 83.4, y: 67.2 } as Point, // CONFIRMED
    loanNumber: { x: 303.6, y: 80.7 } as Point, // CONFIRMED
  },
};
