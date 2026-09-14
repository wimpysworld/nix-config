import { readFileSync } from "node:fs";
import createRouter from "@routerModule@";

export default async function ProviderRouter({
  client,
}: {
  client: Parameters<typeof createRouter>[0];
}) {
  try {
    const routes = JSON.parse(readFileSync("@routerMap@", "utf8"));
    return createRouter(client, routes);
  } catch (cause) {
    throw new Error("Provider router: cannot load the generated route map.", {
      cause,
    });
  }
}
