import { http, postStream, request, tokens } from './client';
import type {
  AiAction, AiConversation, AiMessage, AiSuggestion, AuditLog, Food, FridgeItem, FridgeSummary, Group, IngredientStatus,
  Location, MealName, MealPlan, Named, Notification, Paged, Recipe, RecipeSuggestion, ShoppingList, StatsReport, StockEvent, User,
} from './types';

/** Một hàm cho mỗi API của backend, nhóm theo nghiệp vụ. */

export const authApi = {
  async login(email: string, password: string) {
    const r = await http.post<{ user: User; accessToken: string; refreshToken: string }>('/user/login', { email, password });
    tokens.save(r.data.accessToken, r.data.refreshToken);
    return r.data.user;
  },
  register: (b: { email: string; password: string; name: string }) =>
    http.post<{ confirmToken: string }>('/user', { ...b, language: 'vi', timezone: Intl.DateTimeFormat().resolvedOptions().timeZone }).then((r) => r.data.confirmToken),
  sendCode: (email: string) => http.post<{ confirmToken?: string }>('/user/send-verification-code', { email }).then((r) => r.data?.confirmToken ?? null),
  verify: (code: string, token: string) => http.post('/user/verify-email', { code, token }),
  async logout() {
    try {
      await http.post('/user/logout', { refreshToken: tokens.refresh });
    } finally {
      tokens.clear();
    }
  },
};

export const userApi = {
  me: () => http.get<{ user: User }>('/user').then((d) => d.user),
  update: (fields: Record<string, string | undefined>, image?: File | null) => {
    const f = new FormData();
    Object.entries(fields).forEach(([k, v]) => v !== undefined && f.append(k, v));
    if (image) f.append('image', image);
    return http.put<{ user: User }>('/user', f).then((r) => r.data.user);
  },
  changePassword: (oldPassword: string, newPassword: string) => http.post('/user/change-password', { oldPassword, newPassword }),
  deleteAccount: () => http.del('/user'),
};

export const groupApi = {
  get: () => http.get<{ group: Group; myRole: string }>('/user/group'),
  create: (name?: string) => http.post<{ group: Group }>('/user/group', { name }),
  rename: (name: string) => http.put('/user/group', { name }),
  add: (username: string) => http.post('/user/group/add', { username }),
  remove: (username: string) => http.del('/user/group', { username }),
  leave: () => http.post('/user/group/leave'),
  transfer: (username: string) => http.put('/user/group/leader', { username }),
};

export const catalogApi = {
  categories: () => http.get<{ categories: Named[] }>('/food/category').then((d) => d.categories),
  units: () => http.get<{ units: Named[] }>('/food/unit').then((d) => d.units),
};

export const foodApi = {
  list: (q?: string, categoryId?: number, page = 1) => http.get<{ foods: Food[] } & Paged>('/food', { q, categoryId, page, limit: 50 }),
  save: (fields: Record<string, string | undefined>, image: File | null, update: boolean) => {
    const f = new FormData();
    Object.entries(fields).forEach(([k, v]) => v !== undefined && v !== '' && f.append(k, v));
    if (image) f.append('image', image);
    return update ? http.put('/food', f) : http.post('/food', f);
  },
  remove: (name: string) => http.del('/food', { name }),
};

export const fridgeApi = {
  list: (p: { q?: string; location?: Location | ''; expiringDays?: number; page?: number }) =>
    http.get<{ items: FridgeItem[]; summary: FridgeSummary } & Paged>('/fridge', { ...p, limit: 50 }),
  item: (id: number) => http.get<{ item: FridgeItem }>(`/fridge/item/${id}`).then((d) => d.item),
  add: (b: { foodName: string; quantity: number; useWithin: string; location: Location; note?: string }) => http.post('/fridge', b),
  update: (b: Record<string, unknown>) => http.put('/fridge', b),
  remove: (itemId: number) => http.del('/fridge', { itemId }),
  consume: (b: { itemId: number; quantity: number; type: 'consume' | 'discard'; version: number; note?: string }) =>
    http.post<{ item: FridgeItem | null; remaining: number; depleted: boolean }>('/fridge/consume', b),
};

export const shoppingApi = {
  lists: (p: { status?: 'open' | 'done'; assignedToMe?: boolean; page?: number }) =>
    http.get<{ lists: ShoppingList[] } & Paged>('/shopping/task', { status: p.status, assignedToMe: p.assignedToMe ? 'true' : undefined, page: p.page }),
  get: (id: number) => http.get<{ list: ShoppingList }>(`/shopping/${id}`).then((d) => d.list),
  create: (b: { name: string; date: string; assignToUsername?: string; note?: string }) => http.post<{ listId: number }>('/shopping', b),
  update: (b: Record<string, unknown>) => http.put('/shopping', b),
  remove: (listId: number) => http.del('/shopping', { listId }),
  addTasks: (listId: number, tasks: { foodName: string; quantity: number }[]) =>
    http.post<{ created: unknown[]; failed: { foodName: string; message: string }[] }>('/shopping/task', { listId, tasks }),
  updateTask: (b: { taskId: number; newFoodName?: string; newQuantity?: number }) => http.put('/shopping/task', b),
  removeTask: (taskId: number) => http.del('/shopping/task', { taskId }),
  /** Gửi lại cùng idempotencyKey khi thử lại => backend không cộng tồn kho lần 2. */
  purchase: (listId: number, items: unknown[], idempotencyKey: string) =>
    http.post<{ replayed: boolean }>('/shopping/purchase', { listId, items }, { 'Idempotency-Key': idempotencyKey }),
};

export const mealApi = {
  plans: (from: string, to: string) => http.get<{ plans: MealPlan[] }>('/meal', { from, to }).then((d) => d.plans),
  create: (b: { foodName?: string; recipeId?: number; timestamp: string; name: MealName }) => http.post('/meal', b),
  remove: (planId: number) => http.del('/meal', { planId }),
  ingredients: (q: { planId?: number; date?: string }) => http.get<{ ingredients: IngredientStatus[]; missing: IngredientStatus[] }>('/meal/ingredients', q),
  missingToShopping: (b: { planId?: number; date?: string; listId?: number }) => http.post<{ listId?: number }>('/meal/missing-to-shopping', b),
};

export const recipeApi = {
  list: (q?: string, page = 1) => http.get<{ recipes: Recipe[] } & Paged>('/recipe', { q, page }),
  get: (id: number) => http.get<{ recipe: Recipe }>(`/recipe/${id}`).then((d) => d.recipe),
  create: (b: Record<string, unknown>) => http.post<{ recipe: Recipe }>('/recipe', b),
  update: (b: Record<string, unknown>) => http.put<{ recipe: Recipe }>('/recipe', b),
  remove: (recipeId: number) => http.del('/recipe', { recipeId }),
  suggest: (onlyCookable: boolean) => http.get<{ suggestions: RecipeSuggestion[] }>('/recipe/suggest', { onlyCookable: onlyCookable ? 'true' : undefined }).then((d) => d.suggestions),
};

export const insightApi = {
  stats: (from: string, to: string) => http.get<StatsReport>('/stats', { from, to }),
  events: (from: string, to: string, type?: string, page = 1) => http.get<{ events: StockEvent[] } & Paged>('/stats/events', { from, to, type, page }),
  notifications: (page = 1, unreadOnly = false) =>
    http.get<{ notifications: Notification[]; unreadCount: number } & Paged>('/notification', { page, unreadOnly: unreadOnly ? 'true' : undefined }),
  markRead: (ids?: number[]) => http.put('/notification/read', ids ? { ids } : { all: true }),
};

export const adminApi = {
  users: (q?: string, page = 1) => http.get<{ users: User[] } & Paged>('/admin/users', { q, page }),
  updateUser: (b: { userId: number; isActive?: boolean; systemRole?: string }) => http.put('/admin/users', b),
  logs: (source?: string, page = 1) => http.get<{ logs: AuditLog[] } & Paged>('/admin/logs', { source, page }),
  catalog: (kind: 'category' | 'unit') => http.get<Record<string, Named[]>>(`/admin/${kind}`).then((d) => d[kind === 'category' ? 'categories' : 'units']),
  create: (kind: 'category' | 'unit', name: string) => http.post(`/admin/${kind}`, kind === 'category' ? { name } : { unitName: name }),
  rename: (kind: 'category' | 'unit', oldName: string, newName: string) => http.put(`/admin/${kind}`, { oldName, newName }),
  remove: (kind: 'category' | 'unit', name: string) => http.del(`/admin/${kind}`, kind === 'category' ? { name } : { unitName: name }),
};

export const aiApi = {
  conversations: () => http.get<{ conversations: AiConversation[] }>('/ai/conversation', { limit: 50 }).then((d) => d.conversations),
  conversation: (id: number) =>
    http.get<{ conversation: AiConversation; messages: AiMessage[]; actions: AiAction[] }>(`/ai/conversation/${id}`, { limit: 100 }),
  removeConversation: (conversationId: number) => http.del('/ai/conversation', { conversationId }),
  upload: (file: File) => {
    const f = new FormData();
    f.append('image', file);
    return http.post<{ attachmentId: number }>('/ai/attachment', f).then((r) => r.data.attachmentId);
  },
  chatStream: (b: { conversationId: number | null; message: string; attachmentIds: number[]; screen: string }, onEvent: (e: string, d: any) => void, signal?: AbortSignal) =>
    postStream('/ai/chat', { ...b, stream: true, clientContext: { screen: b.screen } }, onEvent, signal),
  cancel: (conversationId: number) => http.post('/ai/chat/cancel', { conversationId }),
  confirm: (actionIds: number[]) =>
    request<{ results: { actionId: number; status: string; message: string }[] }>('POST', '/ai/action/confirm', { body: { actionIds } }),
  reject: (actionIds: number[]) => http.post('/ai/action/reject', { actionIds }),
  settings: () => http.get<{ settings: { enabled: boolean; autoExecuteLevel: 'read' | 'write'; dailyTokenLimit: number }; aiAvailable: boolean }>('/ai/settings'),
  updateSettings: (b: { enabled?: boolean; autoExecuteLevel?: string }) => http.put('/ai/settings', b),
  usage: () => http.get<{ todayUsed: number; dailyTokenLimit: number }>('/ai/usage'),
  suggestions: () => http.get<{ suggestions: AiSuggestion[] }>('/ai/suggestion').then((d) => d.suggestions),
  refreshSuggestions: () => http.post<{ suggestions: AiSuggestion[] }>('/ai/suggestion/refresh').then((r) => r.data.suggestions),
  accept: (suggestionId: number) => http.post<{ conversationId: number }>('/ai/suggestion/accept', { suggestionId }).then((r) => r.data.conversationId),
  dismiss: (suggestionId: number) => http.post('/ai/suggestion/dismiss', { suggestionId }),
};
