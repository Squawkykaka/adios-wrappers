import type { Loader } from "astro/loaders";
import { z } from "astro/zod";
import { defineCollection } from "astro:content";
import { execSync } from "child_process";

function moduleLoader() {
  return {
    name: "module-loader",
    load: async ({ store, parseData }) => {
      let modules = JSON.parse(
        execSync(
          "nix-instantiate --eval --strict --quiet --json ../dev/_get-docs.nix",
          { encoding: "utf-8" },
        ),
      );

      Object.entries(modules).forEach(async ([id, module]) => {
        const data = await parseData({
          id,
          data: module as any,
        });
        store.set({ id, data });
      });
    },
    schema: z.object({
      options: z.record(
        z.string(),
        z.object({
          description: z.string().optional(),
          type: z.string(),
        }),
      ),
      mutations: z.array(z.string()).optional(),
    }),
  } satisfies Loader;
}


const modules = defineCollection({
    loader: moduleLoader()
})

export const collections = { modules };