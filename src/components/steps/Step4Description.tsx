import { useId } from 'react';
import { emptyAddress, type CertificateData, type MortgageeLossPayee } from '../../types';
import type { ValidationError } from '../../validation';

interface Props {
  data: CertificateData;
  onChange: (data: CertificateData) => void;
  errors: ValidationError[];
}

const MORTGAGEE_TYPES: { value: MortgageeLossPayee['type']; label: string }[] = [
  { value: 'MORTGAGEE', label: 'Mortgagee' },
  { value: 'LOSS_PAYEE', label: 'Loss Payee' },
  { value: 'LENDERS_LOSS_PAYABLE', label: "Lender's Loss Payable" },
  { value: 'ADDITIONAL_INSURED', label: 'Additional Insured' },
];

export default function Step4Description({ data, onChange }: Props) {
  const uid = useId();

  function setMortgagee(enabled: boolean) {
    if (!enabled) {
      onChange({ ...data, acord27: { ...data.acord27, mortgagee: null } });
      return;
    }
    const mortgagee: MortgageeLossPayee = {
      type: 'MORTGAGEE',
      name: '',
      address: emptyAddress(),
      loanNumber: '',
    };
    onChange({ ...data, acord27: { ...data.acord27, mortgagee } });
  }

  function updateMortgagee(patch: Partial<MortgageeLossPayee>) {
    if (!data.acord27.mortgagee) return;
    onChange({ ...data, acord27: { ...data.acord27, mortgagee: { ...data.acord27.mortgagee, ...patch } } });
  }

  return (
    <div>
      <h2>Description &amp; Additional Interests</h2>

      {data.generateAcord25 && (
        <>
          <div className="section-title">Description of Operations / Locations / Vehicles (ACORD 25)</div>
          <div className="field">
            <textarea
              value={data.descriptionOfOperations}
              onChange={(e) => onChange({ ...data, descriptionOfOperations: e.target.value })}
              rows={4}
            />
          </div>
          <p style={{ fontSize: 12, color: '#667' }}>
            Additional Insured / Waiver of Subrogation flags are set per coverage line on the previous step.
          </p>
        </>
      )}

      {data.generateAcord27 && (
        <>
          <div className="section-title">Remarks (ACORD 27)</div>
          <div className="field">
            <textarea
              value={data.acord27.remarks}
              onChange={(e) => onChange({ ...data, acord27: { ...data.acord27, remarks: e.target.value } })}
              rows={4}
            />
          </div>

          <div className="section-title">Additional Interest (Mortgagee / Loss Payee)</div>
          <div className="checkbox-row">
            <input
              type="checkbox"
              id={`${uid}-hasmort`}
              checked={data.acord27.mortgagee !== null}
              onChange={(e) => setMortgagee(e.target.checked)}
            />
            <label htmlFor={`${uid}-hasmort`}>Include a mortgagee / loss payee on ACORD 27</label>
          </div>

          {data.acord27.mortgagee && (
            <div className="field-grid" style={{ marginTop: 12 }}>
              <div className="field">
                <label>Type</label>
                <select
                  value={data.acord27.mortgagee.type}
                  onChange={(e) => updateMortgagee({ type: e.target.value as MortgageeLossPayee['type'] })}
                >
                  {MORTGAGEE_TYPES.map((t) => (
                    <option key={t.value} value={t.value}>
                      {t.label}
                    </option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label>Loan Number</label>
                <input value={data.acord27.mortgagee.loanNumber} onChange={(e) => updateMortgagee({ loanNumber: e.target.value })} />
              </div>
              <div className="field span-2">
                <label>Name</label>
                <input value={data.acord27.mortgagee.name} onChange={(e) => updateMortgagee({ name: e.target.value })} />
              </div>
              <div className="field span-2">
                <label>Street Address</label>
                <input
                  value={data.acord27.mortgagee.address.street}
                  onChange={(e) =>
                    updateMortgagee({ address: { ...data.acord27.mortgagee!.address, street: e.target.value } })
                  }
                />
              </div>
              <div className="field">
                <label>City</label>
                <input
                  value={data.acord27.mortgagee.address.city}
                  onChange={(e) => updateMortgagee({ address: { ...data.acord27.mortgagee!.address, city: e.target.value } })}
                />
              </div>
              <div className="field">
                <label>State</label>
                <input
                  value={data.acord27.mortgagee.address.state}
                  onChange={(e) => updateMortgagee({ address: { ...data.acord27.mortgagee!.address, state: e.target.value } })}
                />
              </div>
              <div className="field">
                <label>ZIP</label>
                <input
                  value={data.acord27.mortgagee.address.zip}
                  onChange={(e) => updateMortgagee({ address: { ...data.acord27.mortgagee!.address, zip: e.target.value } })}
                />
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
