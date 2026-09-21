import { PDFDocument, StandardFonts } from 'pdf-lib';
import type { CertificateData } from '../types';
import { acord27Coords } from './coordinates27';
import { drawValue, drawCheckmark, drawWrappedText } from './drawHelpers';

const TEMPLATE_URL = '/acord-templates/acord-27-template.pdf';

async function loadTemplateBytes(url: string): Promise<ArrayBuffer> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load PDF template at ${url}: ${res.status}`);
  return res.arrayBuffer();
}

export async function fillAcord27(data: CertificateData): Promise<Uint8Array> {
  const templateBytes = await loadTemplateBytes(TEMPLATE_URL);
  const pdfDoc = await PDFDocument.load(templateBytes);
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const page = pdfDoc.getPage(0);
  const c = acord27Coords;
  const a27 = data.acord27;

  drawValue(page, font, data.certificateDate, c.date);

  const p = data.producer;
  drawValue(page, font, p.name, c.agency.name);
  drawValue(page, font, p.address.street, c.agency.addressLine1);
  const agencyCityStateZip = [p.address.city, p.address.state, p.address.zip].filter(Boolean).join(', ');
  drawValue(page, font, agencyCityStateZip, c.agency.cityStateZip);
  drawValue(page, font, p.phone, c.agency.phone);
  drawValue(page, font, p.fax, c.agency.fax);
  drawValue(page, font, p.email, c.agency.email);

  drawValue(page, font, a27.insurerName, c.companyName);

  const ins = data.insured;
  const insuredName = ins.dba ? `${ins.name} DBA ${ins.dba}` : ins.name;
  drawValue(page, font, insuredName, c.insured.name);
  drawValue(page, font, ins.address.street, c.insured.addressLine1);
  const insuredCityStateZip = [ins.address.city, ins.address.state, ins.address.zip].filter(Boolean).join(', ');
  drawValue(page, font, insuredCityStateZip, c.insured.cityStateZip);

  drawValue(page, font, a27.policyNumber, c.policyNumber);
  drawValue(page, font, a27.effectiveDate, c.effectiveDate);
  drawValue(page, font, a27.expirationDate, c.expirationDate);
  if (a27.continuedUntilTerminated) drawCheckmark(page, font, c.continuedUntilTerminatedCheckbox);

  drawWrappedText(page, font, a27.propertyLocationDescription, c.propertyLocationDescription);

  if (a27.causeOfLoss === 'BASIC') drawCheckmark(page, font, c.perilsCheckboxes.basic);
  if (a27.causeOfLoss === 'BROAD') drawCheckmark(page, font, c.perilsCheckboxes.broad);
  if (a27.causeOfLoss === 'SPECIAL') drawCheckmark(page, font, c.perilsCheckboxes.special);

  a27.coverageLines.forEach((line, i) => {
    const y = c.coverageLineStartY - i * c.coverageLineStep;
    drawValue(page, font, line.description, { x: c.coverageColumns.description, y });
    drawValue(page, font, line.amountOfInsurance, { x: c.coverageColumns.amount, y });
    drawValue(page, font, line.deductible, { x: c.coverageColumns.deductible, y });
  });

  drawWrappedText(page, font, a27.remarks, c.remarks);

  if (a27.mortgagee) {
    const m = a27.mortgagee;
    const ai = c.additionalInterest;
    if (m.type === 'ADDITIONAL_INSURED') drawCheckmark(page, font, ai.additionalInsuredCheckbox);
    if (m.type === 'LENDERS_LOSS_PAYABLE') drawCheckmark(page, font, ai.lendersLossPayableCheckbox);
    if (m.type === 'LOSS_PAYEE') drawCheckmark(page, font, ai.lossPayeeCheckbox);
    if (m.type === 'MORTGAGEE') drawCheckmark(page, font, ai.mortgageeCheckbox);
    drawValue(page, font, m.name, ai.name);
    drawValue(page, font, m.address.street, ai.addressLine1);
    const cityStateZip = [m.address.city, m.address.state, m.address.zip].filter(Boolean).join(', ');
    drawValue(page, font, cityStateZip, ai.cityStateZip);
    drawValue(page, font, m.loanNumber, ai.loanNumber);
    // The loan number also appears in the header block, next to POLICY NUMBER.
    drawValue(page, font, m.loanNumber, c.loanNumber);
  }

  return pdfDoc.save();
}
