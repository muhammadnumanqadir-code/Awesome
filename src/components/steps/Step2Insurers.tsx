import type { CertificateData, Insurer, InsurerLetter } from '../../types';
import type { ValidationError } from '../../validation';
import FieldError from '../FieldError';

const LETTERS: InsurerLetter[] = ['A', 'B', 'C', 'D', 'E', 'F'];

interface Props {
  data: CertificateData;
  onChange: (data: CertificateData) => void;
  errors: ValidationError[];
}

export default function Step2Insurers({ data, onChange, errors }: Props) {
  function nextLetter(): InsurerLetter | null {
    const used = new Set(data.insurers.map((i) => i.letter));
    return LETTERS.find((l) => !used.has(l)) ?? null;
  }

  function addInsurer() {
    const letter = nextLetter();
    if (!letter) return;
    const insurer: Insurer = { letter, name: '', naic: '' };
    onChange({ ...data, insurers: [...data.insurers, insurer] });
  }

  function updateInsurer(index: number, patch: Partial<Insurer>) {
    const insurers = data.insurers.map((ins, i) => (i === index ? { ...ins, ...patch } : ins));
    onChange({ ...data, insurers });
  }

  function removeInsurer(index: number) {
    onChange({ ...data, insurers: data.insurers.filter((_, i) => i !== index) });
  }

  return (
    <div>
      <h2>Insurers</h2>
      <p>Add each insurer providing coverage on this certificate. Letters A-F match the ACORD form grid.</p>
      <FieldError errors={errors} field="insurers" />

      {data.insurers.map((insurer, i) => (
        <div className="repeatable-item" key={insurer.letter}>
          <button className="link remove-btn" onClick={() => removeInsurer(i)}>
            Remove
          </button>
          <div className="field-grid cols-3">
            <div className="field">
              <label>Letter</label>
              <input value={insurer.letter} disabled />
            </div>
            <div className="field span-2">
              <label>Insurer Name</label>
              <input value={insurer.name} onChange={(e) => updateInsurer(i, { name: e.target.value })} />
              <FieldError errors={errors} field={`insurers.${i}.name`} />
            </div>
            <div className="field">
              <label>NAIC Number (5 digits)</label>
              <input value={insurer.naic} onChange={(e) => updateInsurer(i, { naic: e.target.value })} maxLength={5} />
              <FieldError errors={errors} field={`insurers.${i}.naic`} />
            </div>
          </div>
        </div>
      ))}

      <button className="secondary" onClick={addInsurer} disabled={data.insurers.length >= LETTERS.length}>
        + Add Insurer
      </button>
    </div>
  );
}
