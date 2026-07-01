import { execSync } from 'child_process';

export const data = JSON.parse(
  execSync('nix-instantiate --eval --strict --quiet --json ../dev/_get-docs.nix', { encoding: 'utf-8' })
);
