// Field placement coordinates for the ACORD 25 (2016/03) template.
//
// Coordinates are in PDF points, origin at the bottom-left of the page
// (612 x 792pt / US Letter), matching pdf-lib's `page.drawText` convention.
//
// Positions marked CONFIRMED were read directly off a real filled sample of
// this exact form revision (see ../../samples/acord-25-sample.pdf) before it
// was stripped down to a blank template - i.e. this is exactly where the
// original flattening tool placed each value. Positions marked ESTIMATED
// were interpolated from the surrounding grid-line spacing (the Auto
// Liability / Umbrella / Workers Comp / Other rows were blank in the sample)
// and should be treated as a first pass - verify visually against a
// generated PDF and nudge if needed.

export interface Point {
  x: number;
  y: number;
}

export const ACORD25_PAGE = { width: 612, height: 792 };

export const acord25Coords = {
  certificateDate: { x: 530.8, y: 746.6 } as Point, // CONFIRMED

  producer: {
    name: { x: 23.6, y: 650.6 } as Point, // CONFIRMED
    addressLine1: { x: 23.6, y: 638.6 } as Point, // CONFIRMED
    city: { x: 23.6, y: 614.6 } as Point, // CONFIRMED
    state: { x: 241, y: 614.6 } as Point, // CONFIRMED
    zip: { x: 257.6, y: 614.6 } as Point, // CONFIRMED
    contactName: { x: 347.6, y: 662.6 } as Point, // CONFIRMED
    phone: { x: 354.8, y: 650.6 } as Point, // CONFIRMED
    fax: { x: 522, y: 650.6 } as Point, // ESTIMATED (mirrors phone column)
    email: { x: 347.6, y: 638.6 } as Point, // CONFIRMED
  },

  insured: {
    name: { x: 74, y: 590.6 } as Point, // CONFIRMED
    addressLine1: { x: 74, y: 578.6 } as Point, // CONFIRMED
    city: { x: 74, y: 554.6 } as Point, // CONFIRMED
    state: { x: 241, y: 554.6 } as Point, // CONFIRMED
    zip: { x: 257.6, y: 554.6 } as Point, // CONFIRMED
  },

  // INSURER(S) AFFORDING COVERAGE grid - one row per letter A-F, 12pt apart.
  insurerRows: {
    A: { name: { x: 351.2, y: 614.6 }, naic: { x: 555.9, y: 614.6 } }, // CONFIRMED
    B: { name: { x: 351.2, y: 602.6 }, naic: { x: 555.9, y: 602.6 } }, // ESTIMATED (12pt row step)
    C: { name: { x: 351.2, y: 590.6 }, naic: { x: 555.9, y: 590.6 } }, // ESTIMATED
    D: { name: { x: 351.2, y: 578.6 }, naic: { x: 555.9, y: 578.6 } }, // ESTIMATED
    E: { name: { x: 351.2, y: 566.6 }, naic: { x: 555.9, y: 566.6 } }, // ESTIMATED
    F: { name: { x: 351.2, y: 554.6 }, naic: { x: 555.9, y: 554.6 } }, // ESTIMATED
  } as Record<string, { name: Point; naic: Point }>,

  certificateNumber: { x: 272, y: 542.2 } as Point, // ESTIMATED (right of label)
  revisionNumber: { x: 516, y: 542.2 } as Point, // ESTIMATED (right of label)

  // Each coverage-type section has one fixed LTR / POLICY NUMBER / EFF / EXP
  // row, plus its own limits column. x columns are shared across all rows.
  columns: {
    insrLtr: 24.3,
    addlInsdCheckbox: 178.5, // "ADDL INSD" checkbox column
    subrWvdCheckbox: 196.6, // "SUBR WVD" checkbox column
    policyNumber: 218,
    policyEff: 334.6,
    policyExp: 381.4,
    limitDollar: 527.6,
  },

  generalLiability: {
    row: { insrLtr: 24.3, policyNumber: 218, eff: 334.6, exp: 381.4 }, // CONFIRMED (row y=446.6)
    rowY: 446.6,
    claimsMadeCheckbox: { x: 61, y: 470 } as Point, // ESTIMATED
    occurCheckbox: { x: 126, y: 470 } as Point, // ESTIMATED
    aggregatePerPolicyCheckbox: { x: 32, y: 422 } as Point, // ESTIMATED
    aggregatePerProjectCheckbox: { x: 90, y: 422 } as Point, // ESTIMATED
    aggregatePerLocCheckbox: { x: 133, y: 422 } as Point, // ESTIMATED
    limits: {
      eachOccurrence: { x: 527.6, y: 482.6 } as Point, // CONFIRMED
      damageToRentedPremises: { x: 527.6, y: 470.6 } as Point, // CONFIRMED
      medExp: { x: 527.6, y: 458.6 } as Point, // CONFIRMED
      personalAdvInjury: { x: 527.6, y: 446.6 } as Point, // CONFIRMED
      generalAggregate: { x: 527.6, y: 434.6 } as Point, // CONFIRMED
      productsCompOpAgg: { x: 527.6, y: 422.6 } as Point, // CONFIRMED
    },
  },

  autoLiability: {
    rowY: 376, // ESTIMATED
    row: { insrLtr: 24.3, policyNumber: 218, eff: 334.6, exp: 381.4 },
    anyAutoCheckbox: { x: 47, y: 389 } as Point, // ESTIMATED
    ownedAutosOnlyCheckbox: { x: 47, y: 373 } as Point, // ESTIMATED
    scheduledAutosCheckbox: { x: 115, y: 373 } as Point, // ESTIMATED
    hiredAutosOnlyCheckbox: { x: 47, y: 361 } as Point, // ESTIMATED
    nonOwnedAutosOnlyCheckbox: { x: 115, y: 361 } as Point, // ESTIMATED
    limits: {
      combinedSingleLimit: { x: 527.6, y: 400 } as Point, // CONFIRMED (aligned to printed "$" glyph)
      bodilyInjuryPerPerson: { x: 527.6, y: 388 } as Point, // CONFIRMED
      bodilyInjuryPerAccident: { x: 527.6, y: 376 } as Point, // CONFIRMED
      propertyDamage: { x: 527.6, y: 364 } as Point, // CONFIRMED
    },
  },

  umbrellaExcess: {
    rowY: 328, // ESTIMATED
    row: { insrLtr: 24.3, policyNumber: 218, eff: 334.6, exp: 381.4 },
    umbrellaCheckbox: { x: 47, y: 341 } as Point, // ESTIMATED
    excessCheckbox: { x: 47, y: 329 } as Point, // ESTIMATED
    occurCheckbox: { x: 126, y: 341 } as Point, // ESTIMATED
    claimsMadeCheckbox: { x: 126, y: 329 } as Point, // ESTIMATED
    dedCheckbox: { x: 47, y: 314 } as Point, // ESTIMATED
    dedAmount: { x: 66, y: 314 } as Point, // ESTIMATED
    retentionAmount: { x: 130, y: 314 } as Point, // ESTIMATED
    limits: {
      eachOccurrence: { x: 527.6, y: 338 } as Point, // CONFIRMED (aligned to printed "$" glyph)
      aggregate: { x: 527.6, y: 326 } as Point, // CONFIRMED
    },
  },

  workersComp: {
    rowY: 279, // ESTIMATED
    row: { insrLtr: 24.3, policyNumber: 218, eff: 334.6, exp: 381.4 },
    anyProprietorYN: { x: 182, y: 291 } as Point, // ESTIMATED
    perStatuteCheckbox: { x: 445, y: 302 } as Point, // ESTIMATED
    otherCheckbox: { x: 495, y: 302 } as Point, // ESTIMATED
    limits: {
      elEachAccident: { x: 527.6, y: 291 } as Point, // ESTIMATED
      elDiseaseEaEmployee: { x: 527.6, y: 279 } as Point, // ESTIMATED
      elDiseasePolicyLimit: { x: 527.6, y: 267 } as Point, // ESTIMATED
    },
  },

  // Two generic blank rows below Workers Comp for "OTHER" coverage types.
  otherRows: [
    { rowY: 241, insrLtr: 24.3, policyNumber: 218, eff: 334.6, exp: 381.4, limit: { x: 527.6, y: 242 } },
    { rowY: 229, insrLtr: 24.3, policyNumber: 218, eff: 334.6, exp: 381.4, limit: { x: 527.6, y: 230 } },
  ] as Array<{ rowY: number; insrLtr: number; policyNumber: number; eff: number; exp: number; limit: Point }>, // ESTIMATED

  descriptionOfOperations: { x: 23, y: 203, maxWidth: 280, lineHeight: 10 } as Point & {
    maxWidth: number;
    lineHeight: number;
  }, // CONFIRMED start position; wraps within the box

  certificateHolder: {
    name: { x: 23, y: 120 } as Point, // ESTIMATED
    addressLine1: { x: 23, y: 108 } as Point, // ESTIMATED
    cityStateZip: { x: 23, y: 96 } as Point, // ESTIMATED
  },
};
