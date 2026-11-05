import { Router } from 'express';
import { send } from './common/errors.js';
import { requireAuth, requireSystemAdmin } from './middlewares/auth.js';
import { authLimiter } from './middlewares/rateLimit.js';
import { imageUpload, publicUrl } from './middlewares/upload.js';
import * as Auth from './modules/auth/auth.service.js';
import * as User from './modules/user/user.service.js';
import * as Group from './modules/group/group.service.js';
import * as Admin from './modules/admin/admin.service.js';
import { CategoryService, UnitService } from './modules/admin/catalog.service.js';
import * as Food from './modules/food/food.service.js';
import * as Fridge from './modules/fridge/fridge.service.js';
import * as Shopping from './modules/shopping/shopping.service.js';
import * as Meal from './modules/meal/meal.service.js';
import * as Recipe from './modules/recipe/recipe.service.js';
import * as Stats from './modules/stats/stats.service.js';
import * as Notification from './modules/notification/notification.service.js';

/** Controller mỏng: chỉ lấy tham số từ request rồi gọi Service; Service trả {code, data}. */
const h = (fn) => async (req, res) => send(res, await fn(req));
const auth = requireAuth;
const admin = [requireAuth, requireSystemAdmin];

const r = Router();

// ===== UC01 Xác thực (không cần token) =====
r.post('/user', authLimiter, h((req) => Auth.register(req.body)));
r.post('/user/login', authLimiter, h((req) => Auth.login(req.body)));
r.post('/user/logout', h((req) => Auth.logout(req.body, req.headers.authorization)));
r.post('/user/refresh-token', authLimiter, h((req) => Auth.refreshToken(req.body)));
r.post('/user/send-verification-code', authLimiter, h((req) => Auth.sendVerificationCode(req.body)));
r.post('/user/verify-email', authLimiter, h((req) => Auth.verifyEmail(req.body)));

// ===== UC12 Tài khoản cá nhân =====
r.get('/user', auth, h((req) => User.getMe(req.ctx)));
r.put('/user', auth, imageUpload('avatars'), h((req) => User.updateMe(req.ctx, req.body, req.file, publicUrl('avatars', req.file))));
r.delete('/user', auth, h((req) => User.deleteMe(req.ctx)));
r.post('/user/change-password', auth, h((req) => User.changePassword(req.ctx, req.body)));
r.post('/user/device', auth, h((req) => User.registerDevice(req.ctx, req.body)));
r.delete('/user/device', auth, h((req) => User.unregisterDevice(req.ctx, req.body)));

// ===== UC02 Nhóm gia đình =====
r.post('/user/group', auth, h((req) => Group.createGroup(req.ctx, req.body)));
r.get('/user/group', auth, h((req) => Group.getGroup(req.ctx)));
r.put('/user/group', auth, h((req) => Group.renameGroup(req.ctx, req.body)));
r.delete('/user/group', auth, h((req) => Group.removeMember(req.ctx, req.body)));
r.post('/user/group/add', auth, h((req) => Group.addMember(req.ctx, req.body)));
r.post('/user/group/leave', auth, h((req) => Group.leaveGroup(req.ctx)));
r.put('/user/group/leader', auth, h((req) => Group.transferLeader(req.ctx, req.body)));

// ===== UC11 Quản trị hệ thống (users.system_role = admin) =====
r.get('/admin/category', admin, h(() => CategoryService.list()));
r.post('/admin/category', admin, h((req) => CategoryService.create(req.ctx, req.body?.name)));
r.put('/admin/category', admin, h((req) => CategoryService.rename(req.ctx, req.body?.oldName, req.body?.newName)));
r.delete('/admin/category', admin, h((req) => CategoryService.remove(req.ctx, req.body?.name)));
r.get('/admin/unit', admin, h(() => UnitService.list()));
r.post('/admin/unit', admin, h((req) => UnitService.create(req.ctx, req.body?.unitName)));
r.put('/admin/unit', admin, h((req) => UnitService.rename(req.ctx, req.body?.oldName, req.body?.newName)));
r.delete('/admin/unit', admin, h((req) => UnitService.remove(req.ctx, req.body?.unitName)));
r.get('/admin/logs', admin, h((req) => Admin.getLogs(req.ctx, req.query)));
r.get('/admin/users', admin, h((req) => Admin.listUsers(req.ctx, req.query)));
r.put('/admin/users', admin, h((req) => Admin.updateUser(req.ctx, req.body)));

// ===== Thực phẩm =====
r.get('/food/unit', auth, h(() => UnitService.list()));
r.get('/food/category', auth, h(() => CategoryService.list()));
r.get('/food', auth, h((req) => Food.listFoods(req.ctx, req.query)));
r.post('/food', auth, imageUpload('foods'), h((req) => Food.createFood(req.ctx, req.body, req.file, publicUrl('foods', req.file))));
r.put('/food', auth, imageUpload('foods'), h((req) => Food.updateFood(req.ctx, req.body, req.file, publicUrl('foods', req.file))));
r.delete('/food', auth, h((req) => Food.deleteFood(req.ctx, req.body)));

// ===== UC05 Tủ lạnh =====
r.get('/fridge', auth, h((req) => Fridge.listItems(req.ctx, req.query)));
r.post('/fridge', auth, h((req) => Fridge.createItem(req.ctx, req.body)));
r.put('/fridge', auth, h((req) => Fridge.updateItem(req.ctx, req.body)));
r.delete('/fridge', auth, h((req) => Fridge.deleteItem(req.ctx, req.body)));
r.post('/fridge/consume', auth, h((req) => Fridge.consumeItem(req.ctx, req.body)));
r.get('/fridge/item/:itemId', auth, h((req) => Fridge.getById(req.ctx, req.params.itemId)));
r.get('/fridge/:foodName', auth, h((req) => Fridge.getByFoodName(req.ctx, req.params.foodName)));

// ===== UC03, UC04 Mua sắm =====
r.post('/shopping', auth, h((req) => Shopping.createList(req.ctx, req.body)));
r.put('/shopping', auth, h((req) => Shopping.updateList(req.ctx, req.body)));
r.delete('/shopping', auth, h((req) => Shopping.deleteList(req.ctx, req.body)));
r.get('/shopping/task', auth, h((req) => Shopping.listLists(req.ctx, req.query)));
r.post('/shopping/task', auth, h((req) => Shopping.createTasks(req.ctx, req.body)));
r.put('/shopping/task', auth, h((req) => Shopping.updateTask(req.ctx, req.body)));
r.delete('/shopping/task', auth, h((req) => Shopping.deleteTask(req.ctx, req.body)));
r.post('/shopping/purchase', auth, h((req) => Shopping.confirmPurchase(req.ctx, req.body, req.get('Idempotency-Key'))));
r.get('/shopping/:listId', auth, h((req) => Shopping.getList(req.ctx, req.params.listId)));

// ===== UC08 Kế hoạch bữa ăn =====
r.get('/meal', auth, h((req) => Meal.listPlans(req.ctx, req.query)));
r.post('/meal', auth, h((req) => Meal.createPlan(req.ctx, req.body)));
r.put('/meal', auth, h((req) => Meal.updatePlan(req.ctx, req.body)));
r.delete('/meal', auth, h((req) => Meal.deletePlan(req.ctx, req.body)));
r.get('/meal/ingredients', auth, h((req) => Meal.checkIngredients(req.ctx, req.query)));
r.post('/meal/missing-to-shopping', auth, h((req) => Meal.addMissingToShopping(req.ctx, req.body)));

// ===== UC07, UC09 Công thức & gợi ý =====
r.get('/recipe', auth, h((req) => Recipe.listRecipes(req.ctx, req.query)));
r.post('/recipe', auth, h((req) => Recipe.createRecipe(req.ctx, req.body)));
r.put('/recipe', auth, h((req) => Recipe.updateRecipe(req.ctx, req.body)));
r.delete('/recipe', auth, h((req) => Recipe.deleteRecipe(req.ctx, req.body)));
r.get('/recipe/suggest', auth, h((req) => Recipe.suggestRecipes(req.ctx, req.query)));
r.get('/recipe/:recipeId', auth, h((req) => Recipe.getRecipe(req.ctx, req.params.recipeId)));

// ===== UC10 Thống kê =====
r.get('/stats', auth, h((req) => Stats.summary(req.ctx, req.query)));
r.get('/stats/events', auth, h((req) => Stats.events(req.ctx, req.query)));

// ===== UC06 Thông báo =====
r.get('/notification', auth, h((req) => Notification.listNotifications(req.ctx, req.query)));
r.put('/notification/read', auth, h((req) => Notification.markRead(req.ctx, req.body)));

export default r;
