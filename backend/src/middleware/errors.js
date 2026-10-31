export function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found.' } });
}

export function errorHandler(err, req, res, next) {
  if (res.headersSent) return next(err);
  const status = Number(err.status || 500);
  const code = err.code || 'INTERNAL_ERROR';
  if (status >= 500) console.error(err);
  res.status(status).json({
    error: {
      code,
      message: status >= 500 && process.env.NODE_ENV === 'production'
        ? 'An unexpected server error occurred.'
        : (err.message || 'Request failed.')
    }
  });
}
