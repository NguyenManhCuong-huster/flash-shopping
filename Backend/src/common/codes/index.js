import { adminCodes } from "./admin_code.js";
import { aiAgentCodes } from "./ai_agent_code.js";
import { authCodes } from "./auth_code.js";
import { commonCodes } from "./common_code.js";
import { foodCodes } from "./food_code.js";
import { fridgeCodes } from "./fridge_code.js";
import { groupCodes } from "./group_code.js";
import { mealCodes } from "./meal_code.js";
import { notificationCodes } from "./notification_code.js";
import { recipeCodes } from "./recipe_code.js";
import { shoppingCodes } from "./shopping_code.js";
import { stockCodes } from "./stock_code.js";

export const responseCodes = {
  ...commonCodes,
  ...authCodes,
  ...groupCodes,
  ...adminCodes,
  ...foodCodes,
  ...fridgeCodes,
  ...shoppingCodes,
  ...mealCodes,
  ...recipeCodes,
  ...aiAgentCodes,
  ...stockCodes,
  ...notificationCodes,
};


export function messageOf(code) {
  return responseCodes[code]?.[1] ?? 'Lỗi không xác định';
}

export function statusOf(code) {
  return responseCodes[code]?.[0] ?? 500;
}
