import axios from "axios";

export async function waitForWebApp(url: string | undefined, timeout = 60000) {
  if (!url) {
    throw new Error("URL is not defined");
  }

  const startTime = Date.now();
  while (true) {
    try {
      await axios.get(url);
      console.log(`Web application is ready: ${url}`);
      break;
    } catch (error) {
      console.log(`Web application is not ready: ${url}`);
      if (Date.now() - startTime > timeout) {
        throw new Error(
          `Web application not ready after ${timeout} ms: ${url}`
        );
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}
