import { expect, test } from '@playwright/test';
import { kumaBaseURL } from '../playwright.config';

// KUMA_BASE_URL controls this target; default is http://localhost:3011.
test('Uptime Kuma web surface is reachable when enabled', async ({ page }) => {
  const response = await page.goto(kumaBaseURL, { waitUntil: 'domcontentloaded' });
  test.skip(!response || response.status() >= 400, `Kuma is not reachable at ${kumaBaseURL}`);

  await expect(page.locator('body')).toBeVisible();
});
