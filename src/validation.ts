import type { CertificateData } from './types';

export interface ValidationError {
  field: string;
  message: string;
}

const DATE_RE = /^(0[1-9]|1[0-2])\/(0[1-9]|[12]\d|3[01])\/\d{4}$/;
const NAIC_RE = /^\d{5}$/;

export function isValidDate(value: string): boolean {
  return DATE_RE.test(value);
}

export function isValidNaic(value: string): boolean {
  return NAIC_RE.test(value);
}

function required(value: string | undefined | null, field: string, errors: ValidationError[], label: string) {
  if (!value || !value.trim()) {
    errors.push({ field, message: `${label} is required.` });
  }
}

export function validateCertificateData(data: CertificateData): ValidationError[] {
  const errors: ValidationError[] = [];

  required(data.producer.name, 'producer.name', errors, 'Producer name');
  required(data.producer.address.street, 'producer.address.street', errors, 'Producer address');
  required(data.producer.address.city, 'producer.address.city', errors, 'Producer city');
  required(data.producer.address.state, 'producer.address.state', errors, 'Producer state');
  required(data.producer.address.zip, 'producer.address.zip', errors, 'Producer ZIP');
  required(data.producer.phone, 'producer.phone', errors, 'Producer phone');

  required(data.insured.name, 'insured.name', errors, 'Insured name');
  required(data.insured.address.street, 'insured.address.street', errors, 'Insured address');
  required(data.insured.address.city, 'insured.address.city', errors, 'Insured city');
  required(data.insured.address.state, 'insured.address.state', errors, 'Insured state');
  required(data.insured.address.zip, 'insured.address.zip', errors, 'Insured ZIP');

  if (data.insurers.length === 0) {
    errors.push({ field: 'insurers', message: 'At least one insurer is required.' });
  }
  data.insurers.forEach((insurer, i) => {
    required(insurer.name, `insurers.${i}.name`, errors, `Insurer ${insurer.letter} name`);
    if (insurer.naic && !isValidNaic(insurer.naic)) {
      errors.push({
        field: `insurers.${i}.naic`,
        message: `Insurer ${insurer.letter} NAIC number must be exactly 5 digits.`,
      });
    }
  });

  if (data.generateAcord25) {
    if (data.acord25CoverageLines.length === 0) {
      errors.push({ field: 'acord25CoverageLines', message: 'At least one coverage line is required for ACORD 25.' });
    }
    data.acord25CoverageLines.forEach((line, i) => {
      required(line.policyNumber, `acord25CoverageLines.${i}.policyNumber`, errors, `Coverage line ${i + 1} policy number`);
      if (line.effectiveDate && !isValidDate(line.effectiveDate)) {
        errors.push({
          field: `acord25CoverageLines.${i}.effectiveDate`,
          message: `Coverage line ${i + 1} effective date must be MM/DD/YYYY.`,
        });
      } else {
        required(line.effectiveDate, `acord25CoverageLines.${i}.effectiveDate`, errors, `Coverage line ${i + 1} effective date`);
      }
      if (line.expirationDate && !isValidDate(line.expirationDate)) {
        errors.push({
          field: `acord25CoverageLines.${i}.expirationDate`,
          message: `Coverage line ${i + 1} expiration date must be MM/DD/YYYY.`,
        });
      } else {
        required(line.expirationDate, `acord25CoverageLines.${i}.expirationDate`, errors, `Coverage line ${i + 1} expiration date`);
      }
      const insurerExists = data.insurers.some((ins) => ins.letter === line.insurerLetter);
      if (!insurerExists) {
        errors.push({
          field: `acord25CoverageLines.${i}.insurerLetter`,
          message: `Coverage line ${i + 1} references insurer ${line.insurerLetter}, which has not been added.`,
        });
      }
    });
  }

  if (data.generateAcord27) {
    required(data.acord27.policyNumber, 'acord27.policyNumber', errors, 'ACORD 27 policy number');
    required(data.acord27.insurerName, 'acord27.insurerName', errors, 'ACORD 27 insurer name');
    if (data.acord27.effectiveDate && !isValidDate(data.acord27.effectiveDate)) {
      errors.push({ field: 'acord27.effectiveDate', message: 'ACORD 27 effective date must be MM/DD/YYYY.' });
    } else {
      required(data.acord27.effectiveDate, 'acord27.effectiveDate', errors, 'ACORD 27 effective date');
    }
    if (data.acord27.expirationDate && !isValidDate(data.acord27.expirationDate)) {
      errors.push({ field: 'acord27.expirationDate', message: 'ACORD 27 expiration date must be MM/DD/YYYY.' });
    } else {
      required(data.acord27.expirationDate, 'acord27.expirationDate', errors, 'ACORD 27 expiration date');
    }
    if (data.acord27.coverageLines.length === 0) {
      errors.push({ field: 'acord27.coverageLines', message: 'At least one coverage line is required for ACORD 27.' });
    }
  }

  if (!data.generateAcord25 && !data.generateAcord27) {
    errors.push({ field: 'generate', message: 'Select at least one certificate to generate.' });
  }

  return errors;
}
