import { test, expect } from "@playwright/test";

test("eShop on Containers App Basic UI and Functionality Checks", async ({ page }) => {
  // Listen for all console events and handle errors
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log(`Error text: "${msg.text()}"`);
    }
  });

  let endpoint = process.env.ENDPOINT

  // Remove quotes from the endpoint
  endpoint = endpoint.replace(/['"]+/g, '')
  
  await page.goto(endpoint);

  // Expect page to have proper URL
  expect(page).toHaveURL(endpoint+"/catalog");

  // Expect page to have proper title
  expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Check for the LOGIN button
  await expect(page.getByText("LOGIN"))
    .toBeVisible();

  // Click on the LOGIN button
  await page.getByText("LOGIN").click();

  // Expect page to have proper title
  expect(page).toHaveTitle("eShopOnContainers - Identity");

  // Fill in the username and password
  expect(page.getByPlaceholder('Username'))
    .toBeVisible();
  await page.getByPlaceholder('Username')
    .click();
  await page.getByPlaceholder('Username')
    .fill('alice');

  expect(page.getByPlaceholder('Password'))
    .toBeVisible();
  await page.getByPlaceholder('Password')
    .click();
  await page.getByPlaceholder('Password')
    .fill('Pass123$');

  // Click on the LOGIN button
  await page.getByRole('button', { name: 'Login' })
    .click();

  // After login, expect to be redirected to the catalog page
  // Expect page to have proper URL
  expect(page).toHaveURL(endpoint+"/catalog");

  // Expect page to have proper title
  expect(page).toHaveTitle("eShopOnContainers - SPA");

  // Logged user details should be visible
  expect(page.getByText('AliceSmith@email.com'))
    .toBeVisible();

  // Click on the user details
  await page.getByText('AliceSmith@email.com').click();

  // Check dropdown menu
  expect(page.getByText('My orders'))
    .toBeVisible();
  expect(page.getByText('Log Out'))
    .toBeVisible();

  let numberOfItemsAdded = 0;
  // Add an item to the cart
  await page.locator('div:nth-child(2) > .esh-catalog-item > .esh-catalog-thumbnail-wrapper > .esh-catalog-thumbnail-icon > .esh-catalog-thumbnail-icon-svg')
    .click();
  numberOfItemsAdded++;

  // Go to the cart
  await page.getByRole('link', { name: `${numberOfItemsAdded}` })
    .click();

  // Expect page to have proper URL
  expect(page).toHaveURL(endpoint+"/basket");

  // Checkout
  await page.getByRole('button', { name: 'Checkout' })
    .click();

  // Place the order
  await page.getByRole('button', { name: 'Place Order' })
    .click();

  // Continue Shopping
  await page.getByRole('link', { name: 'Continue Shopping' })
    .click();

  // Logout
  await page.locator('div').filter({ hasText: 'Log Out' })
    .nth(0)
    .click();
});
