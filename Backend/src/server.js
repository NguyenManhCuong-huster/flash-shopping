import { env } from './config/env.js';
import { pool } from './db/pool.js';
import { migrate } from './db/migrate.js';
import { createApp } from './app.js';
import { ensureAdminAccount } from './modules/auth/auth.service.js';
import { startExpiryJobs } from './modules/notification/expiry.job.js';
import { startAiJobs } from './modules/ai/ai.jobs.js';

async function main() {
  if (env.nodeEnv === 'production' && env.jwtAccessSecret.length < 32) {
    console.warn('[warn] JWT_ACCESS_SECRET quá ngắn, hãy đặt chuỗi ngẫu nhiên >= 32 ký tự');
  }
  await migrate();
  await ensureAdminAccount();
  startExpiryJobs();
  startAiJobs();

  const server = createApp().listen(env.port, () => {
    console.log(`[server] Đi chợ tiện lợi API chạy tại http://0.0.0.0:${env.port}`);
  });

  const shutdown = () => {
    console.log('[server] đang tắt...');
    server.close(() => pool.end().finally(() => process.exit(0)));
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  console.error('[server] khởi động thất bại', err);
  process.exit(1);
});
