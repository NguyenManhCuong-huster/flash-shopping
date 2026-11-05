import cron from 'node-cron';
import { query } from '../../db/pool.js';
import { registerHousekeeping } from '../notification/expiry.job.js';
import { aiConfigured } from './llm.gateway.js';
import { generateSuggestions } from './suggestion.worker.js';

export function startAiJobs() {
  // Hành động 'proposed' quá 15 phút -> expired (xác nhận sau đó trả 00421); gợi ý quá hạn -> expired
  registerHousekeeping(async () => {
    await query(`UPDATE ai_actions SET status = 'expired' WHERE status = 'proposed' AND expires_at < now()`);
    await query(`UPDATE ai_suggestions SET status = 'expired' WHERE status = 'pending' AND expires_at < now()`);
  });
  // Mỗi giờ kiểm tra nhóm nào đang ở 07:00 / 17:00 theo giờ địa phương
  cron.schedule('2 * * * *', () => {
    generateSuggestions().catch((err) => console.error('[ai] suggestion worker lỗi', err));
  });
  console.log(`[jobs] AI: ${aiConfigured() ? 'đã cấu hình LLM' : 'chưa có AI_API_KEY (chat trả 00413, gợi ý chủ động vẫn chạy)'}`);
}
