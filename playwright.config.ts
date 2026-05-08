import { defineConfig, devices } from '@playwright/test';

const newApiBaseURL = process.env.NEW_API_BASE_URL || 'http://localhost:3100';
const kumaBaseURL = process.env.KUMA_BASE_URL || 'http://localhost:3011';

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  expect: {
    timeout: 10_000,
  },
  reporter: [['list']],
  use: {
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  metadata: {
    NEW_API_BASE_URL: newApiBaseURL,
    KUMA_BASE_URL: kumaBaseURL,
  },
});

export { newApiBaseURL, kumaBaseURL };
