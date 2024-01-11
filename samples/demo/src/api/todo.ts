import * as express from "express";
import { Item, RepositoryFactory } from "../db/repository";

export const register = (app: express.Application, factory: RepositoryFactory) => {
    app.get(`/api/todos`, async (req, res) => {
        const respository = await factory.create()
        try {
            const items = await respository.list()

            let message: string | null = null;
            if (!respository.isRealDatabase()) {
                message = "No database is configured, items will be stored in memory.";
            }

            res.status(200);
            res.json({ items: items, message: message })
        } finally {
            respository.dispose();
        }
    });

    app.get(`/api/todos/:id`, async (req, res) => {
        const respository = await factory.create()
        try {
            const id = req.params.id;
            const item = await respository.get(id);
            if (!item) {
                res.sendStatus(404);
                return
            }

            res.status(200);
            res.json(item);
        }
        finally {
            respository.dispose();
        }
    });

    app.delete(`/api/todos/:id`, async (req, res) => {
        const respository = await factory.create()
        try {
            const id = req.params.id;
            await respository.delete(id);

            res.sendStatus(204);
        }
        finally {
            respository.dispose();
        }
    });

    app.put(`/api/todos/:id`, async (req, res) => {
        const respository = await factory.create()
        try {
            const item = req.body as Item;
            item.id = req.params.id

            const updated = await respository.update(item);
            if (!updated) {
                res.sendStatus(404);
                return
            }

            res.status(200);
            res.json(updated);
        }
        finally {
            await respository.dispose()
        }
    });

    // Get the failure rate from the environment variable RADIUS_DEMO_FAILURE_RATE. This is a percentage that defaults to 100
    const radiusDemoFailureRate = parseFloat(process.env.RADIUS_DEMO_FAILURE_RATE || '100') / 100;

    // Environment variable that controls if the failure simulation is enabled. Defaults to 0 (disabled).
    const radiusDemoFailureEnabled = parseInt(process.env.RADIUS_DEMO_FAILURE_ENABLED || '0');

    app.post(`/api/todos`, async (req, res) => {
        const respository = await factory.create()
        try {
            const item = req.body as Item;

            // Titles that end with a space are used to simulate an error condition and return a 500.
            if (item && item.title && item.title.endsWith(' ') && radiusDemoFailureEnabled > 0) {
                // To make the error condition a little more unpredictable, we also read the FAILURE_RATE env
                // variable which represents the percentage of requests that will fail. For example, setting
                // FAILURE_RATE to 30 means tht 30% of requests that end with a space will fail.
                if(Math.random() < radiusDemoFailureRate) {
                    res.status(500).json({ error: 'Server fault' });
                    return;
                }
            }

            const updated = await respository.create(item);
            res.status(200);
            res.json(updated);
        }
        finally {
            await respository.dispose()
        }
    });};
