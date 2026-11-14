import { adminCodes } from "./admin_code";
import { aiAgentCodes } from "./ai_agent_code";
import { authCodes } from "./auth_code";
import { commonCodes } from "./common_code";
import { foodCodes } from "./food_code";
import { fridgeCodes } from "./fridge_code";
import { groupCodes } from "./group_code";
import { mealCodes } from "./meal_code";
import { notificationCodes } from "./notification_code";
import { recipeCodes } from "./recipe_code";
import { shoppingCodes } from "./shopping_code";
import { stockCodes } from "./stock_code";

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
