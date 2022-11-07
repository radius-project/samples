import { useLoaderData } from "react-router-dom";

export function Index() {
  const { process, env, network } = useLoaderData() as ContainerInfo;
  return <>
    <div className="row p-4">
      <div className="container">
        <h3>Welcome to the Radius Demo</h3>
        <section>This page shows the configuration of the demo application.</section>

        <div className="row py-4">
          <h3>Network</h3>
          <div className="vstack gap-1 bg-light border rounded">
            <div><span className="fw-bold pe-3">Hostname:</span><span className="fw-light">{network.hostname}</span></div>
            <div><span className="fw-bold pe-3">IPs:</span><span className="fw-light">{network.ips.join(" ")}</span></div>
            <div><span className="fw-bold pe-3">Port:</span><span className="fw-light">{network.port}</span></div>
          </div>
        </div>
        <div className="row py-4">
          <h3>Process</h3>
          <div className="vstack gap-1 bg-light border rounded">
            <div><span className="fw-bold pe-3">Command:</span><span className="fw-light">{process.args.join(" ")}</span></div>
            <div><span className="fw-bold pe-3">Working Directory:</span><span className="fw-light">{process.pwd}</span></div>
          </div>
        </div>
        <div className="row py-4">
          <h3>Environment</h3>
          <div className="vstack gap-1 bg-light border rounded">
          <table className="table">
            <thead>
              <tr>
                <th>Key</th>
                <th>Value</th>
              </tr>
            </thead>
            {Object.entries(env).sort(([x], [y]) => x.localeCompare(y)).map(([key, value]) => {
              return <tr><td><b>{key}</b></td><td>{value}</td></tr>
            })}
          </table>
          </div>
        </div>
      </div>
    </div>
  </>;
}

export async function loader() {
  const response = await fetch("/api/container-info");
  return await response.json() as ContainerInfo;
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