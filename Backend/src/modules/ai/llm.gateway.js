import Anthropic from '@anthropic-ai/sdk';
import { env } from '../../config/env.js';

/**
 * LLM Gateway: bộ chuyển đổi tới nhà cung cấp LLM (Claude). Khóa API chỉ nằm ở server.
 * Luôn dùng streaming + finalMessage() để có text delta cho SSE và tránh timeout HTTP.
 */
let client = null;

export const aiConfigured = () => env.ai.provider === 'anthropic' && !!env.ai.apiKey;

function getClient() {
  if (!client) {
    client = new Anthropic({ apiKey: env.ai.apiKey, baseURL: env.ai.baseUrl, maxRetries: 2, timeout: env.ai.turnTimeoutMs });
  }
  return client;
}

// Các model hỗ trợ fallback phía server khi bị bộ lọc an toàn từ chối (stop_reason = refusal)
const FALLBACK_MODELS = /^claude-(opus-5|opus-5-5|fable-5-1|sonnet-5-5)$/;

export class ToolInputParseError extends Error {}

/**
 * Gọi model một bước của vòng lặp agent.
 * - system và tools phải giữ nguyên trong cả cuộc hội thoại (prompt cache + preserved thinking)
 * - messages chỉ được nối thêm, không sửa lượt cũ
 */
export async function callModel({ system, tools, messages, signal, onText }) {
  const betas = ['compact-2026-01-12'];
  const params = {
    model: env.ai.model,
    max_tokens: 16000,
    system,
    tools,
    messages,
    output_config: { effort: env.ai.effort },
    cache_control: { type: 'ephemeral' },
    // Hội thoại dài: tóm tắt phía server thay vì tự cắt lịch sử (không phá vỡ chuỗi thinking)
    context_management: { edits: [{ type: 'compact_20260112' }] },
  };
  if (FALLBACK_MODELS.test(env.ai.model)) {
    betas.push('server-side-fallback-2026-07-01');
    params.fallbacks = 'default';
  }
  params.betas = betas;

  for (let attempt = 0; ; attempt++) {
    const stream = getClient().beta.messages.stream(params, { signal });
    if (onText) stream.on('text', onText);
    try {
      return await stream.finalMessage();
    } catch (err) {
      // eager_input_streaming: JSON tham số công cụ không parse được => phát lại lượt (tối đa 2 lần).
      // Lỗi API (kể cả hủy/timeout) thì ném ra cho tầng trên xử lý.
      if (err instanceof Anthropic.APIError || signal?.aborted || attempt >= 2) throw err;
      console.warn('[ai] tool input không parse được, phát lại lượt');
    }
  }
}

export function usageOf(message) {
  const u = message?.usage ?? {};
  return {
    inputTokens: (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0),
    outputTokens: u.output_tokens ?? 0,
  };
}

export { Anthropic };
