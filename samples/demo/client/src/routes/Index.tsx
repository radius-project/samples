import { useLoaderData } from "react-router-dom";
import { useState, useEffect } from "react";

export function Index() {
  const data = useLoaderData() as ContainerInfo | { error: string };
  const [containerInfo, setContainerInfo] = useState<ContainerInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if ('error' in data) {
      setError(data.error);
    } else {
      setContainerInfo(data as ContainerInfo);
    }
  }, [data]);

  if (error) {
    return (
      <div className="container-md">
        <div className="row p-4">
          <div className="container">
            <h1>Welcome to the Radius demo</h1>
            <p>This demo container will showcase Radius features and configuration.</p>
            <div className="alert alert-warning">
              <p>Could not connect to the backend server: {error}</p>
              <p>Make sure the server is running on port 3001.</p>
            </div>
          </div>
        </div>
        <div className="row p-4">
          <div className="container">
            <h2>Todo List</h2>
            <p>Visit the Todo List page to try interacting with external dependencies</p>
            <button className="btn btn-primary" onClick={() => window.location.href = "/todo"}>🚀 Todo List</button>
          </div>
        </div>
      </div>
    );
  }

  if (!containerInfo) {
    return (
      <div className="container-md">
        <div className="row p-4">
          <div className="container">
            <h1>Welcome to the Radius demo</h1>
            <p>Loading container information...</p>
          </div>
        </div>
      </div>
    );
  }

  // Find all environment variables that start with CONNECTION_
  const connections = Object.entries(containerInfo.env).filter(([key, value]) => key.startsWith("CONNECTION_"));
  // Now split the key into parts between _, and find all unique second parts
  const uniqueConnections = Array.from(new Set(connections.map(([key, value]) => key.split("_")[1])));

  return <>
    <div className="container-md">
      <div className="row p-4">
        <div className="container">
          <h1>Welcome to the Radius demo</h1>
          <p>This demo container will showcase Radius features and configuration.</p>
        </div>
      </div>

      <div className="row p-4">
        <div className="container">
          <h2>Radius Connections</h2>
          <p>See all the connections this container has to other resources within the application</p>

          {uniqueConnections.length === 0 && <div className="alert alert-secondary">No connections defined</div>}

          <div className="accordion" id="connectionSection">
            {
              uniqueConnections.map(connection => {
                return <div className="accordion-item" key={connection}>
                  <h2 className="accordion-header">
                    <button className="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target={`#connection_${connection}`} aria-expanded="false" aria-controls={`connection_${connection}`}>
                      <b>🔗 {connection}</b>
                    </button>
                  </h2>
                  <div id={`connection_${connection}`} className="accordion-collapse collapse" data-bs-parent="#connectionSection">
                    <div className="accordion-body">
                      <h5>Environment variables</h5>
                      <p>These environment variables are available to the container and are set automatically by Radius</p>
                      <ul>
                        {connections.filter(([key, value]) => key.startsWith(`CONNECTION_${connection}_`)).map(([key, value]) => {
                          return <li key={key}><b>{key}</b>: {value}</li>
                        })}
                      </ul>
                    </div>
                  </div>
                </div>
              })
            }
          </div>
        </div>
      </div>

      <div className="row p-4">
        <div className="container">
          <h2>Container Metadata</h2>
          <p>Learn about the running container and its configuration</p>

          <div className="accordion" id="metadataSection">
            <div className="accordion-item">
              <h2 className="accordion-header">
                <button className="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#networkMetadata" aria-expanded="false" aria-controls="networkMetadata">
                  <b>🌎 Network configuration</b>
                </button>
              </h2>
              <div id="networkMetadata" className="accordion-collapse collapse" data-bs-parent="#metadataSection">
                <div className="accordion-body">
                  <div className="vstack gap-1 bg-light border rounded">
                    <div><span className="fw-bold pe-3">Hostname:</span><span className="fw-light">{containerInfo.network.hostname}</span></div>
                    <div><span className="fw-bold pe-3">IPs:</span><span className="fw-light">{containerInfo.network.ips.join(" ")}</span></div>
                    <div><span className="fw-bold pe-3">Port:</span><span className="fw-light">{containerInfo.network.port}</span></div>
                  </div>
                </div>
              </div>
            </div>
            <div className="accordion-item">
              <h2 className="accordion-header">
                <button className="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#processMetadata" aria-expanded="false" aria-controls="processMetadata">
                  <b>🖥️ Process information</b>
                </button>
              </h2>
              <div id="processMetadata" className="accordion-collapse collapse" data-bs-parent="#metadataSection">
                <div className="accordion-body">
                  <div className="vstack gap-1 bg-light border rounded">
                    <div><span className="fw-bold pe-3">Command:</span><span className="fw-light">{containerInfo.process.args.join(" ")}</span></div>
                    <div><span className="fw-bold pe-3">Working Directory:</span><span className="fw-light">{containerInfo.process.pwd}</span></div>
                  </div>
                </div>
              </div>
            </div>
            <div className="accordion-item">
              <h2 className="accordion-header">
                <button className="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#environmentMetadata" aria-expanded="false" aria-controls="environmentMetadata">
                  <b>📄 Environment variables</b>
                </button>
              </h2>
              <div id="environmentMetadata" className="accordion-collapse collapse" data-bs-parent="#metadataSection">
                <div className="accordion-body">
                  <div className="vstack gap-1 bg-light border rounded">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>Key</th>
                          <th>Value</th>
                        </tr>
                      </thead>
                      <tbody>
                        {Object.entries(containerInfo.env).sort(([x], [y]) => x.localeCompare(y)).map(([key, value]) => {
                          return <tr key={key}><td><b>{key}</b></td><td>{value}</td></tr>
                        })}
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="row p-4">
        <div className="container">
          <h2>Todo List</h2>
          <p>Visit the Todo List page to try interacting with external dependencies</p>
          <button className="btn btn-primary" onClick={() => window.location.href = "/todo"}>🚀 Todo List</button>
        </div>
      </div>
    </div>
  </>;
}

export async function loader() {
  try {
    const response = await fetch("/api/container-info");
    if (!response.ok) {
      return { error: `Server responded with status ${response.status}` };
    }
    return await response.json() as ContainerInfo;
  } catch (error: any) {
    console.error("Error loading container info:", error);
    return { error: error.message || "Failed to connect to the server" };
  }
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