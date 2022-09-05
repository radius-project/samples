import * as express from "express";

import { Item, RepostoryFactory } from "../db/repository";

export const register = (app: express.Application, factory: RepostoryFactory) => {
    app.get(`/healthz`, async (req, res) => {
        const respository = await factory.create()
        try {
            res.status(200);
        } finally {
            respository.dispose();
        }
    });

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

    app.post(`/api/todos`, async (req, res) => {
        const respository = await factory.create()
        try {
            const item = req.body as Item;
            const updated = await respository.create(item);

            res.status(200);
            res.json(updated);
        }
        finally {
            await respository.dispose()
        }
    });
};
