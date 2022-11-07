import os from 'os'
import * as express from "express";

export const register = (app: express.Application) => {
  app.get('/api/container-info', async (req: express.Request, res: express.Response) => {
    const env : Record<string, string> = Object.entries(process.env).reduce((prev, [key, value]) : Record<string, string> => {
      prev[key] = value || "";
      return prev;
    }, {} as Record<string, string>);
  
    const ips : string[] = Object.entries(os.networkInterfaces()).map(([_, interfaces]) => {
      if (!interfaces) {
        return undefined;
      }
      return interfaces.filter(iface => iface.family == "IPv4").map(iface => iface.address)
    }).filter(value => !!value).flatMap(value => value) as string[];
  
    const info : ContainerInfo = {
      process: {
        args: process.argv,
        pwd: process.cwd(),
      },
      env: env,
      network: {
        hostname: os.hostname(),
        ips: ips,
        port: (process.env.PORT || 3001).toString(),
      }
    }
    res.json(info);
  });
}

interface ContainerInfo {
  process: Process
  env: Record<string, string>
  network: Network
}

interface Process {
  args: string[]
  pwd: string
}

interface Network {
  hostname: string
  ips: string[]
  port: string
}