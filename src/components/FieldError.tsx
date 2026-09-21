import type { ValidationError } from '../validation';

export function fieldError(errors: ValidationError[], field: string): string | undefined {
  return errors.find((e) => e.field === field)?.message;
}

export default function FieldError({ errors, field }: { errors: ValidationError[]; field: string }) {
  const message = fieldError(errors, field);
  if (!message) return null;
  return <div className="field-error">{message}</div>;
}
