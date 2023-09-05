import { test, expect } from "@playwright/test";
import { v4 as uuidv4 } from "uuid";

test("To-Do App Basic UI Checks", async ({ page }) => {
  // Listen for all console events and handle errors
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log(`Error text: "${msg.text()}"`);
    }
  });

  // Go to http://localhost:3000/
  await page.goto("http://localhost:3000/");

  // Expect page to have proper URL
  expect(page).toHaveURL("http://localhost:3000/");

  // Expect page to have proper title
  expect(page).toHaveTitle("Radius Demo");

  // Make sure the tabs are visible
  await expect(page.getByRole("link", { name: "Radius Demo" }))
    .toBeVisible();
  await expect(page.getByRole("link", { name: "Container Info" }))
    .toBeVisible();
  await expect(page.getByRole("link", { name: "Todo List" }))
    .toBeVisible();

  // Make sure the tabs are clickable
  await page.getByRole("link", { name: "Radius Demo" })
    .click();
  await page.getByRole("link", { name: "Container Info" })
    .click();
  await page.getByRole("link", { name: "Todo List" })
    .click();

  // Go back to Main Page
  await page.getByRole("link", { name: "Radius Demo" })
    .click();

  await page.getByRole('button', { name: '📄 Environment variables' }).click();

  // Make sure important environment variables are visible
  await expect(page.getByRole('cell', { name: 'CONNECTION_REDIS_CONNECTIONSTRING' }).getByText('CONNECTION_REDIS_CONNECTIONSTRING')).toBeVisible();
  await expect(page.getByRole('cell', { name: 'CONNECTION_REDIS_HOST' }).getByText('CONNECTION_REDIS_HOST')).toBeVisible();
  await expect(page.getByRole('cell', { name: 'CONNECTION_REDIS_PORT' }).getByText('CONNECTION_REDIS_PORT')).toBeVisible();
});

test("Add an item and check basic functionality", async ({ page }) => {
  await page.goto("http://localhost:3000/");
  // Go to Todo List Page
  await page.getByRole("link", { name: "Todo List" }).click();

  // Make sure the input is visible
  await expect(page.getByPlaceholder("What do you need to do?"))
    .toBeVisible();

  // Add a todo item
  const todoItem = `Test Item ${uuidv4()}`;
  await page.getByPlaceholder("What do you need to do?")
    .fill(todoItem);
  await page.getByRole("button", { name: "Add send" })
    .click();

  // Make sure the todo item is visible now
  await expect(page.getByRole("cell", { name: todoItem }))
    .toBeVisible();

  // Complete a todo item

  // At first we expect a lightbulb icon in the status column for the given todo item
  await expect(page.getByRole("row", { name: `${todoItem} lightbulb` }))
    .toBeVisible();

  // Then we expect to have a Complete button for the given todo item
  await expect(page
    .getByRole("row", {
      name: `${todoItem} lightbulb Complete done Delete delete`,
    })
    .getByRole("button", { name: "Complete done" }))
    .toBeVisible();

  // We click the Complete button
  await page
    .getByRole("row", {
      name: `${todoItem} lightbulb Complete done Delete delete`,
    })
    .getByRole("button", { name: "Complete done" })
    .click();

  // Now we expect a checkmark icon represented as `done` in the status column for the given todo item
  await expect(page
    .getByRole("row", {
      name: `${todoItem} done Complete done Delete delete`,
    })
    .getByRole("button", { name: "Complete done" }))
    .toBeVisible();

  // Delete a todo item
  await page
    .getByRole("row", {
      name: `${todoItem} done Complete done Delete delete`,
    })
    .getByRole("button", { name: "Delete delete" })
    .click();

  // Make sure the todo item is not visible now
  await expect(page.getByRole("cell", { name: todoItem }))
    .not.toBeVisible();
});
