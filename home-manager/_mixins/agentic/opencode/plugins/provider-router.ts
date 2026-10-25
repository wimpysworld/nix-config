import { readFileSync } from "node:fs";
const routerModule = "@routerModule@";

export default {
  id: "nix-config.provider-router",
  async setup(ctx: any) {
    try {
      const { default: createRouter } = await import(routerModule);
      const routes = JSON.parse(readFileSync("@routerMap@", "utf8"));
      const variants = JSON.parse(readFileSync("@routerVariants@", "utf8"));
      await createRouter(ctx, routes, variants);
    } catch (cause) {
      throw new Error("Provider router: cannot initialise routing.", { cause });
    }
    if (process.env.FENCE_SANDBOX === "1") {
      await ctx.permission.hook("evaluate", (event: { effect: string }) => {
        if (event.effect === "ask") event.effect = "allow";
      });
    }
  },
};
