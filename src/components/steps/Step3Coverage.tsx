import { useId } from 'react';
import type {
  Acord25CoverageLine,
  Acord25CoverageType,
  Acord27CoverageLine,
  CertificateData,
  InsurerLetter,
} from '../../types';
import type { ValidationError } from '../../validation';
import FieldError from '../FieldError';

interface Props {
  data: CertificateData;
  onChange: (data: CertificateData) => void;
  errors: ValidationError[];
}

const COVERAGE_TYPES: { value: Acord25CoverageType; label: string }[] = [
  { value: 'GENERAL_LIABILITY', label: 'General Liability' },
  { value: 'AUTOMOBILE_LIABILITY', label: 'Automobile Liability' },
  { value: 'UMBRELLA_EXCESS', label: 'Umbrella / Excess' },
  { value: 'WORKERS_COMP_EMPLOYERS_LIABILITY', label: "Workers Comp / Employers Liability" },
  { value: 'OTHER', label: 'Other' },
];

let idCounter = 0;
function newId() {
  idCounter += 1;
  return `line-${Date.now()}-${idCounter}`;
}

function newCoverageLine(letter: InsurerLetter): Acord25CoverageLine {
  return {
    id: newId(),
    insurerLetter: letter,
    coverageType: 'GENERAL_LIABILITY',
    policyNumber: '',
    effectiveDate: '',
    expirationDate: '',
    limits: {},
    additionalInsured: false,
    subrogationWaived: false,
  };
}

export default function Step3Coverage({ data, onChange, errors }: Props) {
  const uid = useId();

  function addCoverageLine() {
    const letter = data.insurers[0]?.letter ?? 'A';
    onChange({ ...data, acord25CoverageLines: [...data.acord25CoverageLines, newCoverageLine(letter)] });
  }

  function updateCoverageLine(index: number, patch: Partial<Acord25CoverageLine>) {
    const lines = data.acord25CoverageLines.map((l, i) => (i === index ? { ...l, ...patch } : l));
    onChange({ ...data, acord25CoverageLines: lines });
  }

  function removeCoverageLine(index: number) {
    onChange({ ...data, acord25CoverageLines: data.acord25CoverageLines.filter((_, i) => i !== index) });
  }

  function addAcord27Line() {
    const line: Acord27CoverageLine = { id: newId(), description: '', amountOfInsurance: '', deductible: '' };
    onChange({ ...data, acord27: { ...data.acord27, coverageLines: [...data.acord27.coverageLines, line] } });
  }

  function updateAcord27Line(index: number, patch: Partial<Acord27CoverageLine>) {
    const lines = data.acord27.coverageLines.map((l, i) => (i === index ? { ...l, ...patch } : l));
    onChange({ ...data, acord27: { ...data.acord27, coverageLines: lines } });
  }

  function removeAcord27Line(index: number) {
    onChange({
      ...data,
      acord27: { ...data.acord27, coverageLines: data.acord27.coverageLines.filter((_, i) => i !== index) },
    });
  }

  return (
    <div>
      <h2>Coverage</h2>

      <div className="checkbox-row">
        <input
          type="checkbox"
          id={`${uid}-gen25`}
          checked={data.generateAcord25}
          onChange={(e) => onChange({ ...data, generateAcord25: e.target.checked })}
        />
        <label htmlFor={`${uid}-gen25`}>Generate ACORD 25 (Certificate of Liability Insurance)</label>
      </div>
      <div className="checkbox-row" style={{ marginTop: 6 }}>
        <input
          type="checkbox"
          id={`${uid}-gen27`}
          checked={data.generateAcord27}
          onChange={(e) => onChange({ ...data, generateAcord27: e.target.checked })}
        />
        <label htmlFor={`${uid}-gen27`}>Generate ACORD 27 (Evidence of Property Insurance)</label>
      </div>
      <FieldError errors={errors} field="generate" />

      {data.generateAcord25 && (
        <>
          <div className="section-title">ACORD 25 Coverage Lines</div>
          <FieldError errors={errors} field="acord25CoverageLines" />
          {data.acord25CoverageLines.map((line, i) => (
            <div className="repeatable-item" key={line.id}>
              <button className="link remove-btn" onClick={() => removeCoverageLine(i)}>
                Remove
              </button>
              <div className="field-grid cols-4">
                <div className="field">
                  <label>Coverage Type</label>
                  <select
                    value={line.coverageType}
                    onChange={(e) => updateCoverageLine(i, { coverageType: e.target.value as Acord25CoverageType })}
                  >
                    {COVERAGE_TYPES.map((t) => (
                      <option key={t.value} value={t.value}>
                        {t.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="field">
                  <label>Insurer Letter</label>
                  <select
                    value={line.insurerLetter}
                    onChange={(e) => updateCoverageLine(i, { insurerLetter: e.target.value as InsurerLetter })}
                  >
                    {data.insurers.length === 0 && <option value={line.insurerLetter}>{line.insurerLetter}</option>}
                    {data.insurers.map((ins) => (
                      <option key={ins.letter} value={ins.letter}>
                        {ins.letter} — {ins.name || 'unnamed'}
                      </option>
                    ))}
                  </select>
                  <FieldError errors={errors} field={`acord25CoverageLines.${i}.insurerLetter`} />
                </div>
                <div className="field">
                  <label>Policy Number</label>
                  <input value={line.policyNumber} onChange={(e) => updateCoverageLine(i, { policyNumber: e.target.value })} />
                  <FieldError errors={errors} field={`acord25CoverageLines.${i}.policyNumber`} />
                </div>
                <div className="field">
                  <label>Effective Date</label>
                  <input
                    placeholder="MM/DD/YYYY"
                    value={line.effectiveDate}
                    onChange={(e) => updateCoverageLine(i, { effectiveDate: e.target.value })}
                  />
                  <FieldError errors={errors} field={`acord25CoverageLines.${i}.effectiveDate`} />
                </div>
                <div className="field">
                  <label>Expiration Date</label>
                  <input
                    placeholder="MM/DD/YYYY"
                    value={line.expirationDate}
                    onChange={(e) => updateCoverageLine(i, { expirationDate: e.target.value })}
                  />
                  <FieldError errors={errors} field={`acord25CoverageLines.${i}.expirationDate`} />
                </div>
                <div className="checkbox-row">
                  <input
                    type="checkbox"
                    id={`${line.id}-addl`}
                    checked={line.additionalInsured}
                    onChange={(e) => updateCoverageLine(i, { additionalInsured: e.target.checked })}
                  />
                  <label htmlFor={`${line.id}-addl`}>Additional Insured</label>
                </div>
                <div className="checkbox-row">
                  <input
                    type="checkbox"
                    id={`${line.id}-subr`}
                    checked={line.subrogationWaived}
                    onChange={(e) => updateCoverageLine(i, { subrogationWaived: e.target.checked })}
                  />
                  <label htmlFor={`${line.id}-subr`}>Waiver of Subrogation</label>
                </div>
              </div>

              {line.coverageType === 'GENERAL_LIABILITY' && (
                <div className="field-grid cols-3" style={{ marginTop: 10 }}>
                  <div className="field">
                    <label>Each Occurrence</label>
                    <input
                      value={line.limits.eachOccurrence ?? ''}
                      onChange={(e) => updateCoverageLine(i, { limits: { ...line.limits, eachOccurrence: e.target.value } })}
                    />
                  </div>
                  <div className="field">
                    <label>Damage to Rented Premises</label>
                    <input
                      value={line.limits.damageToRentedPremises ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, damageToRentedPremises: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Med Exp (any one person)</label>
                    <input
                      value={line.limits.medExp ?? ''}
                      onChange={(e) => updateCoverageLine(i, { limits: { ...line.limits, medExp: e.target.value } })}
                    />
                  </div>
                  <div className="field">
                    <label>Personal &amp; Adv Injury</label>
                    <input
                      value={line.limits.personalAdvInjury ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, personalAdvInjury: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>General Aggregate</label>
                    <input
                      value={line.limits.generalAggregate ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, generalAggregate: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Products - Comp/Op Agg</label>
                    <input
                      value={line.limits.productsCompOpAgg ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, productsCompOpAgg: e.target.value } })
                      }
                    />
                  </div>
                </div>
              )}

              {line.coverageType === 'AUTOMOBILE_LIABILITY' && (
                <div className="field-grid cols-3" style={{ marginTop: 10 }}>
                  <div className="field">
                    <label>Combined Single Limit</label>
                    <input
                      value={line.limits.combinedSingleLimit ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, combinedSingleLimit: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Bodily Injury (per person)</label>
                    <input
                      value={line.limits.bodilyInjuryPerPerson ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, bodilyInjuryPerPerson: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Bodily Injury (per accident)</label>
                    <input
                      value={line.limits.bodilyInjuryPerAccident ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, bodilyInjuryPerAccident: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Property Damage</label>
                    <input
                      value={line.limits.propertyDamage ?? ''}
                      onChange={(e) => updateCoverageLine(i, { limits: { ...line.limits, propertyDamage: e.target.value } })}
                    />
                  </div>
                </div>
              )}

              {line.coverageType === 'UMBRELLA_EXCESS' && (
                <div className="field-grid cols-3" style={{ marginTop: 10 }}>
                  <div className="field">
                    <label>Each Occurrence</label>
                    <input
                      value={line.limits.eachOccurrenceUmbrella ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, eachOccurrenceUmbrella: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Aggregate</label>
                    <input
                      value={line.limits.aggregateUmbrella ?? ''}
                      onChange={(e) => updateCoverageLine(i, { limits: { ...line.limits, aggregateUmbrella: e.target.value } })}
                    />
                  </div>
                </div>
              )}

              {line.coverageType === 'WORKERS_COMP_EMPLOYERS_LIABILITY' && (
                <div className="field-grid cols-3" style={{ marginTop: 10 }}>
                  <div className="field">
                    <label>E.L. Each Accident</label>
                    <input
                      value={line.limits.elEachAccident ?? ''}
                      onChange={(e) => updateCoverageLine(i, { limits: { ...line.limits, elEachAccident: e.target.value } })}
                    />
                  </div>
                  <div className="field">
                    <label>E.L. Disease - Ea Employee</label>
                    <input
                      value={line.limits.elDiseaseEaEmployee ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, elDiseaseEaEmployee: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>E.L. Disease - Policy Limit</label>
                    <input
                      value={line.limits.elDiseasePolicyLimit ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, elDiseasePolicyLimit: e.target.value } })
                      }
                    />
                  </div>
                </div>
              )}

              {line.coverageType === 'OTHER' && (
                <div className="field-grid cols-3" style={{ marginTop: 10 }}>
                  <div className="field span-2">
                    <label>Description</label>
                    <input
                      value={line.limits.otherDescription ?? ''}
                      onChange={(e) =>
                        updateCoverageLine(i, { limits: { ...line.limits, otherDescription: e.target.value } })
                      }
                    />
                  </div>
                  <div className="field">
                    <label>Limit</label>
                    <input
                      value={line.limits.otherLimit ?? ''}
                      onChange={(e) => updateCoverageLine(i, { limits: { ...line.limits, otherLimit: e.target.value } })}
                    />
                  </div>
                </div>
              )}
            </div>
          ))}
          <button className="secondary" onClick={addCoverageLine}>
            + Add Coverage Line
          </button>
        </>
      )}

      {data.generateAcord27 && (
        <>
          <div className="section-title">ACORD 27 Details</div>
          <div className="field-grid cols-3">
            <div className="field">
              <label>Insurer Name</label>
              <input
                value={data.acord27.insurerName}
                onChange={(e) => onChange({ ...data, acord27: { ...data.acord27, insurerName: e.target.value } })}
              />
              <FieldError errors={errors} field="acord27.insurerName" />
            </div>
            <div className="field">
              <label>Policy Number</label>
              <input
                value={data.acord27.policyNumber}
                onChange={(e) => onChange({ ...data, acord27: { ...data.acord27, policyNumber: e.target.value } })}
              />
              <FieldError errors={errors} field="acord27.policyNumber" />
            </div>
            <div className="field">
              <label>Cause of Loss</label>
              <select
                value={data.acord27.causeOfLoss ?? ''}
                onChange={(e) =>
                  onChange({
                    ...data,
                    acord27: { ...data.acord27, causeOfLoss: (e.target.value || null) as typeof data.acord27.causeOfLoss },
                  })
                }
              >
                <option value="">—</option>
                <option value="BASIC">Basic</option>
                <option value="BROAD">Broad</option>
                <option value="SPECIAL">Special</option>
              </select>
            </div>
            <div className="field">
              <label>Effective Date</label>
              <input
                placeholder="MM/DD/YYYY"
                value={data.acord27.effectiveDate}
                onChange={(e) => onChange({ ...data, acord27: { ...data.acord27, effectiveDate: e.target.value } })}
              />
              <FieldError errors={errors} field="acord27.effectiveDate" />
            </div>
            <div className="field">
              <label>Expiration Date</label>
              <input
                placeholder="MM/DD/YYYY"
                value={data.acord27.expirationDate}
                onChange={(e) => onChange({ ...data, acord27: { ...data.acord27, expirationDate: e.target.value } })}
              />
              <FieldError errors={errors} field="acord27.expirationDate" />
            </div>
            <div className="checkbox-row">
              <input
                type="checkbox"
                id={`${uid}-cut`}
                checked={data.acord27.continuedUntilTerminated}
                onChange={(e) =>
                  onChange({ ...data, acord27: { ...data.acord27, continuedUntilTerminated: e.target.checked } })
                }
              />
              <label htmlFor={`${uid}-cut`}>Continued until terminated</label>
            </div>
          </div>

          <div className="section-title">ACORD 27 Coverage / Perils / Forms</div>
          <FieldError errors={errors} field="acord27.coverageLines" />
          {data.acord27.coverageLines.map((line, i) => (
            <div className="repeatable-item" key={line.id}>
              <button className="link remove-btn" onClick={() => removeAcord27Line(i)}>
                Remove
              </button>
              <div className="field-grid cols-3">
                <div className="field span-2">
                  <label>Description (e.g. Building - Replacement Cost)</label>
                  <input value={line.description} onChange={(e) => updateAcord27Line(i, { description: e.target.value })} />
                </div>
                <div className="field">
                  <label>Amount of Insurance</label>
                  <input
                    value={line.amountOfInsurance}
                    onChange={(e) => updateAcord27Line(i, { amountOfInsurance: e.target.value })}
                  />
                </div>
                <div className="field">
                  <label>Deductible</label>
                  <input value={line.deductible} onChange={(e) => updateAcord27Line(i, { deductible: e.target.value })} />
                </div>
              </div>
            </div>
          ))}
          <button className="secondary" onClick={addAcord27Line}>
            + Add Coverage Line
          </button>
        </>
      )}
    </div>
  );
}
