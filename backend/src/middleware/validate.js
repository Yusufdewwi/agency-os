export function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse({ body: req.body, query: req.query, params: req.params });
    if (!result.success) {
      return res.status(422).json({
        error: { code: 'VALIDATION_ERROR', message: 'Request validation failed.', details: result.error.flatten() }
      });
    }
    req.validated = result.data;
    next();
  };
}
