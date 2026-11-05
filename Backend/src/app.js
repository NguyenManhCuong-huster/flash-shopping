import path from 'node:path';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/env.js';
import { globalLimiter } from './middlewares/rateLimit.js';
import { errorHandler, notFound } from './middlewares/errorHandler.js';
import routes from './routes.js';
import aiRoutes from './modules/ai/ai.routes.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors({ origin: env.corsOrigin === '*' ? true : env.corsOrigin.split(',') }));
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  app.use((req, res, next) => {
    const t = Date.now();
    res.on('finish', () => {
      if (req.path !== '/health') console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - t}ms`);
    });
    next();
  });
  app.use(globalLimiter);

  // Chỉ công khai ảnh hồ sơ và ảnh thực phẩm; ảnh gửi cho trợ lý AI nằm ở thư mục riêng tư
  for (const folder of ['avatars', 'foods']) {
    app.use(`/uploads/${folder}`, express.static(path.join(env.uploadDir, folder), { maxAge: '7d', index: false }));
  }
  app.get('/health', (_req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

  app.use(routes);
  app.use(aiRoutes);
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
