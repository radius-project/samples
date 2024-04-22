import { test, expect } from "@playwright/test";

test("eShop on Containers App Basic UI and Functionality Checks", async ({
  page,
}) => {
  // Listen for all console events and handle errors
  page.on("console", (msg) => {
    if (msg.type() === "error") {
      console.log(`Error text: "${msg.text()}"`);
    }
  });

  let endpoint = process.env.ENDPOINT;
  expect(endpoint).toBeDefined();

  // Remove quotes from the endpoint if they exist
  endpoint = (endpoint as string).replace(/['"]+/g, "");
  console.log(`Endpoint: ${endpoint}`);
  await page.goto(endpoint);

  // Expect page to have proper URL
  await expect(page).toHaveURL(new RegExp(`${endpoint}/catalog.*`));
  // Expect page to have proper title
  await expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Check for the LOGIN button in the home page
  const loginButton = page.getByText("LOGIN");
  await expect(loginButton).toBeVisible();
  await loginButton.click();

  // Expect login page to have proper title
  await expect(page).toHaveTitle("eShopOnContainers - Identity");

  // Fill in the username and password
  const username = page.getByPlaceholder("Username");
  await expect(username).toBeVisible();
  await username.click();
  await username.fill("alice");

  const password = page.getByPlaceholder("Password");
  await expect(password).toBeVisible();
  await password.click();
  await password.fill("Pass123$");

  // Click on the LOGIN button
  await page.getByRole("button", { name: "Login" }).click();

  // After login, expect to be redirected to the catalog page
  // Expect page to have proper URL
  await expect(page).toHaveURL(new RegExp(`${endpoint}/catalog.*`));
  // Expect page to have proper title
  await expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Logged user details should be visible
  const user = page.getByText("AliceSmith@email.com");
  await expect(user).toBeVisible();
  // Click on the user details
  await user.click();

  // Check dropdown menu
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
  // Add an item to the cart
  console.log("Adding the first item to the cart");
  const firstItemSelector = "div:nth-child(1) > .esh-catalog-item";
  await page.waitForSelector(firstItemSelector);
  const firstItem = page.locator(firstItemSelector);
  await expect(firstItem).toBeVisible();
  await firstItem.click();
  console.log("Item added to the cart");
  numberOfItemsAdded++;

  // Add an item to the cart
  console.log("Adding the second item to the cart");
  const secondItemSelector = "div:nth-child(2) > .esh-catalog-item";
  await page.waitForSelector(secondItemSelector);
  const secondItem = page.locator(secondItemSelector);
  await expect(secondItem).toBeVisible();
  await secondItem.click();
  console.log("Item added to the cart");
  numberOfItemsAdded++;

  // Go to the cart
  const cartLink = page.getByRole("link", { name: `${numberOfItemsAdded}` });
  await expect(cartLink).toBeVisible();
  await cartLink.click();

  // Expect page to have proper URL
  await expect(page).toHaveURL(new RegExp(`${endpoint}/basket.*`));
  // Checkout
  await page.getByRole("button", { name: "Checkout" }).click();
  // Place the order
  await page.getByRole("button", { name: "Place Order" }).click();
  // Continue Shopping
  await page.getByRole("link", { name: "Continue Shopping" }).click();
  // Logout
  await page.locator("div").filter({ hasText: "Log Out" }).nth(0).click();
});
