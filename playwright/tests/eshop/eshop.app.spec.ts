import { test, expect } from "@playwright/test";

test("eShop on Containers App Basic UI and Functionality Checks", async ({
  page,
}) => {
  console.log("Starting the eShop App UI tests");

  console.log("Checking the necessary environment variables");
  let endpoint = process.env.ENDPOINT;
  expect(endpoint).toBeDefined();

  // Remove quotes from the endpoint if they exist
  try {
    console.log("Navigating to the endpoint");
    endpoint = (endpoint as string).replace(/['"]+/g, "");
    console.log(`Endpoint: ${endpoint}`);
    await page.goto(endpoint);
  } catch (error) {
    console.error("Failed to navigate to the endpoint:", error);
  }

  // Expect page to have proper URL
  console.log("Checking the URL");
  await expect(page).toHaveURL(new RegExp(`${endpoint}/catalog.*`));
  // Expect page to have proper title
  console.log("Checking the title");
  await expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Check for the LOGIN button in the home page
  console.log("Checking the LOGIN button");
  const loginButton = page.getByText("LOGIN");
  await expect(loginButton).toBeVisible();
  await loginButton.click();

  // Expect login page to have proper title
  console.log("Checking the login page title");
  await expect(page).toHaveTitle("eShopOnContainers - Identity");

  // Fill in the username and password
  console.log("Filling in the username");
  const username = page.getByPlaceholder("Username");
  await expect(username).toBeVisible();
  await username.click();
  await username.fill("alice");

  console.log("Filling in the password");
  const password = page.getByPlaceholder("Password");
  await expect(password).toBeVisible();
  await password.click();
  await password.fill("Pass123$");

  // Click on the LOGIN button
  console.log("Clicking the LOGIN button");
  await page.getByRole("button", { name: "Login" }).click();

  // After login, expect to be redirected to the catalog page
  // Expect page to have proper URL
  console.log("Checking the URL after login");
  await expect(page).toHaveURL(new RegExp(`${endpoint}/catalog.*`));
  // Expect page to have proper title
  console.log("Checking the title after login");
  await expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Logged user details should be visible
  console.log("Checking the user details");
  const user = page.getByText("AliceSmith@email.com");
  await expect(user).toBeVisible();
  // Click on the user details
  await user.click();

  // Check dropdown menu
  console.log("Checking the dropdown menu");
  await expect(page.getByText("My orders")).toBeVisible();
  await expect(page.getByText("Log Out")).toBeVisible();

  // Find the catalog
  console.log("Finding the catalog");
  const catalogSelector = "esh-catalog";
  await page.waitForSelector(catalogSelector);
  const catalog = page.locator(catalogSelector);
  await expect(catalog).toBeVisible();
  console.log("Catalog found");

  let numberOfItemsAdded = 0;
  // Add the first item to the cart
  console.log("Adding an item to the cart");
  const firstItemSelector = "div:nth-child(1) > .esh-catalog-item";

  let attempts = 0;
  let maxAttempts = 5;
  let firstItem;

  while (attempts < maxAttempts) {
    try {
      // If the item is not found in the first attempt,
      // reload the page to trigger the API call again.
      if (attempts > 0) {
        await page.reload();
      }

      await page.waitForSelector(firstItemSelector);
      firstItem = page.locator(firstItemSelector);
      await expect(firstItem).toBeVisible();
      await firstItem.click();
      console.log("Item added to the cart");
      numberOfItemsAdded++;
      break;
    } catch (error) {
      // If the item is not found within 5 seconds, an error will be thrown here, then the page will be reloaded
      console.error("Item not found:", error);
      attempts++;
    }
  }

  if (!firstItem) {
    throw new Error("First item not found after " + maxAttempts + " attempts");
  }

  // Go to the cart
  console.log("Going to the cart");
  const cartLink = page.getByRole("link", { name: `${numberOfItemsAdded}` });
  await expect(cartLink).toBeVisible();
  await cartLink.click();
  console.log("Cart page loaded");

  // Expect page to have proper URL
  console.log("Checking the URL after going to the cart");
  await expect(page).toHaveURL(new RegExp(`${endpoint}/basket.*`));
  // Checkout
  console.log("Checking out");
  await page.getByRole("button", { name: "Checkout" }).click();
  // Place the order
  console.log("Placing the order");
  await page.getByRole("button", { name: "Place Order" }).click();
  // Continue Shopping
  console.log("Continuing shopping");
  await page.getByRole("link", { name: "Continue Shopping" }).click();
  // Logout
  console.log("Logging out");
  await page.locator("div").filter({ hasText: "Log Out" }).nth(0).click();
});
