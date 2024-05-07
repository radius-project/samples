import { test, expect } from "@playwright/test";

test("eShop on Containers App Basic UI and Functionality Checks", async ({
  page,
}, testInfo) => {
  if (testInfo.retry > 0) {
    console.log(`Retrying!`);
  }

  const log = (message: any) => {
    console.log(`Attempt ${testInfo.retry}: ${message}`);
  };

  log("Starting the eShop App UI tests");

  log("Checking the necessary environment variables");
  let endpoint = process.env.ENDPOINT;
  expect(endpoint).toBeDefined();

  // Remove quotes from the endpoint if they exist
  try {
    endpoint = (endpoint as string).replace(/['"]+/g, "");
    log(`Navigating to the endpoint: ${endpoint}`);
    await page.goto(endpoint);
  } catch (error) {
    console.error(
      `Attempt ${testInfo.retry}: Failed to navigate to the endpoint:`,
      error
    );
  }

  // Expect page to have proper URL
  log(`Checking the URL: ${endpoint}/catalog`);
  await expect(page).toHaveURL(new RegExp(`${endpoint}/catalog.*`));
  // Expect page to have proper title
  log("Checking the title: eShopOnContainers - SPA");
  await expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Check for the LOGIN button in the home page
  log("Checking the LOGIN button");
  const loginButton = page.getByText("LOGIN");
  await expect(loginButton).toBeVisible();
  await loginButton.click();

  // Expect login page to have proper title
  log("Checking the title: eShopOnContainers - Identity");
  await expect(page).toHaveTitle("eShopOnContainers - Identity");

  // Fill in the username and password
  log("Filling in the username");
  const username = page.getByPlaceholder("Username");
  await expect(username).toBeVisible();
  await username.click();
  await username.fill("alice");

  log("Filling in the password");
  const password = page.getByPlaceholder("Password");
  await expect(password).toBeVisible();
  await password.click();
  await password.fill("Pass123$");

  // Click on the LOGIN button
  log("Clicking the LOGIN button");
  await page.getByRole("button", { name: "Login" }).click();

  // After login, expect to be redirected to the catalog page
  // Expect page to have proper URL
  log("Checking the URL after login");
  await expect(page).toHaveURL(new RegExp(`${endpoint}/catalog.*`));
  // Expect page to have proper title
  log("Checking the title after login");
  await expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Logged user details should be visible
  log("Checking the user details");
  const user = page.getByText("AliceSmith@email.com");
  await expect(user).toBeVisible();
  // Click on the user details
  await user.click();

  // Check dropdown menu
  log("Checking the dropdown menu");
  await expect(page.getByText("My orders")).toBeVisible();
  await expect(page.getByText("Log Out")).toBeVisible();

  // Find the catalog
  log("Finding the catalog");
  const catalogSelector = "esh-catalog";
  await page.waitForSelector(catalogSelector);
  const catalog = page.locator(catalogSelector);
  await expect(catalog).toBeVisible();
  log("Catalog found");

  // Add the first item to the cart
  let numberOfItemsAdded = 0;
  log("Adding an item to the cart");

  let attempts = 0;
  let maxAttempts = 5;
  let itemAdded = false;

  while (attempts < maxAttempts) {
    // Try to find the first item in the catalog
    const firstItemSelector = "div:nth-child(1) > .esh-catalog-item";
    // await page.waitForSelector(firstItemSelector);
    const firstItem = page.locator(firstItemSelector);
    const isFirstItemVisible = await firstItem.isVisible();

    // If not visible, reload the page
    if (!isFirstItemVisible) {
      log("Item is not visible, reloading the page");
      attempts++;
      await page.reload({ waitUntil: "commit" });
    } else {
      // If visible, add the item to the cart
      await firstItem.click();
      log("Item added to the cart");
      numberOfItemsAdded++;
      itemAdded = true;
      break;
    }
  }

  if (!itemAdded) {
    // If the item was not added, log and end the test.
    // Please see this issue: https://github.com/radius-project/samples/issues/1545
    log(`Failed to add an item to the cart after ${maxAttempts} attempts`);
    return;
  }

  // Go to the cart
  log("Going to the cart");
  const cartLink = page.getByRole("link", { name: `${numberOfItemsAdded}` });
  await expect(cartLink).toBeVisible();
  await cartLink.click();
  log("Cart page loaded");

  // Expect page to have proper URL
  log("Checking the URL after going to the cart");
  await expect(page).toHaveURL(new RegExp(`${endpoint}/basket.*`));
  // Checkout
  log("Checking out");
  await page.getByRole("button", { name: "Checkout" }).click();
  // Place the order
  log("Placing the order");
  await page.getByRole("button", { name: "Place Order" }).click();
  // Continue Shopping
  log("Continuing shopping");
  await page.getByRole("link", { name: "Continue Shopping" }).click();
  // Logout
  log("Logging out");
  await page.locator("div").filter({ hasText: "Log Out" }).nth(0).click();
});
