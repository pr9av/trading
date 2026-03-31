/**
 * Joi Validation Middleware — Blauplug Trading Platform
 * 
 * Usage in routes:
 *   const validate = require('../middleware/validate');
 *   router.post('/endpoint', validate(schema), handler);
 */

const { ValidationError } = require('../errors');

/**
 * Creates Express middleware that validates req.body (or req.query for GET)
 * against a Joi schema.
 * @param {Object} schema - Joi schema object with optional body, query, params keys
 */
const validate = (schema) => (req, res, next) => {
  const targets = {};
  if (schema.body) targets.body = req.body;
  if (schema.query) targets.query = req.query;
  if (schema.params) targets.params = req.params;

  for (const [key, value] of Object.entries(targets)) {
    const { error, value: validated } = schema[key].validate(value, {
      abortEarly: false,
      stripUnknown: true,
    });
    if (error) {
      const details = error.details.map((d) => d.message).join(', ');
      throw new ValidationError(`Validation failed: ${details}`, error.details);
    }
    req[key] = validated;
  }
  next();
};

module.exports = validate;
