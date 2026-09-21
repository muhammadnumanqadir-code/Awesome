import type { CertificateData } from '../../types';
import type { ValidationError } from '../../validation';
import FieldError from '../FieldError';

interface Props {
  data: CertificateData;
  onChange: (data: CertificateData) => void;
  errors: ValidationError[];
}

export default function Step1ProducerInsured({ data, onChange, errors }: Props) {
  function set<K extends keyof CertificateData>(key: K, value: CertificateData[K]) {
    onChange({ ...data, [key]: value });
  }

  return (
    <div>
      <h2>Producer, Insured &amp; Certificate Holder</h2>

      <div className="section-title">Producer (Agency)</div>
      <div className="field-grid">
        <div className="field span-2">
          <label>Producer / Agency Name</label>
          <input
            value={data.producer.name}
            onChange={(e) => set('producer', { ...data.producer, name: e.target.value })}
          />
          <FieldError errors={errors} field="producer.name" />
        </div>
        <div className="field span-2">
          <label>Street Address</label>
          <input
            value={data.producer.address.street}
            onChange={(e) =>
              set('producer', { ...data.producer, address: { ...data.producer.address, street: e.target.value } })
            }
          />
          <FieldError errors={errors} field="producer.address.street" />
        </div>
        <div className="field">
          <label>City</label>
          <input
            value={data.producer.address.city}
            onChange={(e) =>
              set('producer', { ...data.producer, address: { ...data.producer.address, city: e.target.value } })
            }
          />
          <FieldError errors={errors} field="producer.address.city" />
        </div>
        <div className="field">
          <label>State</label>
          <input
            value={data.producer.address.state}
            onChange={(e) =>
              set('producer', { ...data.producer, address: { ...data.producer.address, state: e.target.value } })
            }
          />
          <FieldError errors={errors} field="producer.address.state" />
        </div>
        <div className="field">
          <label>ZIP</label>
          <input
            value={data.producer.address.zip}
            onChange={(e) =>
              set('producer', { ...data.producer, address: { ...data.producer.address, zip: e.target.value } })
            }
          />
          <FieldError errors={errors} field="producer.address.zip" />
        </div>
        <div className="field">
          <label>Contact Name</label>
          <input
            value={data.producer.contactName}
            onChange={(e) => set('producer', { ...data.producer, contactName: e.target.value })}
          />
        </div>
        <div className="field">
          <label>Phone</label>
          <input
            value={data.producer.phone}
            onChange={(e) => set('producer', { ...data.producer, phone: e.target.value })}
          />
          <FieldError errors={errors} field="producer.phone" />
        </div>
        <div className="field">
          <label>Fax</label>
          <input value={data.producer.fax} onChange={(e) => set('producer', { ...data.producer, fax: e.target.value })} />
        </div>
        <div className="field">
          <label>Email</label>
          <input
            value={data.producer.email}
            onChange={(e) => set('producer', { ...data.producer, email: e.target.value })}
          />
        </div>
      </div>

      <div className="section-title">Insured</div>
      <div className="field-grid">
        <div className="field">
          <label>Insured Name</label>
          <input value={data.insured.name} onChange={(e) => set('insured', { ...data.insured, name: e.target.value })} />
          <FieldError errors={errors} field="insured.name" />
        </div>
        <div className="field">
          <label>DBA (optional)</label>
          <input value={data.insured.dba} onChange={(e) => set('insured', { ...data.insured, dba: e.target.value })} />
        </div>
        <div className="field span-2">
          <label>Mailing Address</label>
          <input
            value={data.insured.address.street}
            onChange={(e) =>
              set('insured', { ...data.insured, address: { ...data.insured.address, street: e.target.value } })
            }
          />
          <FieldError errors={errors} field="insured.address.street" />
        </div>
        <div className="field">
          <label>City</label>
          <input
            value={data.insured.address.city}
            onChange={(e) =>
              set('insured', { ...data.insured, address: { ...data.insured.address, city: e.target.value } })
            }
          />
          <FieldError errors={errors} field="insured.address.city" />
        </div>
        <div className="field">
          <label>State</label>
          <input
            value={data.insured.address.state}
            onChange={(e) =>
              set('insured', { ...data.insured, address: { ...data.insured.address, state: e.target.value } })
            }
          />
          <FieldError errors={errors} field="insured.address.state" />
        </div>
        <div className="field">
          <label>ZIP</label>
          <input
            value={data.insured.address.zip}
            onChange={(e) =>
              set('insured', { ...data.insured, address: { ...data.insured.address, zip: e.target.value } })
            }
          />
          <FieldError errors={errors} field="insured.address.zip" />
        </div>
      </div>

      <div className="section-title">Certificate Holder</div>
      <div className="field-grid">
        <div className="field span-2">
          <label>Certificate Holder Name</label>
          <input
            value={data.certificateHolder.name}
            onChange={(e) => set('certificateHolder', { ...data.certificateHolder, name: e.target.value })}
          />
        </div>
        <div className="field span-2">
          <label>Street Address</label>
          <input
            value={data.certificateHolder.address.street}
            onChange={(e) =>
              set('certificateHolder', {
                ...data.certificateHolder,
                address: { ...data.certificateHolder.address, street: e.target.value },
              })
            }
          />
        </div>
        <div className="field">
          <label>City</label>
          <input
            value={data.certificateHolder.address.city}
            onChange={(e) =>
              set('certificateHolder', {
                ...data.certificateHolder,
                address: { ...data.certificateHolder.address, city: e.target.value },
              })
            }
          />
        </div>
        <div className="field">
          <label>State</label>
          <input
            value={data.certificateHolder.address.state}
            onChange={(e) =>
              set('certificateHolder', {
                ...data.certificateHolder,
                address: { ...data.certificateHolder.address, state: e.target.value },
              })
            }
          />
        </div>
        <div className="field">
          <label>ZIP</label>
          <input
            value={data.certificateHolder.address.zip}
            onChange={(e) =>
              set('certificateHolder', {
                ...data.certificateHolder,
                address: { ...data.certificateHolder.address, zip: e.target.value },
              })
            }
          />
        </div>
      </div>

      <div className="section-title">Certificate Metadata</div>
      <div className="field-grid cols-3">
        <div className="field">
          <label>Certificate Date (MM/DD/YYYY)</label>
          <input value={data.certificateDate} onChange={(e) => set('certificateDate', e.target.value)} placeholder="MM/DD/YYYY" />
        </div>
        <div className="field">
          <label>Certificate Number</label>
          <input value={data.certificateNumber} onChange={(e) => set('certificateNumber', e.target.value)} />
        </div>
        <div className="field">
          <label>Revision Number</label>
          <input value={data.revisionNumber} onChange={(e) => set('revisionNumber', e.target.value)} />
        </div>
      </div>
    </div>
  );
}
