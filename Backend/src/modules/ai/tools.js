import { query } from '../../db/pool.js';
import { AppError } from '../../common/errors.js';
import { requireMember } from '../../common/permissions.js';
import * as User from '../user/user.service.js';
import * as Group from '../group/group.service.js';
import { CategoryService, UnitService } from '../admin/catalog.service.js';
import * as Food from '../food/food.service.js';
import { findFoodByName } from '../food/food.repo.js';
import * as Fridge from '../fridge/fridge.service.js';
import * as Shopping from '../shopping/shopping.service.js';
import * as Meal from '../meal/meal.service.js';
import * as Recipe from '../recipe/recipe.service.js';
import * as Stats from '../stats/stats.service.js';

/**
 * Tool Registry. Chính sách:
 *  - AI chỉ được XEM và TẠO dữ liệu; không có công cụ sửa/xóa (người dùng tự làm trong ứng dụng).
 *  - AI không thấy ID: tham số tham chiếu bằng TÊN (thực phẩm, danh sách, công thức), kết quả được
 *    rút gọn không kèm id và còn được lọc lần nữa bằng stripHidden() trước khi gửi cho LLM.
 *  - Danh tính và nhóm luôn lấy từ token (ctx); không công cụ nào nhận user_id / group_id.
 *  - Mọi công cụ gọi đúng Service của REST nên chung validation, quyền và mã phản hồi.
 *
 * risk: read | write      requires: user | member | leader (lọc gợi ý chủ động / hiển thị)
 */

// ---------- JSON Schema dùng chung ----------
const str = (max = 150, description) => ({ type: 'string', minLength: 1, maxLength: max, ...(description ? { description } : {}) });
const obj = (properties, required = []) => ({ type: 'object', properties, required, additionalProperties: false });
const qty = { type: 'number', exclusiveMinimum: 0, description: 'Số lượng theo đơn vị của thực phẩm' };
const date = { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$', description: 'Ngày dạng YYYY-MM-DD' };
const when = { type: 'string', minLength: 10, maxLength: 40, description: 'Thời điểm ISO 8601 có múi giờ hoặc ngày YYYY-MM-DD' };
const useWithin = {
  type: 'string', minLength: 1, maxLength: 40,
  description: 'Hạn sử dụng: ngày YYYY-MM-DD (hết hạn cuối ngày), ISO 8601 có múi giờ, hoặc số ngày kể từ hôm nay, vd "3"',
};
const meal = { type: 'string', enum: ['sáng', 'trưa', 'tối'] };
const location = { type: 'string', enum: ['cool', 'freezer', 'other'], description: 'cool = ngăn mát, freezer = ngăn đông, other = khác' };
const note = { type: 'string', maxLength: 500 };
const taskList = (max = 30) => ({ type: 'array', minItems: 1, maxItems: max, items: obj({ foodName: str(), quantity: qty }, ['foodName', 'quantity']) });

// ---------- Rút gọn dữ liệu trả cho LLM (không id) ----------
const cFridge = (i) => ({
  food: i.food.name, quantity: i.quantity, unit: i.food.unit.name, category: i.food.category.name,
  useWithin: i.useWithin, daysLeft: i.daysLeft, status: i.status, location: i.location, note: i.note,
});
const cList = (l) => ({
  name: l.name, date: l.date, note: l.note, assignedTo: l.assignedTo?.username ?? null,
  tasks: l.tasks.map((t) => ({ food: t.food.name, quantity: t.quantity, unit: t.food.unit.name, status: t.status })),
});
const cPlan = (p) => ({ date: p.date, meal: p.mealName, food: p.food.name, recipe: p.recipe?.name ?? null });
const cRecipe = (r) => ({
  name: r.name, description: r.description, mainFood: r.food.name,
  ingredients: (r.ingredients ?? []).map((i) => ({ food: i.food.name, quantity: i.quantity, unit: i.food.unit })),
});
const stripHtml = (h) => String(h ?? '').replace(/<\/(p|li|h\d)>/gi, '\n').replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').trim();

// ---------- Tra cứu theo tên trong phạm vi nhóm của người dùng ----------
async function recipeIdByName(ctx, name) {
  const groupId = requireMember(ctx, '00185');
  const { rows } = await query(
    `SELECT id FROM recipes WHERE group_id = $1 AND lower(btrim(name)) = lower(btrim($2)) ORDER BY updated_at DESC LIMIT 1`,
    [groupId, name],
  );
  if (!rows[0]) throw new AppError('00538', { recipeName: name });
  return rows[0].id;
}

/** Danh sách mua sắm theo tên (+ ngày nếu có). Trùng tên mà không có ngày => yêu cầu nói rõ ngày. */
async function listIdByName(ctx, name, listDate) {
  const groupId = requireMember(ctx, '00288');
  const { rows } = await query(
    `SELECT id, shopping_date FROM shopping_lists
      WHERE group_id = $1 AND lower(btrim(name)) = lower(btrim($2)) AND ($3::date IS NULL OR shopping_date = $3::date)
      ORDER BY shopping_date DESC, id DESC`,
    [groupId, name, listDate ?? null],
  );
  if (!rows.length) throw new AppError('00283', { listName: name, hint: 'Xem tên chính xác bằng list_shopping_lists' });
  if (rows.length > 1 && !listDate) {
    throw new AppError('00513', { listName: name, hint: 'Có nhiều danh sách trùng tên, hãy truyền thêm listDate', dates: rows.map((r) => r.shopping_date) });
  }
  return rows[0].id;
}

const TOOLS = [
  // ===================== XEM =====================
  {
    name: 'get_my_profile', risk: 'read', requires: 'user',
    description: 'Xem hồ sơ của chính người dùng (tên, username, nhóm, vai trò trong nhóm, múi giờ).',
    schema: obj({}),
    run: (ctx) => User.getMe(ctx),
    compact: ({ user }) => ({
      name: user.name, username: user.username, timezone: user.timezone,
      group: user.group ? { name: user.group.name, role: user.group.role === 'admin' ? 'trưởng nhóm' : 'thành viên' } : null,
    }),
    summary: () => 'Xem hồ sơ',
  },
  {
    name: 'get_group_members', risk: 'read', requires: 'member',
    description: 'Xem nhóm gia đình của người dùng và danh sách thành viên (tên, username, vai trò).',
    schema: obj({}),
    run: (ctx) => Group.getGroup(ctx),
    compact: ({ group, myRole }) => ({
      groupName: group.name, myRole, members: group.members.map((m) => ({ name: m.name, username: m.username, role: m.role })),
    }),
    summary: () => 'Xem thành viên nhóm',
  },
  {
    name: 'list_categories', risk: 'read', requires: 'user',
    description: 'Danh mục thực phẩm dùng chung (thịt, rau củ, ...).',
    schema: obj({}),
    run: () => CategoryService.list(),
    compact: (d) => d.categories.map((c) => c.name),
    summary: () => 'Xem danh mục thực phẩm',
  },
  {
    name: 'list_units', risk: 'read', requires: 'user',
    description: 'Đơn vị đo dùng chung (kg, g, quả, bó, ...).',
    schema: obj({}),
    run: () => UnitService.list(),
    compact: (d) => d.units.map((u) => u.name),
    summary: () => 'Xem đơn vị đo',
  },
  {
    name: 'list_foods', risk: 'read', requires: 'member',
    description: 'Thực phẩm đã khai báo của gia đình (tìm theo từ khóa). Dùng để biết tên chính xác trước khi thêm vào tủ lạnh/danh sách mua.',
    schema: obj({ keyword: { type: 'string', maxLength: 100 } }),
    run: (ctx, a) => Food.listFoods(ctx, { q: a.keyword, limit: 50 }),
    compact: (d) => ({ total: d.total, foods: d.foods.map((f) => ({ name: f.name, category: f.category.name, unit: f.unit.name })) }),
    summary: (a) => (a.keyword ? `Tìm thực phẩm "${a.keyword}"` : 'Xem danh sách thực phẩm'),
  },
  {
    name: 'list_fridge_items', risk: 'read', requires: 'member',
    description: 'Toàn bộ thực phẩm đang có trong tủ lạnh, sắp xếp theo hạn dùng.',
    schema: obj({}),
    run: (ctx) => Fridge.listItems(ctx, { limit: 50 }),
    compact: (d) => ({ summary: d.summary, items: d.items.map(cFridge) }),
    summary: () => 'Xem tủ lạnh',
  },
  {
    name: 'get_fridge_item', risk: 'read', requires: 'member',
    description: 'Thông tin trong tủ lạnh của một thực phẩm theo tên.',
    schema: obj({ foodName: str() }, ['foodName']),
    run: (ctx, a) => Fridge.getByFoodName(ctx, a.foodName),
    compact: (d) => cFridge(d.item),
    summary: (a) => `Xem ${a.foodName} trong tủ lạnh`,
  },
  {
    name: 'find_expiring_items', risk: 'read', requires: 'member',
    description: 'Thực phẩm trong tủ lạnh sẽ hết hạn trong withinDays ngày tới (gồm cả đã quá hạn).',
    schema: obj({ withinDays: { type: 'integer', minimum: 1, maximum: 30 } }, ['withinDays']),
    run: (ctx, a) => Fridge.listItems(ctx, { expiringDays: a.withinDays, limit: 50 }),
    compact: (d) => d.items.map(cFridge),
    summary: (a) => `Tìm đồ sắp hết hạn trong ${a.withinDays} ngày`,
  },
  {
    name: 'list_shopping_lists', risk: 'read', requires: 'member',
    description: 'Các danh sách mua sắm gần đây kèm món cần mua. status: open (còn món chưa mua) hoặc done.',
    schema: obj({ status: { type: 'string', enum: ['open', 'done'] }, fromDate: date }),
    run: (ctx, a) => Shopping.listLists(ctx, { status: a.status, from: a.fromDate, limit: 10 }),
    compact: (d) => d.lists.map(cList),
    summary: () => 'Xem danh sách mua sắm',
  },
  {
    name: 'get_meal_plans', risk: 'read', requires: 'member',
    description: 'Kế hoạch bữa ăn theo ngày (date) hoặc theo khoảng (fromDate..toDate, tối đa 31 ngày).',
    schema: obj({ date, fromDate: date, toDate: date }),
    run: (ctx, a) => Meal.listPlans(ctx, a.fromDate ? { from: a.fromDate, to: a.toDate ?? a.fromDate } : { date: a.date }),
    compact: (d) => ({ from: d.from, to: d.to, plans: d.plans.map(cPlan) }),
    summary: (a) => `Xem lịch bữa ăn ${a.date ?? `${a.fromDate}..${a.toDate ?? a.fromDate}`}`,
  },
  {
    name: 'check_meal_ingredients', risk: 'read', requires: 'member',
    description: 'Đối chiếu nguyên liệu cần cho các bữa của một ngày với tủ lạnh: cần gì, đang có, còn thiếu.',
    schema: obj({ date }, ['date']),
    run: (ctx, a) => Meal.checkIngredients(ctx, { date: a.date }),
    compact: (d) => ({
      plans: d.plans.map(cPlan),
      ingredients: d.ingredients.map((i) => ({
        food: i.food.name, unit: i.food.unit, required: i.requiredQuantity, available: i.availableQuantity, missing: i.missingQuantity, enough: i.enough,
      })),
    }),
    summary: (a) => `Kiểm tra nguyên liệu ngày ${a.date}`,
  },
  {
    name: 'get_recipes', risk: 'read', requires: 'member',
    description: 'Tìm công thức của gia đình theo tên thực phẩm (nguyên liệu) hoặc từ khóa.',
    schema: obj({ foodName: str(), keyword: { type: 'string', maxLength: 100 } }),
    run: async (ctx, a) => {
      let foodId;
      if (a.foodName) {
        const food = await findFoodByName(null, requireMember(ctx, '00185'), a.foodName);
        if (!food) return { code: '00378', data: { recipes: [] } };
        foodId = food.id;
      }
      return Recipe.listRecipes(ctx, { foodId, q: a.keyword, limit: 20 });
    },
    compact: (d) => d.recipes.map(cRecipe),
    summary: () => 'Tìm công thức',
  },
  {
    name: 'get_recipe_detail', risk: 'read', requires: 'member',
    description: 'Nội dung đầy đủ (cách nấu) của một công thức theo tên.',
    schema: obj({ recipeName: str() }, ['recipeName']),
    run: async (ctx, a) => Recipe.getRecipe(ctx, await recipeIdByName(ctx, a.recipeName)),
    compact: (d) => ({ ...cRecipe(d.recipe), instructions: stripHtml(d.recipe.htmlContent).slice(0, 4000) }),
    summary: (a) => `Xem công thức "${a.recipeName}"`,
  },
  {
    name: 'suggest_recipes', risk: 'read', requires: 'member',
    description: 'Gợi ý công thức từ đồ đang có trong tủ lạnh, ưu tiên món nấu được ngay và dùng đồ sắp hết hạn.',
    schema: obj({ onlyCookable: { type: 'boolean' } }),
    run: (ctx, a) => Recipe.suggestRecipes(ctx, { onlyCookable: a.onlyCookable ? 'true' : undefined, limit: 10 }),
    compact: (d) => d.suggestions.map((s) => ({
      name: s.recipe.name, canCook: s.canCook, expiringIngredients: s.expiringIngredients,
      missing: s.missing.map((m) => ({ food: m.food.name, missingQuantity: m.missingQuantity, unit: m.food.unit })),
    })),
    summary: () => 'Gợi ý món từ tủ lạnh',
  },
  {
    name: 'get_stats', risk: 'read', requires: 'member',
    description: 'Thống kê mua sắm và tiêu thụ/bỏ đi trong khoảng ngày (mặc định 30 ngày gần nhất).',
    schema: obj({ fromDate: date, toDate: date }),
    run: (ctx, a) => Stats.summary(ctx, { from: a.fromDate, to: a.toDate }),
    compact: (d) => ({ from: d.from, to: d.to, totals: d.totals, wasteRate: d.wasteRate, shopping: d.shopping, byFood: d.byFood.slice(0, 30) }),
    summary: () => 'Xem thống kê',
  },

  // ===================== TẠO =====================
  {
    name: 'create_food', risk: 'write', requires: 'member',
    description: 'Khai báo thực phẩm mới cho gia đình (tên chưa trùng; danh mục và đơn vị phải có trong list_categories / list_units).',
    schema: obj({ name: str(), foodCategoryName: str(100), unitName: str(100) }, ['name', 'foodCategoryName', 'unitName']),
    run: (ctx, a) => Food.createFood(ctx, a),
    compact: (d) => ({ name: d.food.name, category: d.food.category.name, unit: d.food.unit.name }),
    summary: (a) => `Thêm thực phẩm "${a.name}" (${a.foodCategoryName}, ${a.unitName})`,
  },
  {
    name: 'create_fridge_item', risk: 'write', requires: 'member',
    description: 'Thêm một thực phẩm đã khai báo vào tủ lạnh. Mỗi thực phẩm chỉ có một mục; nếu đã có thì báo người dùng tự sửa số lượng trong ứng dụng.',
    schema: obj({ foodName: str(), quantity: qty, useWithin, note, location }, ['foodName', 'quantity', 'useWithin']),
    run: (ctx, a) => Fridge.createItem(ctx, a),
    compact: (d) => cFridge(d.item),
    summary: (a) => `Thêm ${a.quantity} ${a.foodName} vào tủ lạnh, hạn ${a.useWithin}`,
  },
  {
    name: 'create_shopping_list', risk: 'write', requires: 'leader',
    description: 'Tạo danh sách mua sắm cho một ngày, có thể giao cho thành viên (username) và kèm luôn các món cần mua. Chỉ trưởng nhóm.',
    schema: obj({ name: str(), date, assignToUsername: str(14), note, tasks: taskList() }, ['name', 'date']),
    run: async (ctx, a) => {
      const created = await Shopping.createList(ctx, { name: a.name, date: a.date, assignToUsername: a.assignToUsername, note: a.note });
      if (!a.tasks?.length) return created;
      try {
        const t = await Shopping.createTasks(ctx, { listId: created.data.listId, tasks: a.tasks });
        return { code: t.code, data: { list: t.data.list, failed: t.data.failed } };
      } catch (err) {
        // Danh sách đã tạo; báo rõ món nào chưa thêm được (UC03 - 5a)
        if (err instanceof AppError) return { code: '00507', data: { list: created.data.list, failed: err.data?.failed ?? [{ message: err.message }] } };
        throw err;
      }
    },
    compact: (d) => ({ ...cList(d.list), failed: (d.failed ?? []).map((f) => ({ foodName: f.foodName, message: f.message })) }),
    summary: (a) => `Tạo danh sách "${a.name}" ngày ${a.date}${a.assignToUsername ? ` giao cho ${a.assignToUsername}` : ''}`
      + (a.tasks?.length ? `: ${a.tasks.map((t) => `${t.foodName} ${t.quantity}`).join(', ')}` : ''),
  },
  {
    name: 'add_shopping_tasks', risk: 'write', requires: 'leader',
    description: 'Thêm món cần mua vào một danh sách CÓ SẴN, chỉ định bằng tên danh sách (thêm listDate nếu trùng tên). Chỉ trưởng nhóm.',
    schema: obj({ listName: str(), listDate: date, tasks: taskList() }, ['listName', 'tasks']),
    run: async (ctx, a) => Shopping.createTasks(ctx, { listId: await listIdByName(ctx, a.listName, a.listDate), tasks: a.tasks }),
    compact: (d) => ({ ...cList(d.list), failed: d.failed.map((f) => ({ foodName: f.foodName, message: f.message })) }),
    summary: (a) => `Thêm vào "${a.listName}": ${a.tasks.map((t) => `${t.foodName} ${t.quantity}`).join(', ')}`.slice(0, 300),
  },
  {
    name: 'create_meal_plan', risk: 'write', requires: 'leader',
    description: 'Lên kế hoạch bữa ăn (sáng/trưa/tối) bằng tên thực phẩm hoặc tên công thức. Không tự trừ tồn kho. Chỉ trưởng nhóm.',
    schema: obj({ foodName: str(), recipeName: str(), timestamp: when, name: meal }, ['timestamp', 'name']),
    run: async (ctx, a) => Meal.createPlan(ctx, {
      foodName: a.foodName,
      recipeId: a.recipeName ? await recipeIdByName(ctx, a.recipeName) : undefined,
      timestamp: a.timestamp,
      name: a.name,
    }),
    compact: (d) => cPlan(d.plan),
    summary: (a) => `Lên bữa ${a.name} ${String(a.timestamp).slice(0, 10)}: ${a.recipeName ?? a.foodName}`,
  },
  {
    name: 'create_recipe', risk: 'write', requires: 'member',
    description: 'Lưu công thức: nguyên liệu chính (foodName), tên, mô tả, cách làm (HTML đơn giản, mỗi bước một <p>) và nguyên liệu phụ.',
    schema: obj(
      {
        foodName: str(), name: str(), description: str(2000), htmlContent: str(20000),
        ingredients: { type: 'array', maxItems: 30, items: obj({ foodName: str(), quantity: qty }, ['foodName']) },
      },
      ['foodName', 'name', 'description', 'htmlContent'],
    ),
    run: (ctx, a) => Recipe.createRecipe(ctx, a),
    compact: (d) => cRecipe(d.recipe),
    summary: (a) => `Lưu công thức "${a.name}"`,
  },
];

const BY_NAME = new Map(TOOLS.map((t) => [t.name, t]));
export const getTool = (name) => BY_NAME.get(name) ?? null;
export const allTools = () => TOOLS;

/** Phiên bản bộ công cụ: hội thoại tạo với bộ cũ không tiếp tục được (lịch sử gọi công cụ cũ). */
export const TOOLSET_VERSION = 2;

export function roleAllows(tool, ctx) {
  if (tool.requires === 'user') return true;
  if (!ctx.groupId) return false;
  return tool.requires === 'member' || ctx.groupRole === 'admin';
}

/** Khóa nội bộ không bao giờ gửi cho LLM. */
const HIDDEN_KEY = /^(id|version|imageUrl|sessionId)$|Ids?$/;

/** Lọc đệ quy mọi khóa id / ...Id khỏi dữ liệu trước khi gửi cho LLM (lớp bảo vệ thứ hai sau compact). */
export function stripHidden(v) {
  if (Array.isArray(v)) return v.map(stripHidden);
  if (v && typeof v === 'object' && !(v instanceof Date)) {
    const out = {};
    for (const [k, val] of Object.entries(v)) if (!HIDDEN_KEY.test(k)) out[k] = stripHidden(val);
    return out;
  }
  return v;
}

/**
 * Định nghĩa gửi cho LLM: cố định, thứ tự cố định cho mọi người dùng (giữ prompt cache);
 * quyền được Guard + Service kiểm tra khi thực thi.
 */
export const llmToolDefinitions = TOOLS.map((t) => ({
  name: t.name,
  description: `${t.description} [${t.risk === 'read' ? 'xem' : 'tạo'}]`,
  input_schema: t.schema,
  eager_input_streaming: true,
}));
