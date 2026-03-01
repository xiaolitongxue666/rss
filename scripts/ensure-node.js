#!/usr/bin/env node
/**
 * 根据 .nvmrc 使用 fnm 安装 Node 版本。
 * 使用：pnpm run node:install
 */
const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const NVMRC_PATH = path.join(__dirname, '..', '.nvmrc');

function getRequestedVersion() {
    if (!fs.existsSync(NVMRC_PATH)) {
        return null;
    }
    return fs.readFileSync(NVMRC_PATH, 'utf8').trim() || null;
}

function hasFnm() {
    try {
        execSync('fnm --version', { stdio: 'ignore' });
        return true;
    } catch {
        return false;
    }
}

function installWithFnm() {
    const result = spawnSync('fnm', ['install'], {
        stdio: 'inherit',
        shell: true,
    });
    return result.status === 0;
}

const version = getRequestedVersion();
if (!version) {
    console.warn('scripts/ensure-node.js: 未找到 .nvmrc，跳过安装。');
    process.exit(0);
}

if (hasFnm()) {
    if (installWithFnm()) process.exit(0);
    process.exit(1);
}

console.warn('scripts/ensure-node.js: 未检测到 fnm。请先安装 fnm，或手动执行：');
console.warn('  fnm install');
process.exit(1);
