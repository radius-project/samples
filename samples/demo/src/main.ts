const { useAzureMonitor, AzureMonitorOpenTelemetryOptions } = require("@azure/monitor-opentelemetry");
const { Resource } = require("@opentelemetry/resources");
const { SemanticResourceAttributes } = require("@opentelemetry/semantic-conventions");

const customResource = new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: "radius-demo-application",
    [SemanticResourceAttributes.SERVICE_NAMESPACE]: "radius-demo-application-ns",
    [SemanticResourceAttributes.SERVICE_INSTANCE_ID]: "radius-demo-application-node2",
  });

const options: typeof AzureMonitorOpenTelemetryOptions = {
resource: customResource
};

if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    useAzureMonitor(options);      // Must be called before importing any packages
}
else {
    console.log("No APPLICATIONINSIGHTS_CONNECTION_STRING found, skipping Azure Monitor setup");
}

import express, { Express } from 'express';
import dotenv from 'dotenv';
import morgan from 'morgan'
import path from 'path';
import * as container from './api/container';
import * as health from './api/health';
import * as todo from './api/todo';
import { createFactory } from './db/repository';

dotenv.config();

const app: Express = express();
const port = process.env.PORT || 3001;

app.use(morgan('short'))

app.use(express.json());
app.use(express.static(path.join(__dirname, "www")));

const factory = createFactory()
container.register(app);
health.register(app, factory);
todo.register(app, factory);

app.get('*', (req: express.Request, res: express.Response) => {
    // Pass through unhandled requests to React.
    res.sendFile(path.resolve(__dirname, "www", 'index.html'));
});

process.on('SIGINT', function () {
    console.log("\nGracefully shutting down from SIGINT (Ctrl-C)");
    process.exit(1);
});

app.listen(port, () => {
    console.log(`Server is running at http://localhost:${port}`);
});