import { expect, type Locator, type Page, test } from '@playwright/test';
import { newApiBaseURL } from '../playwright.config';

const adminUsername = process.env.NEW_API_ADMIN_USERNAME;
const adminPassword = process.env.NEW_API_ADMIN_PASSWORD;
const targetUsername = process.env.NEW_API_ADMIN_TARGET_USERNAME;
const baseURL = newApiBaseURL.replace(/\/$/, '');

test.describe('New API admin user row actions', () => {
  test.skip(
    !adminUsername || !adminPassword,
    'requires NEW_API_ADMIN_USERNAME and NEW_API_ADMIN_PASSWORD'
  );

  test('opens user binding and subscription management dialogs', async ({
    page,
  }) => {
    await signIn(page);
    await page.goto(`${baseURL}/users`, { waitUntil: 'domcontentloaded' });

    const userRow = await findUserRow(page);
    await expect(userRow).toBeVisible();

    await openRowMenu(userRow);
    await page.getByRole('menuitem', { name: /Manage Bindings/i }).click();
    await expect(
      page.getByRole('heading', { name: /Account Binding Management/i })
    ).toBeVisible();
    await page.keyboard.press('Escape');

    await openRowMenu(userRow);
    await page.getByRole('menuitem', { name: /Manage Subscriptions/i }).click();
    await expect(
      page.getByRole('heading', { name: /User Subscription Management/i })
    ).toBeVisible();
  });
});

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
  for (const selector of selectors) {
    const input = page.locator(selector).first();
    if (await input.isVisible().catch(() => false)) {
      await input.fill(value);
      return;
    }
  }
  throw new Error(`No visible input found for selectors: ${selectors.join(', ')}`);
}

async function findUserRow(page: Page): Promise<Locator> {
  const rows = page.getByRole('row');
  if (targetUsername) {
    return rows.filter({ hasText: targetUsername }).first();
  }
  return page.locator('tbody tr').first();
}

async function openRowMenu(row: Locator) {
  await row.getByRole('button', { name: /Open menu/i }).click();
}
