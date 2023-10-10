import * as express from "express";
import { RepositoryFactory } from "../db/repository";

export const register = (app: express.Application, factory: RepositoryFactory) => {
    app.get(`/healthz`, async (req: express.Request, res: express.Response) => {
        const respository = await factory.create()
        try {
            res.status(200);
            res.json({status : "OK"});
        } finally {
            await respository.dispose();
        }
    });
}