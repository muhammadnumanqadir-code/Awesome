import { useState } from 'react';
import type { CertificateData } from '../../types';
import type { ValidationError } from '../../validation';
import { generateCertificates, downloadFile, downloadAsZip, type GeneratedFile } from '../../pdf/generate';

interface Props {
  data: CertificateData;
  errors: ValidationError[];
  showErrors: boolean;
  setShowErrors: (show: boolean) => void;
}

export default function Step5Review({ data, errors, showErrors, setShowErrors }: Props) {
  const [generating, setGenerating] = useState(false);
  const [files, setFiles] = useState<GeneratedFile[]>([]);
  const [generateError, setGenerateError] = useState<string | null>(null);

  async function handleGenerate() {
    setShowErrors(true);
    if (errors.length > 0) return;
    setGenerating(true);
    setGenerateError(null);
    try {
      const result = await generateCertificates(data);
      setFiles(result);
    } catch (err) {
      setGenerateError(err instanceof Error ? err.message : 'Failed to generate PDFs.');
    } finally {
      setGenerating(false);
    }
  }

  return (
    <div>
      <h2>Review &amp; Generate</h2>

      {showErrors && errors.length > 0 && (
        <div className="error-summary">
          <strong>Please fix the following before generating:</strong>
          <ul>
            {errors.map((e) => (
              <li key={e.field}>{e.message}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="review-block">
        <h3>Producer</h3>
        <table>
          <tbody>
            <tr>
              <td className="label">Name</td>
              <td>{data.producer.name || '—'}</td>
            </tr>
            <tr>
              <td className="label">Address</td>
              <td>
                {data.producer.address.street}, {data.producer.address.city}, {data.producer.address.state}{' '}
                {data.producer.address.zip}
              </td>
            </tr>
            <tr>
              <td className="label">Phone / Email</td>
              <td>
                {data.producer.phone} / {data.producer.email}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="review-block">
        <h3>Insured</h3>
        <table>
          <tbody>
            <tr>
              <td className="label">Name</td>
              <td>
                {data.insured.name} {data.insured.dba && `DBA ${data.insured.dba}`}
              </td>
            </tr>
            <tr>
              <td className="label">Address</td>
              <td>
                {data.insured.address.street}, {data.insured.address.city}, {data.insured.address.state}{' '}
                {data.insured.address.zip}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="review-block">
        <h3>Insurers</h3>
        <table>
          <tbody>
            {data.insurers.map((ins) => (
              <tr key={ins.letter}>
                <td className="label">Insurer {ins.letter}</td>
                <td>
                  {ins.name} (NAIC {ins.naic || '—'})
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {data.generateAcord25 && (
        <div className="review-block">
          <h3>ACORD 25 Coverage Lines</h3>
          <table>
            <tbody>
              {data.acord25CoverageLines.map((line) => (
                <tr key={line.id}>
                  <td className="label">
                    {line.insurerLetter} — {line.coverageType.replace(/_/g, ' ')}
                  </td>
                  <td>
                    Policy {line.policyNumber || '—'} ({line.effectiveDate || '—'} to {line.expirationDate || '—'})
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {data.generateAcord27 && (
        <div className="review-block">
          <h3>ACORD 27</h3>
          <table>
            <tbody>
              <tr>
                <td className="label">Insurer / Policy</td>
                <td>
                  {data.acord27.insurerName} — {data.acord27.policyNumber || '—'}
                </td>
              </tr>
              <tr>
                <td className="label">Policy Period</td>
                <td>
                  {data.acord27.effectiveDate || '—'} to {data.acord27.expirationDate || '—'}
                </td>
              </tr>
              <tr>
                <td className="label">Coverage Lines</td>
                <td>{data.acord27.coverageLines.length}</td>
              </tr>
            </tbody>
          </table>
        </div>
      )}

      <button className="primary" onClick={handleGenerate} disabled={generating}>
        {generating ? 'Generating…' : 'Generate PDF(s)'}
      </button>

      {generateError && <div className="field-error" style={{ marginTop: 10 }}>{generateError}</div>}

      {files.length > 0 && (
        <div className="generated-files">
          <h3>Generated Files</h3>
          <ul>
            {files.map((file) => (
              <li key={file.filename}>
                {file.filename}{' '}
                <button className="link" onClick={() => downloadFile(file)}>
                  Download
                </button>
              </li>
            ))}
          </ul>
          {files.length > 1 && (
            <button className="secondary" onClick={() => downloadAsZip(files)}>
              Download All as ZIP
            </button>
          )}
        </div>
      )}
    </div>
  );
}
