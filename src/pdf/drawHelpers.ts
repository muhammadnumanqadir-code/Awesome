import { PDFFont, PDFPage, rgb } from 'pdf-lib';
import type { Point } from './coordinates25';

const DEFAULT_SIZE = 8;

export function drawValue(
  page: PDFPage,
  font: PDFFont,
  text: string | undefined | null,
  point: Point,
  size: number = DEFAULT_SIZE,
) {
  if (!text) return;
  page.drawText(text, {
    x: point.x,
    y: point.y,
    size,
    font,
    color: rgb(0, 0, 0),
  });
}

/** Draws a small "X" mark centered on the given point, for form checkboxes. */
export function drawCheckmark(page: PDFPage, font: PDFFont, point: Point, size: number = 8) {
  page.drawText('X', {
    x: point.x,
    y: point.y,
    size,
    font,
    color: rgb(0, 0, 0),
  });
}

/**
 * Draws text wrapped within maxWidth, starting at (x, y) and moving
 * downward by lineHeight per line. Returns the y coordinate after the last
 * line drawn.
 */
export function drawWrappedText(
  page: PDFPage,
  font: PDFFont,
  text: string | undefined | null,
  origin: Point & { maxWidth: number; lineHeight: number },
  size: number = DEFAULT_SIZE,
  maxLines: number = 20,
): number {
  if (!text) return origin.y;
  const words = text.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let current = '';
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (font.widthOfTextAtSize(candidate, size) > origin.maxWidth && current) {
      lines.push(current);
      current = word;
    } else {
      current = candidate;
    }
    if (lines.length >= maxLines) break;
  }
  if (current && lines.length < maxLines) lines.push(current);

  let y = origin.y;
  for (const line of lines) {
    page.drawText(line, { x: origin.x, y, size, font, color: rgb(0, 0, 0) });
    y -= origin.lineHeight;
  }
  return y;
}
