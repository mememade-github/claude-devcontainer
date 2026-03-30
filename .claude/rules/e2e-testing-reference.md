# E2E Testing Reference

> Reference for e2e-runner agent. Playwright patterns, configuration, and flaky test management.

## Playwright Test Structure

```
tests/
├── e2e/                       # End-to-end user journeys
│   ├── auth/                  # Authentication flows
│   ├── markets/               # Feature tests
│   └── api/                   # API endpoint tests
├── fixtures/                  # Test data and helpers
└── playwright.config.ts
```

## Page Object Model Pattern

```typescript
import { Page, Locator } from '@playwright/test'

export class ExamplePage {
  readonly page: Page
  readonly searchInput: Locator

  constructor(page: Page) {
    this.page = page
    this.searchInput = page.locator('[data-testid="search-input"]')
  }

  async goto() {
    await this.page.goto('/path')
    await this.page.waitForLoadState('networkidle')
  }
}
```

## Playwright Configuration Template

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html'], ['junit', { outputFile: 'results.xml' }]],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
})
```

## Flaky Test Management

**Identification**: `npx playwright test --repeat-each=10`

**Quarantine**:
```typescript
test('flaky test', async ({ page }) => {
  test.fixme(true, 'Flaky - Issue #123')
})
```

**Common causes & fixes**:
1. Race conditions — use Playwright auto-wait locators, not raw `page.click()`
2. Network timing — `waitForResponse()` instead of `waitForTimeout()`
3. Animation timing — `waitFor({ state: 'visible' })` before interaction

## Artifact Strategy

- Screenshots: `page.screenshot({ path: 'artifacts/name.png' })`
- Full page: `page.screenshot({ fullPage: true })`
- Element: `locator.screenshot({ path: 'artifacts/element.png' })`
- Trace: configured in playwright.config.ts `trace: 'on-first-retry'`
- Video: `video: 'retain-on-failure'` (only save on failure)
