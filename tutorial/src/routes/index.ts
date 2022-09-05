import * as express from "express";
import { RepostoryFactory } from "../db/repository";
import * as api from "./api";

export const register = (app: express.Application, factory: RepostoryFactory) => {
    app.get("/", (req: any, res) => {
        res.render("index");
    });

    api.register(app, factory);
};
