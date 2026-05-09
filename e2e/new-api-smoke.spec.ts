import { expect, test } from '@playwright/test';
import { newApiBaseURL } from '../playwright.config';

test('New API status endpoint is reachable', async ({ request }) => {
  const response = await request.get(`${newApiBaseURL}/api/status`);
  expect(response.ok()).toBeTruthy();

  const body = await response.json();
  expect(body.success).toBe(true);
});

test('New API web app loads in browser', async ({ page }) => {
  await page.goto(newApiBaseURL, { waitUntil: 'domcontentloaded' });
  await expect(page).toHaveTitle(/.+/);
  await expect(page.locator('body')).toBeVisible();
});
