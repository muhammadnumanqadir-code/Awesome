import JSZip from 'jszip';
import type { CertificateData } from '../types';
import { fillAcord25 } from './fillAcord25';
import { fillAcord27 } from './fillAcord27';

export interface GeneratedFile {
  filename: string;
  bytes: Uint8Array;
}

export async function generateCertificates(data: CertificateData): Promise<GeneratedFile[]> {
  const files: GeneratedFile[] = [];
  const safeName = (data.insured.name || 'certificate').replace(/[^a-z0-9]+/gi, '_');

  if (data.generateAcord25) {
    const bytes = await fillAcord25(data);
    files.push({ filename: `ACORD25_${safeName}.pdf`, bytes });
  }
  if (data.generateAcord27) {
    const bytes = await fillAcord27(data);
    files.push({ filename: `ACORD27_${safeName}.pdf`, bytes });
  }
  return files;
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export function downloadFile(file: GeneratedFile) {
  downloadBlob(new Blob([file.bytes as BlobPart], { type: 'application/pdf' }), file.filename);
}

export async function downloadAsZip(files: GeneratedFile[], zipName = 'certificates.zip') {
  const zip = new JSZip();
  for (const file of files) {
    zip.file(file.filename, file.bytes);
  }
  const blob = await zip.generateAsync({ type: 'blob' });
  downloadBlob(blob, zipName);
}
