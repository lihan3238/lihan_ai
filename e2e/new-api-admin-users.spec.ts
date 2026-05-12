import { expect, type Locator, type Page, test } from '@playwright/test';
import { newApiBaseURL } from '../playwright.config';

const adminUsername = process.env.NEW_API_ADMIN_USERNAME;
const adminPassword = process.env.NEW_API_ADMIN_PASSWORD;
const targetUsername = process.env.NEW_API_ADMIN_TARGET_USERNAME;
const baseURL = newApiBaseURL.replace(/\/$/, '');
const requireAdminE2E = process.env.NEW_API_REQUIRE_ADMIN_E2E === '1';

if (requireAdminE2E && (!adminUsername || !adminPassword)) {
  throw new Error(
    'NEW_API_REQUIRE_ADMIN_E2E=1 requires NEW_API_ADMIN_USERNAME and NEW_API_ADMIN_PASSWORD'
  );
}

test.describe('New API admin user row actions', () => {
  test.skip(
    !adminUsername || !adminPassword,
    'requires NEW_API_ADMIN_USERNAME and NEW_API_ADMIN_PASSWORD'
  );

  test('opens user binding management dialog', async ({ page }) => {
    await verifyUserMenuDialog(
      page,
      /Manage Bindings/i,
      /Account Binding Management/i
    );
  });

  test('opens user subscription management dialog', async ({ page }) => {
    await verifyUserMenuDialog(
      page,
      /Manage Subscriptions/i,
      /User Subscription Management/i
    );
  });
});

async function verifyUserMenuDialog(
  page: Page,
  menuItemName: RegExp,
  headingName: RegExp
) {
  await signIn(page);
  await page.goto(`${baseURL}/users`, { waitUntil: 'domcontentloaded' });

  const userRow = await findUserRow(page);
  await expect(userRow).toBeVisible();

  await openRowMenuItem(page, userRow, menuItemName);
  await expect(page.getByRole('heading', { name: headingName })).toBeVisible();
}

async function signIn(page: Page) {
  await page.goto(`${baseURL}/sign-in`, { waitUntil: 'domcontentloaded' });
  await fillFirst(page, [
    'input[name="username"]',
    'input[autocomplete="username"]',
    'input[placeholder*="username" i]',
    'input[placeholder*="email" i]',
    'input[type="text"]',
  ], adminUsername || '');
  await fillFirst(page, [
    'input[name="password"]',
    'input[autocomplete="current-password"]',
    'input[placeholder*="password" i]',
    'input[type="password"]',
  ], adminPassword || '');

  await Promise.all([
    page.waitForLoadState('networkidle').catch(() => undefined),
    page
      .getByRole('button', { name: /sign in|login|\u767b\u5f55|\u767b\u5165/i })
      .click(),
  ]);
}

async function fillFirst(page: Page, selectors: string[], value: string) {
  const input = page.locator(selectors.join(', ')).first();
  await expect(input).toBeVisible({ timeout: 10000 });
  await input.fill(value);
}

async function findUserRow(page: Page): Promise<Locator> {
  const rows = page.getByRole('row');
  const username = targetUsername || adminUsername;
  if (username) {
    return rows.filter({ hasText: username }).first();
  }
  return page.locator('tbody tr').first();
}

async function openRowMenuItem(
  page: Page,
  row: Locator,
  menuItemName: RegExp
) {
  await row.getByRole('button', { name: /Open menu/i }).click();
  const menuItem = page.getByRole('menuitem', { name: menuItemName }).first();
  await expect(menuItem).toBeVisible();
  await menuItem.click({ trial: true });
  await page.waitForTimeout(250);
  await menuItem.click();
}
