import * as User from '../user/user.service.js';
import * as Group from '../group/group.service.js';
import { CategoryService, UnitService } from '../admin/catalog.service.js';
import * as Food from '../food/food.service.js';
import * as Fridge from '../fridge/fridge.service.js';
import * as Shopping from '../shopping/shopping.service.js';
import * as Meal from '../meal/meal.service.js';
import * as Recipe from '../recipe/recipe.service.js';

/**
 * Tool Registry (Bảng 32). Mỗi công cụ gọi đúng Service mà REST Controller dùng, nên chung
 * validation, kiểm tra quyền và mã phản hồi. Không công cụ nào nhận user_id / group_id.
 *
 * risk: read | write | destructive      requires: user | member | leader (để lọc gợi ý chủ động)
 * run(ctx, args) -> {code, data}        compact(data) -> dữ liệu rút gọn gửi cho LLM
 * refs(data) -> các id có thể tham chiếu bằng "$action:<id>.<field>"
 */

// ---------- JSON Schema dùng chung ----------
const str = (max = 150, description) => ({ type: 'string', minLength: 1, maxLength: max, ...(description ? { description } : {}) });
const obj = (properties, required = []) => ({ type: 'object', properties, required, additionalProperties: false });
const id = (description) => ({ type: 'integer', minimum: 1, ...(description ? { description } : {}) });
const qty = { type: 'number', exclusiveMinimum: 0, description: 'Số lượng theo đơn vị của thực phẩm' };
const date = { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$', description: 'Ngày dạng YYYY-MM-DD' };
const when = {
  type: 'string',
  minLength: 10,
  maxLength: 40,
  description: 'Thời điểm ISO 8601 có múi giờ (vd 2026-11-05T18:30:00+07:00) hoặc ngày YYYY-MM-DD',
};
const useWithin = {
  type: 'string',
  minLength: 1,
  maxLength: 40,
  description: 'Hạn sử dụng: ISO 8601 có múi giờ, ngày YYYY-MM-DD (hết hạn cuối ngày) hoặc số ngày kể từ hôm nay, vd "3"',
};
const meal = { type: 'string', enum: ['sáng', 'trưa', 'tối'] };
const location = { type: 'string', enum: ['cool', 'freezer', 'other'], description: 'cool = ngăn mát, freezer = ngăn đông, other = khác' };
const ref = (description) => ({
  anyOf: [{ type: 'integer', minimum: 1 }, { type: 'string', pattern: '^\\$action:\\d+\\.[A-Za-z]+$' }],
  description: `${description}. Có thể là "$action:<actionId>.<trường>" để dùng kết quả của hành động đang chờ xác nhận`,
});
const note = { type: 'string', maxLength: 500 };

// ---------- Rút gọn dữ liệu trả cho LLM (bớt token, không lộ trường thừa) ----------
const cFridge = (i) => ({
  itemId: i.id, food: i.food.name, quantity: i.quantity, unit: i.food.unit.name, category: i.food.category.name,
  useWithin: i.useWithin, daysLeft: i.daysLeft, status: i.status, location: i.location, note: i.note, version: i.version,
});
const cList = (l) => ({
  listId: l.id, name: l.name, date: l.date, note: l.note, assignedTo: l.assignedTo?.username ?? null,
  tasks: l.tasks.map((t) => ({ taskId: t.id, food: t.food.name, quantity: t.quantity, unit: t.food.unit.name, status: t.status })),
});
const cPlan = (p) => ({ planId: p.id, date: p.date, meal: p.mealName, food: p.food.name, recipe: p.recipe?.name ?? null, plannedAt: p.plannedAt });
const cRecipe = (r) => ({
  recipeId: r.id, name: r.name, description: r.description, mainFood: r.food.name, foodId: r.food.id,
  ingredients: (r.ingredients ?? []).map((i) => ({ food: i.food.name, quantity: i.quantity, unit: i.food.unit })),
});
const stripHtml = (h) => String(h ?? '').replace(/<\/(p|li|h\d)>/gi, '\n').replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').trim();

const TOOLS = [
  // ===================== read =====================
  {
    name: 'get_my_profile', risk: 'read', requires: 'user',
    description: 'Xem hồ sơ của người dùng hiện tại (tên, username, nhóm, vai trò trong nhóm, múi giờ).',
    schema: obj({}),
    run: (ctx) => User.getMe(ctx),
    compact: ({ user }) => ({ name: user.name, username: user.username, timezone: user.timezone, group: user.group }),
    summary: () => 'Xem hồ sơ',
  },
  {
    name: 'get_group_members', risk: 'read', requires: 'member',
    description: 'Xem nhóm gia đình và danh sách thành viên (tên, username, vai trò).',
    schema: obj({}),
    run: (ctx) => Group.getGroup(ctx),
    compact: ({ group, myRole }) => ({
      groupName: group.name, myRole, members: group.members.map((m) => ({ name: m.name, username: m.username, role: m.role })),
    }),
    summary: () => 'Xem thành viên nhóm',
  },
  {
    name: 'list_categories', risk: 'read', requires: 'user',
    description: 'Danh sách danh mục thực phẩm dùng chung (thịt, rau củ, ...).',
    schema: obj({}),
    run: () => CategoryService.list(),
    compact: (d) => d.categories.map((c) => c.name),
    summary: () => 'Xem danh mục thực phẩm',
  },
  {
    name: 'list_units', risk: 'read', requires: 'user',
    description: 'Danh sách đơn vị đo dùng chung (kg, g, quả, bó, ...).',
    schema: obj({}),
    run: () => UnitService.list(),
    compact: (d) => d.units.map((u) => u.name),
    summary: () => 'Xem đơn vị đo',
  },
  {
    name: 'list_foods', risk: 'read', requires: 'member',
    description: 'Danh sách thực phẩm đã khai báo của nhóm (tìm theo từ khóa). Dùng để biết tên chính xác trước khi thêm vào tủ lạnh/danh sách mua.',
    schema: obj({ keyword: { type: 'string', maxLength: 100 } }),
    run: (ctx, a) => Food.listFoods(ctx, { q: a.keyword, limit: 50 }),
    compact: (d) => ({ total: d.total, foods: d.foods.map((f) => ({ foodId: f.id, name: f.name, category: f.category.name, unit: f.unit.name })) }),
    summary: (a) => (a.keyword ? `Tìm thực phẩm "${a.keyword}"` : 'Xem danh sách thực phẩm'),
  },
  {
    name: 'list_fridge_items', risk: 'read', requires: 'member',
    description: 'Toàn bộ thực phẩm đang có trong tủ lạnh của nhóm, sắp xếp theo hạn dùng.',
    schema: obj({}),
    run: (ctx) => Fridge.listItems(ctx, { limit: 50 }),
    compact: (d) => ({ summary: d.summary, items: d.items.map(cFridge) }),
    summary: () => 'Xem tủ lạnh',
  },
  {
    name: 'get_fridge_item', risk: 'read', requires: 'member',
    description: 'Chi tiết mục tủ lạnh của một thực phẩm theo tên.',
    schema: obj({ foodName: str() }, ['foodName']),
    run: (ctx, a) => Fridge.getByFoodName(ctx, a.foodName),
    compact: (d) => cFridge(d.item),
    summary: (a) => `Xem ${a.foodName} trong tủ lạnh`,
  },
  {
    name: 'find_expiring_items', risk: 'read', requires: 'member',
    description: 'Các thực phẩm trong tủ lạnh sẽ hết hạn trong vòng withinDays ngày tới (gồm cả đã quá hạn).',
    schema: obj({ withinDays: { type: 'integer', minimum: 1, maximum: 30 } }, ['withinDays']),
    run: (ctx, a) => Fridge.listItems(ctx, { expiringDays: a.withinDays, limit: 50 }),
    compact: (d) => d.items.map(cFridge),
    summary: (a) => `Tìm đồ sắp hết hạn trong ${a.withinDays} ngày`,
  },
  {
    name: 'list_shopping_lists', risk: 'read', requires: 'member',
    description: 'Các danh sách mua sắm gần đây của nhóm kèm nhiệm vụ. status: open (còn món chưa mua) hoặc done.',
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
    compact: (d) => ({ plans: d.plans.map(cPlan), ingredients: d.ingredients }),
    summary: (a) => `Kiểm tra nguyên liệu ngày ${a.date}`,
  },
  {
    name: 'get_recipes', risk: 'read', requires: 'member',
    description: 'Tìm công thức của nhóm theo foodId (nguyên liệu) hoặc từ khóa.',
    schema: obj({ foodId: id(), keyword: { type: 'string', maxLength: 100 } }),
    run: (ctx, a) => Recipe.listRecipes(ctx, { foodId: a.foodId, q: a.keyword, limit: 20 }),
    compact: (d) => d.recipes.map(cRecipe),
    summary: () => 'Tìm công thức',
  },
  {
    name: 'get_recipe_detail', risk: 'read', requires: 'member',
    description: 'Nội dung đầy đủ (cách nấu) của một công thức.',
    schema: obj({ recipeId: id() }, ['recipeId']),
    run: (ctx, a) => Recipe.getRecipe(ctx, a.recipeId),
    compact: (d) => ({ ...cRecipe(d.recipe), instructions: stripHtml(d.recipe.htmlContent).slice(0, 4000) }),
    summary: (a) => `Xem công thức #${a.recipeId}`,
  },
  {
    name: 'suggest_recipes', risk: 'read', requires: 'member',
    description: 'Gợi ý công thức từ đồ đang có trong tủ lạnh, ưu tiên món nấu được ngay và dùng đồ sắp hết hạn.',
    schema: obj({ onlyCookable: { type: 'boolean' } }),
    run: (ctx, a) => Recipe.suggestRecipes(ctx, { onlyCookable: a.onlyCookable ? 'true' : undefined, limit: 10 }),
    compact: (d) => d.suggestions.map((s) => ({
      recipeId: s.recipe.id, name: s.recipe.name, canCook: s.canCook, expiringIngredients: s.expiringIngredients,
      missing: s.missing.map((m) => ({ food: m.food.name, missingQuantity: m.missingQuantity, unit: m.food.unit })),
    })),
    summary: () => 'Gợi ý món từ tủ lạnh',
  },
  {
    name: 'read_attachment', risk: 'read', requires: 'user',
    description: 'Xem lại một ảnh người dùng đã gửi trước đó trong cuộc hội thoại (hóa đơn, ảnh tủ lạnh, món ăn).',
    schema: obj({ attachmentId: id() }, ['attachmentId']),
    special: 'attachment',
    summary: (a) => `Xem ảnh đính kèm #${a.attachmentId}`,
  },

  // ===================== write =====================
  {
    name: 'create_food', risk: 'write', requires: 'member',
    description: 'Khai báo thực phẩm mới cho nhóm (tên duy nhất trong nhóm, danh mục và đơn vị phải có sẵn).',
    schema: obj({ name: str(), foodCategoryName: str(100), unitName: str(100) }, ['name', 'foodCategoryName', 'unitName']),
    run: (ctx, a) => Food.createFood(ctx, a),
    compact: (d) => ({ foodId: d.food.id, name: d.food.name }),
    refs: (d) => ({ foodId: d.food.id }),
    summary: (a) => `Thêm thực phẩm "${a.name}" (${a.foodCategoryName}, ${a.unitName})`,
  },
  {
    name: 'update_food', risk: 'write', requires: 'leader',
    description: 'Sửa tên/danh mục/đơn vị của thực phẩm (chỉ trưởng nhóm).',
    schema: obj({ name: str(), newName: str(), newCategory: str(100), newUnit: str(100) }, ['name']),
    run: (ctx, a) => Food.updateFood(ctx, a),
    compact: (d) => ({ foodId: d.food.id, name: d.food.name }),
    summary: (a) => `Sửa thực phẩm "${a.name}"`,
  },
  {
    name: 'create_fridge_item', risk: 'write', requires: 'member',
    description: 'Thêm một thực phẩm của nhóm vào tủ lạnh. Mỗi thực phẩm chỉ có một mục; nếu đã có thì dùng update_fridge_item.',
    schema: obj({ foodName: str(), quantity: qty, useWithin, note, location }, ['foodName', 'quantity', 'useWithin']),
    run: (ctx, a) => Fridge.createItem(ctx, a),
    compact: (d) => cFridge(d.item),
    refs: (d) => ({ itemId: d.item.id }),
    summary: (a) => `Thêm ${a.quantity} ${a.foodName} vào tủ lạnh, hạn ${a.useWithin}`,
  },
  {
    name: 'update_fridge_item', risk: 'write', requires: 'member',
    description: 'Cập nhật số lượng/hạn dùng/ghi chú/vị trí của một mục tủ lạnh.',
    schema: obj({ itemId: id(), newQuantity: qty, newUseWithin: useWithin, newNote: note, newFoodName: str(), newLocation: location }, ['itemId']),
    run: (ctx, a) => Fridge.updateItem(ctx, a),
    compact: (d) => cFridge(d.item),
    summary: (a) => `Cập nhật mục tủ lạnh #${a.itemId}`,
  },
  {
    name: 'record_consumption', risk: 'write', requires: 'member',
    description: 'Ghi nhận đã dùng (consume) hoặc bỏ đi (discard) một lượng thực phẩm trong tủ lạnh; trừ tồn kho.',
    schema: obj({ itemId: id(), quantity: qty, type: { type: 'string', enum: ['consume', 'discard'] }, note }, ['itemId', 'quantity', 'type']),
    run: (ctx, a) => Fridge.consumeItem(ctx, a),
    compact: (d) => ({ remaining: d.remaining, depleted: d.depleted }),
    summary: (a) => `${a.type === 'discard' ? 'Bỏ' : 'Dùng'} ${a.quantity} từ mục tủ lạnh #${a.itemId}`,
  },
  {
    name: 'create_shopping_list', risk: 'write', requires: 'leader',
    description: 'Tạo danh sách mua sắm cho một ngày, có thể giao cho thành viên cùng nhóm (theo username). Chỉ trưởng nhóm.',
    schema: obj({ name: str(), date, assignToUsername: str(14), note }, ['name', 'date']),
    run: (ctx, a) => Shopping.createList(ctx, a),
    compact: (d) => cList(d.list),
    refs: (d) => ({ listId: d.listId }),
    summary: (a) => `Tạo danh sách "${a.name}" ngày ${a.date}${a.assignToUsername ? ` giao cho ${a.assignToUsername}` : ''}`,
  },
  {
    name: 'update_shopping_list', risk: 'write', requires: 'leader',
    description: 'Sửa danh sách mua sắm (tên, người được giao, ngày, ghi chú). newAssignToUsername rỗng để bỏ giao.',
    schema: obj({ listId: id(), newName: str(), newAssignToUsername: { type: 'string', maxLength: 14 }, newDate: date, newNote: note }, ['listId']),
    run: (ctx, a) => Shopping.updateList(ctx, a),
    compact: (d) => cList(d.list),
    summary: (a) => `Sửa danh sách mua sắm #${a.listId}`,
  },
  {
    name: 'add_shopping_tasks', risk: 'write', requires: 'leader',
    description: 'Thêm các món cần mua (tên thực phẩm đã khai báo + số lượng) vào một danh sách mua sắm.',
    schema: obj(
      {
        listId: ref('ID danh sách mua sắm'),
        tasks: { type: 'array', minItems: 1, maxItems: 30, items: obj({ foodName: str(), quantity: qty }, ['foodName', 'quantity']) },
      },
      ['listId', 'tasks'],
    ),
    run: (ctx, a) => Shopping.createTasks(ctx, a),
    compact: (d) => ({ created: d.created, failed: d.failed }),
    summary: (a) => `Thêm ${a.tasks.length} món: ${a.tasks.map((t) => `${t.foodName} ${t.quantity}`).join(', ')}`.slice(0, 300),
  },
  {
    name: 'update_shopping_task', risk: 'write', requires: 'leader',
    description: 'Sửa thực phẩm hoặc số lượng của một nhiệm vụ mua (chưa mua).',
    schema: obj({ taskId: id(), newFoodName: str(), newQuantity: qty }, ['taskId']),
    run: (ctx, a) => Shopping.updateTask(ctx, a),
    compact: (d) => ({ taskId: d.task.id, food: d.task.food.name, quantity: d.task.quantity }),
    summary: (a) => `Sửa nhiệm vụ mua #${a.taskId}`,
  },
  {
    name: 'create_meal_plan', risk: 'write', requires: 'leader',
    description: 'Lên kế hoạch bữa ăn (sáng/trưa/tối) với một thực phẩm/món, có thể gắn công thức. Không tự trừ tồn kho.',
    schema: obj({ foodName: str(), recipeId: ref('ID công thức'), timestamp: when, name: meal }, ['timestamp', 'name']),
    run: (ctx, a) => Meal.createPlan(ctx, a),
    compact: (d) => cPlan(d.plan),
    refs: (d) => ({ planId: d.plan.id }),
    summary: (a) => `Lên bữa ${a.name} ${String(a.timestamp).slice(0, 10)}: ${a.foodName ?? `công thức #${a.recipeId}`}`,
  },
  {
    name: 'update_meal_plan', risk: 'write', requires: 'leader',
    description: 'Sửa kế hoạch bữa ăn (món, thời điểm, bữa, công thức).',
    schema: obj({ planId: id(), newFoodName: str(), newTimestamp: when, newName: meal, newRecipeId: id() }, ['planId']),
    run: (ctx, a) => Meal.updatePlan(ctx, a),
    compact: (d) => cPlan(d.plan),
    summary: (a) => `Sửa kế hoạch bữa ăn #${a.planId}`,
  },
  {
    name: 'create_recipe', risk: 'write', requires: 'member',
    description: 'Lưu công thức nấu ăn: nguyên liệu chính (foodName), tên, mô tả, cách làm (HTML đơn giản) và nguyên liệu phụ.',
    schema: obj(
      {
        foodName: str(), name: str(), description: str(2000), htmlContent: str(20000),
        ingredients: { type: 'array', maxItems: 30, items: obj({ foodName: str(), quantity: qty }, ['foodName']) },
      },
      ['foodName', 'name', 'description', 'htmlContent'],
    ),
    run: (ctx, a) => Recipe.createRecipe(ctx, a),
    compact: (d) => cRecipe(d.recipe),
    refs: (d) => ({ recipeId: d.recipe.id }),
    summary: (a) => `Lưu công thức "${a.name}"`,
  },
  {
    name: 'update_recipe', risk: 'write', requires: 'member',
    description: 'Sửa công thức (người tạo hoặc trưởng nhóm).',
    schema: obj({ recipeId: id(), newName: str(), newDescription: str(2000), newHtmlContent: str(20000), newFoodName: str() }, ['recipeId']),
    run: (ctx, a) => Recipe.updateRecipe(ctx, a),
    compact: (d) => cRecipe(d.recipe),
    summary: (a) => `Sửa công thức #${a.recipeId}`,
  },
  {
    name: 'add_group_member', risk: 'write', requires: 'leader',
    description: 'Thêm người dùng vào nhóm theo username (chỉ trưởng nhóm).',
    schema: obj({ username: str(14) }, ['username']),
    run: (ctx, a) => Group.addMember(ctx, a),
    compact: () => ({ ok: true }),
    summary: (a) => `Thêm ${a.username} vào nhóm`,
  },

  // ===================== destructive (luôn cần xác nhận) =====================
  {
    name: 'delete_food', risk: 'destructive', requires: 'leader',
    description: 'Xóa thực phẩm (kèm mục tủ lạnh, nhiệm vụ mua, kế hoạch, công thức liên quan).',
    schema: obj({ name: str() }, ['name']),
    run: (ctx, a) => Food.deleteFood(ctx, a),
    summary: (a) => `Xóa thực phẩm "${a.name}"`,
  },
  {
    name: 'delete_fridge_item', risk: 'destructive', requires: 'member',
    description: 'Xóa mục tủ lạnh của một thực phẩm.',
    schema: obj({ foodName: str() }, ['foodName']),
    run: (ctx, a) => Fridge.deleteItem(ctx, a),
    summary: (a) => `Xóa ${a.foodName} khỏi tủ lạnh`,
  },
  {
    name: 'delete_shopping_list', risk: 'destructive', requires: 'leader',
    description: 'Xóa danh sách mua sắm.',
    schema: obj({ listId: id() }, ['listId']),
    run: (ctx, a) => Shopping.deleteList(ctx, a),
    summary: (a) => `Xóa danh sách mua sắm #${a.listId}`,
  },
  {
    name: 'delete_shopping_task', risk: 'destructive', requires: 'leader',
    description: 'Xóa một nhiệm vụ mua.',
    schema: obj({ taskId: id() }, ['taskId']),
    run: (ctx, a) => Shopping.deleteTask(ctx, a),
    summary: (a) => `Xóa nhiệm vụ mua #${a.taskId}`,
  },
  {
    name: 'delete_meal_plan', risk: 'destructive', requires: 'leader',
    description: 'Xóa kế hoạch bữa ăn.',
    schema: obj({ planId: id() }, ['planId']),
    run: (ctx, a) => Meal.deletePlan(ctx, a),
    summary: (a) => `Xóa kế hoạch bữa ăn #${a.planId}`,
  },
  {
    name: 'delete_recipe', risk: 'destructive', requires: 'member',
    description: 'Xóa công thức (người tạo hoặc trưởng nhóm).',
    schema: obj({ recipeId: id() }, ['recipeId']),
    run: (ctx, a) => Recipe.deleteRecipe(ctx, a),
    summary: (a) => `Xóa công thức #${a.recipeId}`,
  },
  {
    name: 'remove_group_member', risk: 'destructive', requires: 'leader',
    description: 'Xóa thành viên khỏi nhóm theo username (chỉ trưởng nhóm).',
    schema: obj({ username: str(14) }, ['username']),
    run: (ctx, a) => Group.removeMember(ctx, a),
    summary: (a) => `Xóa ${a.username} khỏi nhóm`,
  },
];

const BY_NAME = new Map(TOOLS.map((t) => [t.name, t]));
export const getTool = (name) => BY_NAME.get(name) ?? null;
export const allTools = () => TOOLS;

/** Có đủ quyền vai trò cho công cụ không (Service vẫn kiểm tra lại khi thực thi). */
export function roleAllows(tool, ctx) {
  if (tool.requires === 'user') return true;
  if (!ctx.groupId) return false;
  return tool.requires === 'member' || ctx.groupRole === 'admin';
}

/**
 * Định nghĩa gửi cho LLM. Danh sách CỐ ĐỊNH, thứ tự cố định cho mọi người dùng để giữ prompt cache
 * và tính hợp lệ của thinking block qua các lượt; quyền được Guard + Service kiểm tra khi thực thi.
 */
export const llmToolDefinitions = TOOLS.map((t) => ({
  name: t.name,
  description: `${t.description} [${t.risk === 'read' ? 'đọc' : t.risk === 'write' ? 'ghi' : 'xóa - luôn cần xác nhận'}]`,
  input_schema: t.schema,
  eager_input_streaming: true,
}));
