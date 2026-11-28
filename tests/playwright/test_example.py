# SPDX-FileCopyrightText: Copyright (c) 2026 Yukihiko Shinoda
# SPDX-License-Identifier: MIT
"""Smoke tests confirming Playwright can drive a browser inside the image."""

import re

from playwright.sync_api import Page
from playwright.sync_api import expect


class TestPlaywrightDev:
    def test_has_title(self, page: Page) -> None:
        page.goto("https://playwright.dev/")
        expect(page).to_have_title(re.compile("Playwright"))

    def test_get_started_link(self, page: Page) -> None:
        page.goto("https://playwright.dev/")
        page.get_by_role("link", name="Get started").click()
        heading = page.get_by_role("heading", name="Installation")
        expect(heading).to_be_visible()
