# Prompt for Lovable

Two ways to use this:

1. **Import via GitHub (recommended)** — in Lovable, choose "Import from
   GitHub", point it at this repository, then paste the prompt below into
   the chat so Lovable knows what to keep and what to restyle.
2. **Fresh Lovable project** — start a new project, then upload/paste in the
   files listed under "Files to preserve as-is" in `ENGINE.md` before using
   the prompt below.

---

## The prompt

```
This project is a browser-only tool that fills out ACORD 25 (Certificate of
Liability Insurance) and ACORD 27 (Evidence of Property Insurance) PDF forms
from data entered in a multi-step wizard, entirely client-side.

Read ENGINE.md first — it documents which files are the PDF-filling engine
(src/types.ts, src/validation.ts, src/pdf/**) and must be kept exactly as
they are. Do not rewrite the PDF-filling logic, the coordinate maps, or the
data model. Do not add a backend, Supabase, an API route, or auth — this
tool's entire value is that certificate data never leaves the browser, and
none of those are needed for it to work.

What I want you to do: rebuild and beautify the UI layer only
(src/components/**, src/App.tsx, src/index.css), using Tailwind and
shadcn/ui, while wiring it to the existing engine functions:

- Read/write a single CertificateData object (from src/types.ts), starting
  from emptyCertificateData().
- Call validateCertificateData(data) from src/validation.ts on every change
  and show inline errors next to the relevant field (error.field is a
  dotted path like "producer.address.zip" or
  "acord25CoverageLines.0.policyNumber").
- On the final step, call generateCertificates(data) from
  src/pdf/generate.ts, then let the user downloadFile() each PDF or
  downloadAsZip() all of them if there's more than one.

Keep the same five-step flow:
1. Producer / Insured / Certificate Holder
2. Insurers (repeatable, lettered A-F, name + 5-digit NAIC number)
3. Coverage (choose ACORD 25 and/or ACORD 27, then repeatable coverage
   lines per form)
4. Description & Additional Interests (ACORD 25 description of
   operations / ACORD 27 remarks + mortgagee/loss payee)
5. Review & Generate

Design direction: clean, modern, professional — this is used by insurance
agents and brokers, not consumers, so favor clarity and information density
over flashiness. A persistent step indicator/progress bar, clear section
grouping within each step, and a visible "runs entirely in your browser,
nothing is uploaded" trust message somewhere prominent (e.g. the header or
the final Generate step) would all fit well. Responsive down to tablet
width is enough; this isn't meant to be filled out on a phone.

Add pdf-lib and jszip as dependencies if they aren't already present -
that's what src/pdf/** relies on.
```

---

After Lovable finishes, sanity-check that `public/acord-templates/acord-25-template.pdf`
and `acord-27-template.pdf` still exist at those exact paths (Lovable's file
tree sometimes drops unrecognized static assets on import) — the app fetches
them by that relative path at generation time, so the fill step silently
fails without them.
