import { Router } from 'express';
import { result, send } from '../../common/errors.js';
import { requireLeader } from '../../common/permissions.js';
import { requireAuth, requireSystemAdmin } from '../../middlewares/auth.js';
import { aiChatLimiter } from '../../middlewares/rateLimit.js';
import { imageUpload } from '../../middlewares/upload.js';
import * as AI from './ai.service.js';
import { generateSuggestions } from './suggestion.worker.js';

const h = (fn) => async (req, res) => send(res, await fn(req));
const auth = requireAuth;

const r = Router();

// ===== Hội thoại =====
r.post('/ai/conversation', auth, h((req) => AI.createConversation(req.ctx, req.body)));
r.get('/ai/conversation', auth, h((req) => AI.listConversations(req.ctx, req.query)));
r.put('/ai/conversation', auth, h((req) => AI.renameConversation(req.ctx, req.body)));
r.delete('/ai/conversation', auth, h((req) => AI.deleteConversation(req.ctx, req.body)));
r.get('/ai/conversation/:conversationId', auth, h((req) => AI.getConversation(req.ctx, req.params.conversationId, req.query)));

// ===== Chat (JSON hoặc SSE) =====
r.post('/ai/chat', auth, aiChatLimiter, (req, res) => AI.chat(req, res));
r.post('/ai/chat/cancel', auth, h((req) => AI.cancelTurn(req.ctx, req.body)));
r.post('/ai/attachment', auth, imageUpload('private/ai', '00415'), h((req) => AI.uploadAttachment(req.ctx, req.file)));

// ===== Hành động có kiểm soát =====
r.get('/ai/action', auth, h((req) => AI.listActions(req.ctx, req.query)));
r.post('/ai/action/confirm', auth, h((req) => AI.confirmActions(req.ctx, req.body)));
r.post('/ai/action/reject', auth, h((req) => AI.rejectActions(req.ctx, req.body)));
r.get('/ai/tools', auth, h((req) => AI.listTools(req.ctx)));

// ===== Cài đặt, gợi ý, sử dụng =====
r.get('/ai/settings', auth, h((req) => AI.getSettings(req.ctx)));
r.put('/ai/settings', auth, h((req) => AI.updateSettings(req.ctx, req.body)));
r.get('/ai/suggestion', auth, h((req) => AI.listSuggestions(req.ctx, req.query)));
r.post('/ai/suggestion/accept', auth, h((req) => AI.acceptSuggestion(req.ctx, req.body)));
r.post('/ai/suggestion/dismiss', auth, h((req) => AI.dismissSuggestion(req.ctx, req.body)));
// [BỔ SUNG] Trưởng nhóm chạy Suggestion Worker ngay (không chờ 07:00/17:00) - tiện kiểm thử
r.post(
  '/ai/suggestion/refresh',
  auth,
  h(async (req) => {
    requireLeader(req.ctx, '00096', '00104');
    const created = await generateSuggestions({ groupId: req.ctx.groupId, force: true });
    const list = await AI.listSuggestions(req.ctx, {});
    return result('00431', { created, suggestions: list.data.suggestions });
  }),
);
r.get('/ai/usage', auth, h((req) => AI.getUsage(req.ctx, req.query)));

// ===== Quản trị =====
r.get('/admin/ai/logs', auth, requireSystemAdmin, h((req) => AI.adminLogs(req.ctx, req.query)));

export default r;
