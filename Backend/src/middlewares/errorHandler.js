import { AppError, send } from '../common/errors.js';

export function notFound(_req, res) {
  res.status(404).json({ code: '00599', message: 'Không tìm thấy API', data: null });
}

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, _next) {
  if (err instanceof AppError) return send(res, { code: err.code, data: err.data });
  if (err?.type === 'entity.parse.failed') return send(res, { code: '00025' });
  if (err?.type === 'entity.too.large') return send(res, { code: '00025' });
  console.error(`[error] ${req.method} ${req.originalUrl}`, err);
  return send(res, { code: '00008' });
}
