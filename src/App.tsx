import { useMemo, useState } from 'react';
import { emptyCertificateData, type CertificateData } from './types';
import { validateCertificateData, type ValidationError } from './validation';
import Step1ProducerInsured from './components/steps/Step1ProducerInsured';
import Step2Insurers from './components/steps/Step2Insurers';
import Step3Coverage from './components/steps/Step3Coverage';
import Step4Description from './components/steps/Step4Description';
import Step5Review from './components/steps/Step5Review';

const STEPS = [
  'Producer / Insured / Holder',
  'Insurers',
  'Coverage',
  'Description & Additional Interests',
  'Review & Generate',
];

export default function App() {
  const [step, setStep] = useState(0);
  const [data, setData] = useState<CertificateData>(emptyCertificateData());
  const [showErrors, setShowErrors] = useState(false);

  const errors: ValidationError[] = useMemo(() => validateCertificateData(data), [data]);

  function goNext() {
    if (step < STEPS.length - 1) setStep(step + 1);
  }
  function goBack() {
    if (step > 0) setStep(step - 1);
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>ACORD Certificate Autofill</h1>
        <p>Fill ACORD 25 &amp; ACORD 27 PDFs entirely in your browser. No data leaves this page.</p>
      </header>

      <nav className="steps-nav">
        {STEPS.map((label, i) => (
          <button key={label} className={i === step ? 'active' : ''} onClick={() => setStep(i)}>
            {i + 1}. {label}
          </button>
        ))}
      </nav>

      <div className="card">
        {step === 0 && <Step1ProducerInsured data={data} onChange={setData} errors={errors} />}
        {step === 1 && <Step2Insurers data={data} onChange={setData} errors={errors} />}
        {step === 2 && <Step3Coverage data={data} onChange={setData} errors={errors} />}
        {step === 3 && <Step4Description data={data} onChange={setData} errors={errors} />}
        {step === 4 && (
          <Step5Review data={data} errors={errors} showErrors={showErrors} setShowErrors={setShowErrors} />
        )}

        <div className="wizard-footer">
          <button className="secondary" onClick={goBack} disabled={step === 0}>
            Back
          </button>
          {step < STEPS.length - 1 && (
            <button className="primary" onClick={goNext}>
              Next
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
