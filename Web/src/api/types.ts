/** Kiểu dữ liệu theo DTO của backend. */

export interface Named {
  id: number;
  name: string;
}

export interface Paged {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface User {
  id: number;
  email: string;
  name: string;
  username: string | null;
  language: string;
  timezone: string;
  imageUrl: string | null;
  isActive: boolean;
  systemRole: 'user' | 'admin';
  group?: { id: number; name: string; role: 'admin' | 'member' } | null;
  groupId?: number | null;
  groupRole?: string | null;
}

export interface Member {
  id: number;
  name: string;
  username: string | null;
  imageUrl: string | null;
  role: 'admin' | 'member';
  joinedAt: string;
}

export interface Group {
  id: number;
  name: string;
  members: Member[];
}

export interface Food {
  id: number;
  name: string;
  imageUrl: string | null;
  category: Named;
  unit: Named;
}

export type Location = 'cool' | 'freezer' | 'other';
export const LOCATIONS: Record<Location, string> = { cool: 'Ngăn mát', freezer: 'Ngăn đông', other: 'Khác' };

export interface FridgeItem {
  id: number;
  food: Food;
  quantity: number;
  useWithin: string;
  location: Location;
  note: string | null;
  version: number;
  status: 'fresh' | 'expiring' | 'expired';
  daysLeft: number;
}

export interface FridgeSummary {
  total: number;
  expiring: number;
  expired: number;
}

export interface ShoppingItem {
  id: number;
  food: Food;
  quantity: number;
  status: 'pending' | 'bought';
  boughtQuantity: number | null;
  boughtAt: string | null;
  boughtBy: { id: number; name: string } | null;
}

export interface ShoppingSession {
  id: number;
  name: string;
  note: string | null;
  date: string;
  assignedTo: { id: number; name: string; username: string } | null;
  items: ShoppingItem[];
  progress: { total: number; bought: number; done: boolean };
}

export interface FoodRef {
  id: number;
  name: string;
  unit: string;
  imageUrl?: string | null;
}

export type MealName = 'sáng' | 'trưa' | 'tối';
export const MEALS: MealName[] = ['sáng', 'trưa', 'tối'];

export interface MealPlan {
  id: number;
  date: string;
  plannedAt: string;
  mealName: MealName;
  food: FoodRef;
  recipe: { id: number; name: string } | null;
}

export interface IngredientStatus {
  food: FoodRef;
  requiredQuantity: number | null;
  availableQuantity: number;
  missingQuantity: number;
  enough: boolean;
  expiringSoon: boolean;
}

export interface Recipe {
  id: number;
  name: string;
  description: string;
  htmlContent?: string;
  food: FoodRef;
  createdBy: { id: number; name: string } | null;
  ingredients: { food: FoodRef; quantity: number | null }[] | null;
}

export interface RecipeSuggestion {
  recipe: Recipe;
  totalIngredients: number;
  availableIngredients: number;
  canCook: boolean;
  expiringIngredients: string[];
  missing: IngredientStatus[];
}

export interface Notification {
  id: number;
  type: string;
  title: string;
  body: string;
  data: { fridgeItemId?: number; foodName?: string };
  read: boolean;
  createdAt: string;
}

export interface StatsReport {
  from: string;
  to: string;
  totals: Record<string, number>;
  wasteRate: number;
  shopping: { sessions: number; items: number; boughtItems: number };
  byFood: { foodName: string; unit: string; category: string; purchased: number; added: number; consumed: number; discarded: number }[];
  byCategory: { category: string; inEvents: number; consumeEvents: number; discardEvents: number }[];
  daily: { date: string; inEvents: number; consumeEvents: number; discardEvents: number }[];
}

export interface StockEvent {
  id: number;
  type: string;
  foodName: string;
  unit: string;
  quantity: number;
  note: string | null;
  actor: { id: number; name: string } | null;
  occurredAt: string;
}

export interface AuditLog {
  id: number;
  action: string;
  entityType: string | null;
  entityId: number | null;
  occurredAt: string;
  source: string;
  actor: { id: number; email: string; name: string } | null;
}

export interface AiConversation {
  id: number;
  title: string;
  updatedAt: string;
}

export interface AiMessage {
  id: number;
  role: 'user' | 'assistant' | 'tool';
  text: string;
  attachmentIds?: number[];
  toolCalls?: string[];
}

export interface AiAction {
  actionId: number;
  tool: string;
  riskLevel: 'read' | 'write' | 'destructive';
  summary: string;
  status: string;
  dependsOn: number | null;
  resultCode: string | null;
  expiresAt: string | null;
}

export interface AiSuggestion {
  id: number;
  type: string;
  title: string;
}
