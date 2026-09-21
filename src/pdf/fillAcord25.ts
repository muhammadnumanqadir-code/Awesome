import { PDFDocument, StandardFonts } from 'pdf-lib';
import type { CertificateData, Acord25CoverageLine } from '../types';
import { acord25Coords } from './coordinates25';
import { drawValue, drawCheckmark, drawWrappedText } from './drawHelpers';

const TEMPLATE_URL = '/acord-templates/acord-25-template.pdf';

async function loadTemplateBytes(url: string): Promise<ArrayBuffer> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load PDF template at ${url}: ${res.status}`);
  return res.arrayBuffer();
}

function drawCoverageLine(
  page: import('pdf-lib').PDFPage,
  font: import('pdf-lib').PDFFont,
  line: Acord25CoverageLine,
  otherRowIndex: { current: number },
) {
  const c = acord25Coords;
  let row: { insrLtr: number; policyNumber: number; eff: number; exp: number };
  let rowY: number;

  switch (line.coverageType) {
    case 'GENERAL_LIABILITY':
      row = c.generalLiability.row;
      rowY = c.generalLiability.rowY;
      break;
    case 'AUTOMOBILE_LIABILITY':
      row = c.autoLiability.row;
      rowY = c.autoLiability.rowY;
      break;
    case 'UMBRELLA_EXCESS':
      row = c.umbrellaExcess.row;
      rowY = c.umbrellaExcess.rowY;
      break;
    case 'WORKERS_COMP_EMPLOYERS_LIABILITY':
      row = c.workersComp.row;
      rowY = c.workersComp.rowY;
      break;
    case 'OTHER':
    default: {
      const slot = c.otherRows[otherRowIndex.current];
      otherRowIndex.current += 1;
      if (!slot) return; // no more room on the form for additional "other" lines
      row = { insrLtr: slot.insrLtr, policyNumber: slot.policyNumber, eff: slot.eff, exp: slot.exp };
      rowY = slot.rowY;
      drawValue(page, font, line.limits.otherDescription, { x: 55, y: rowY });
      drawValue(page, font, line.limits.otherLimit, slot.limit);
      break;
    }
  }

  drawValue(page, font, line.insurerLetter, { x: row.insrLtr, y: rowY });
  drawValue(page, font, line.policyNumber, { x: row.policyNumber, y: rowY });
  drawValue(page, font, line.effectiveDate, { x: row.eff, y: rowY });
  drawValue(page, font, line.expirationDate, { x: row.exp, y: rowY });
  if (line.additionalInsured) drawCheckmark(page, font, { x: c.columns.addlInsdCheckbox, y: rowY });
  if (line.subrogationWaived) drawCheckmark(page, font, { x: c.columns.subrWvdCheckbox, y: rowY });

  if (line.coverageType === 'GENERAL_LIABILITY') {
    const gl = c.generalLiability;
    const opts = line.generalLiabilityOptions;
    if (opts?.claimsMade) drawCheckmark(page, font, gl.claimsMadeCheckbox);
    if (opts?.occur) drawCheckmark(page, font, gl.occurCheckbox);
    if (opts?.aggregateLimitAppliesPer === 'POLICY') drawCheckmark(page, font, gl.aggregatePerPolicyCheckbox);
    if (opts?.aggregateLimitAppliesPer === 'PROJECT') drawCheckmark(page, font, gl.aggregatePerProjectCheckbox);
    if (opts?.aggregateLimitAppliesPer === 'LOC') drawCheckmark(page, font, gl.aggregatePerLocCheckbox);
    const l = line.limits;
    drawValue(page, font, l.eachOccurrence, gl.limits.eachOccurrence);
    drawValue(page, font, l.damageToRentedPremises, gl.limits.damageToRentedPremises);
    drawValue(page, font, l.medExp, gl.limits.medExp);
    drawValue(page, font, l.personalAdvInjury, gl.limits.personalAdvInjury);
    drawValue(page, font, l.generalAggregate, gl.limits.generalAggregate);
    drawValue(page, font, l.productsCompOpAgg, gl.limits.productsCompOpAgg);
  } else if (line.coverageType === 'AUTOMOBILE_LIABILITY') {
    const auto = c.autoLiability;
    const opts = line.autoLiabilityOptions;
    if (opts?.anyAuto) drawCheckmark(page, font, auto.anyAutoCheckbox);
    if (opts?.ownedAutosOnly) drawCheckmark(page, font, auto.ownedAutosOnlyCheckbox);
    if (opts?.scheduledAutos) drawCheckmark(page, font, auto.scheduledAutosCheckbox);
    if (opts?.hiredAutosOnly) drawCheckmark(page, font, auto.hiredAutosOnlyCheckbox);
    if (opts?.nonOwnedAutosOnly) drawCheckmark(page, font, auto.nonOwnedAutosOnlyCheckbox);
    const l = line.limits;
    drawValue(page, font, l.combinedSingleLimit, auto.limits.combinedSingleLimit);
    drawValue(page, font, l.bodilyInjuryPerPerson, auto.limits.bodilyInjuryPerPerson);
    drawValue(page, font, l.bodilyInjuryPerAccident, auto.limits.bodilyInjuryPerAccident);
    drawValue(page, font, l.propertyDamage, auto.limits.propertyDamage);
  } else if (line.coverageType === 'UMBRELLA_EXCESS') {
    const umb = c.umbrellaExcess;
    const opts = line.umbrellaExcessOptions;
    if (opts?.umbrella) drawCheckmark(page, font, umb.umbrellaCheckbox);
    if (opts?.excess) drawCheckmark(page, font, umb.excessCheckbox);
    if (opts?.occur) drawCheckmark(page, font, umb.occurCheckbox);
    if (opts?.claimsMade) drawCheckmark(page, font, umb.claimsMadeCheckbox);
    if (opts?.deductible) {
      drawCheckmark(page, font, umb.dedCheckbox);
      drawValue(page, font, opts.deductible, umb.dedAmount);
    }
    if (opts?.retention) drawValue(page, font, opts.retention, umb.retentionAmount);
    const l = line.limits;
    drawValue(page, font, l.eachOccurrenceUmbrella, umb.limits.eachOccurrence);
    drawValue(page, font, l.aggregateUmbrella, umb.limits.aggregate);
  } else if (line.coverageType === 'WORKERS_COMP_EMPLOYERS_LIABILITY') {
    const wc = c.workersComp;
    const opts = line.workersCompOptions;
    if (opts?.anyProprietorExcluded) drawValue(page, font, opts.anyProprietorExcluded, wc.anyProprietorYN);
    if (opts?.perStatute) drawCheckmark(page, font, wc.perStatuteCheckbox);
    if (opts?.otherLimit) drawCheckmark(page, font, wc.otherCheckbox);
    const l = line.limits;
    drawValue(page, font, l.elEachAccident, wc.limits.elEachAccident);
    drawValue(page, font, l.elDiseaseEaEmployee, wc.limits.elDiseaseEaEmployee);
    drawValue(page, font, l.elDiseasePolicyLimit, wc.limits.elDiseasePolicyLimit);
  }
}

export async function fillAcord25(data: CertificateData): Promise<Uint8Array> {
  const templateBytes = await loadTemplateBytes(TEMPLATE_URL);
  const pdfDoc = await PDFDocument.load(templateBytes);
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const page = pdfDoc.getPage(0);
  const c = acord25Coords;

  drawValue(page, font, data.certificateDate, c.certificateDate);
  drawValue(page, font, data.certificateNumber, c.certificateNumber);
  drawValue(page, font, data.revisionNumber, c.revisionNumber);

  const p = data.producer;
  drawValue(page, font, p.name, c.producer.name);
  drawValue(page, font, p.address.street, c.producer.addressLine1);
  drawValue(page, font, p.address.city, c.producer.city);
  drawValue(page, font, p.address.state, c.producer.state);
  drawValue(page, font, p.address.zip, c.producer.zip);
  drawValue(page, font, p.contactName, c.producer.contactName);
  drawValue(page, font, p.phone, c.producer.phone);
  drawValue(page, font, p.fax, c.producer.fax);
  drawValue(page, font, p.email, c.producer.email);

  const ins = data.insured;
  const insuredName = ins.dba ? `${ins.name} DBA ${ins.dba}` : ins.name;
  drawValue(page, font, insuredName, c.insured.name);
  drawValue(page, font, ins.address.street, c.insured.addressLine1);
  drawValue(page, font, ins.address.city, c.insured.city);
  drawValue(page, font, ins.address.state, c.insured.state);
  drawValue(page, font, ins.address.zip, c.insured.zip);

  for (const insurer of data.insurers) {
    const rowCoords = c.insurerRows[insurer.letter];
    if (!rowCoords) continue;
    drawValue(page, font, insurer.name, rowCoords.name);
    drawValue(page, font, insurer.naic, rowCoords.naic);
  }

  const otherRowIndex = { current: 0 };
  for (const line of data.acord25CoverageLines) {
    drawCoverageLine(page, font, line, otherRowIndex);
  }

  drawWrappedText(page, font, data.descriptionOfOperations, c.descriptionOfOperations);

  const holder = data.certificateHolder;
  drawValue(page, font, holder.name, c.certificateHolder.name);
  drawValue(page, font, holder.address.street, c.certificateHolder.addressLine1);
  const holderCityStateZip = [holder.address.city, holder.address.state, holder.address.zip]
    .filter(Boolean)
    .join(', ');
  drawValue(page, font, holderCityStateZip, c.certificateHolder.cityStateZip);

  return pdfDoc.save();
}
