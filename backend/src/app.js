import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { env } from './config/env.js';
import healthRouter from './routes/health.js';
import authRouter from './routes/auth.js';
import resourcesRouter from './routes/resources.js';
import integrationsRouter from './routes/integrations.js';
import { notFound, errorHandler } from './middleware/errors.js';

const app = express();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const frontendPath = path.resolve(__dirname, '../../frontend');
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({
  origin(origin, callback) {
    if (!origin || env.corsOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Origin is not allowed by CORS.'));
  },
  credentials: false
}));
app.use(express.json({ limit: '1mb' }));
app.use('/api/', rateLimit({ windowMs: 60_000, limit: 120, standardHeaders: 'draft-8', legacyHeaders: false }));

app.use('/health', healthRouter);
// Serve the original frontend without changing its HTML/CSS/UI.
app.use(express.static(frontendPath));
app.get('/', (_req, res) => res.sendFile(path.join(frontendPath, 'index.html')));
app.use('/api/v1/auth', authRouter);
app.use('/api/v1', resourcesRouter);
app.use('/api/v1/integrations', integrationsRouter);
app.use(notFound);
app.use(errorHandler);

export default app;
