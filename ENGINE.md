# ACORD Autofill Engine — Reference

This file documents the framework-agnostic "engine" of this project: the part
that knows how to validate certificate data and fill the ACORD 25 / ACORD 27
PDFs. It has no dependency on the current UI, so it's the part to **keep
unchanged** when rebuilding the interface (e.g. in Lovable) — only the files
under `src/components/`, `App.tsx`, and `index.css` are UI and are meant to
be replaced/restyled.

## Files to preserve as-is

```
src/types.ts              Data model (CertificateData and friends)
src/validation.ts         validateCertificateData()
src/pdf/coordinates25.ts  Field x/y positions on the ACORD 25 template
src/pdf/coordinates27.ts  Field x/y positions on the ACORD 27 template
src/pdf/drawHelpers.ts    Low-level pdf-lib draw helpers
src/pdf/fillAcord25.ts    fillAcord25()
src/pdf/fillAcord27.ts    fillAcord27()
src/pdf/generate.ts       generateCertificates(), downloadFile(), downloadAsZip()
public/acord-templates/   The two blank template PDFs (fetched at runtime)
```

The templates are fetched with a plain `fetch('/acord-templates/acord-25-template.pdf')`
at generation time, so `public/acord-templates/*.pdf` must ship at those exact
paths in whatever project imports this code.

## Required dependencies

```
pdf-lib   - fills/flattens the PDFs, runs entirely in the browser
jszip     - bundles multiple generated PDFs into one .zip download
```

Neither one talks to a network. No backend, no API, no database is involved
in generating a certificate — that's a deliberate design constraint, not an
oversight. See "Do not add a backend" below.

## Data model (`src/types.ts`)

`CertificateData` is the single object the whole wizard reads from and
writes to. Start a new form with `emptyCertificateData()`. Shape summary:

```ts
interface CertificateData {
  producer: Producer;                       // agency info
  insured: Insured;                         // name, DBA, address
  certificateHolder: CertificateHolder;
  insurers: Insurer[];                      // up to 6, lettered A-F
  certificateNumber: string;
  revisionNumber: string;
  certificateDate: string;                  // MM/DD/YYYY
  acord25CoverageLines: Acord25CoverageLine[];
  descriptionOfOperations: string;
  acord27: Acord27Data;
  generateAcord25: boolean;
  generateAcord27: boolean;
}
```

See `src/types.ts` for the full nested shapes (`Acord25CoverageLine` has a
`coverageType` discriminant of `GENERAL_LIABILITY | AUTOMOBILE_LIABILITY |
UMBRELLA_EXCESS | WORKERS_COMP_EMPLOYERS_LIABILITY | OTHER`, each with its
own limits/checkboxes).

## Validation (`src/validation.ts`)

```ts
function validateCertificateData(data: CertificateData): ValidationError[]
// ValidationError = { field: string; message: string }
```

Call this on every change (or at least before enabling the Generate button).
An empty array means the data is generation-ready. `field` values are dotted
paths like `producer.address.zip` or `acord25CoverageLines.0.policyNumber`,
meant to be matched against form fields to show inline errors.

Also exports `isValidDate(value: string): boolean` (MM/DD/YYYY) and
`isValidNaic(value: string): boolean` (exactly 5 digits) if you want to
validate a single field as the user types.

## Generation (`src/pdf/generate.ts`)

```ts
interface GeneratedFile { filename: string; bytes: Uint8Array }

async function generateCertificates(data: CertificateData): Promise<GeneratedFile[]>
function downloadFile(file: GeneratedFile): void
async function downloadAsZip(files: GeneratedFile[], zipName?: string): Promise<void>
```

`generateCertificates` fills whichever of ACORD 25 / ACORD 27 the data asks
for (`generateAcord25` / `generateAcord27`) and returns their bytes — it does
not touch the DOM. `downloadFile` / `downloadAsZip` are the only two
functions that trigger a browser download (via an object URL), so they're
the ones to call from a "Download" button.

Typical wiring from a UI component:

```ts
import { generateCertificates, downloadFile, downloadAsZip } from './pdf/generate';
import { validateCertificateData } from './validation';

const errors = validateCertificateData(data);
if (errors.length === 0) {
  const files = await generateCertificates(data);
  // show files, then either:
  downloadFile(files[0]);
  // or, if there's more than one:
  await downloadAsZip(files);
}
```

## Coordinate maps (`src/pdf/coordinates25.ts` / `coordinates27.ts`)

Every field's pixel position on the page is a named constant here, in PDF
points with the origin at the bottom-left (pdf-lib's convention). Comments
mark each one `CONFIRMED` (read directly off a real filled sample of that
exact form revision) or `ESTIMATED` (interpolated from surrounding grid
spacing because that field was blank in the sample). If a generated PDF ever
looks slightly misaligned, this is the one place to nudge — no other file
needs to change.

## Do not add a backend

The reason this exists as a client-only tool is so insured/policy data never
leaves the person's browser. When extending the UI (in Lovable or anywhere
else), do not introduce Supabase, an API route, analytics that captures form
values, or auth gating the wizard — none of that is needed for what this
does, and adding it silently changes the privacy posture of the tool.
