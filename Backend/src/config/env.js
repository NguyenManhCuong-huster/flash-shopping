import path from 'node:path';

const int = (v, d) => (v === undefined || v === '' ? d : Number.parseInt(v, 10));

export const env = {
  port: int(process.env.PORT, 3000),
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  databaseUrl: process.env.DATABASE_URL || 'postgres://dicho:dicho@localhost:5432/dicho',

  jwtAccessSecret: process.env.JWT_ACCESS_SECRET || 'dev-secret-change-me',
  jwtAccessTtl: process.env.JWT_ACCESS_TTL || '15m',
  refreshTokenTtlDays: int(process.env.REFRESH_TOKEN_TTL_DAYS, 30),
  verificationCodeTtlMinutes: int(process.env.VERIFICATION_CODE_TTL_MINUTES, 10),

  adminEmail: process.env.ADMIN_EMAIL || '',
  adminPassword: process.env.ADMIN_PASSWORD || '',
  adminName: process.env.ADMIN_NAME || 'Quản trị viên',

  smtp: {
    host: process.env.SMTP_HOST || '',
    port: int(process.env.SMTP_PORT, 1025),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.MAIL_FROM || 'Đi chợ tiện lợi <no-reply@dicho.local>',
  },

  uploadDir: path.resolve(process.env.UPLOAD_DIR || './uploads'),
  maxUploadBytes: int(process.env.MAX_UPLOAD_MB, 5) * 1024 * 1024,

  expiryReminderDays: int(process.env.EXPIRY_REMINDER_DAYS, 3),
  expiryJobCron: process.env.EXPIRY_JOB_CRON || '*/30 * * * *',
  pushRetryLimit: int(process.env.PUSH_RETRY_LIMIT, 3),
  fcmProjectId: process.env.FCM_PROJECT_ID || '',
  fcmServiceAccountFile: process.env.FCM_SERVICE_ACCOUNT_FILE || '',

  ai: {
    provider: process.env.AI_PROVIDER || 'anthropic',
    model: process.env.AI_MODEL || 'claude-opus-5-5',
    effort: process.env.AI_EFFORT || 'medium',
    apiKey: process.env.AI_API_KEY || '',
    baseUrl: process.env.AI_BASE_URL || undefined,
    maxToolCalls: int(process.env.AI_MAX_TOOL_CALLS, 8),
    turnTimeoutMs: int(process.env.AI_TURN_TIMEOUT_SECONDS, 60) * 1000,
  },
};
