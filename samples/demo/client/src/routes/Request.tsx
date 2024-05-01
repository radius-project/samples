import React from "react";

export default function Request() {
    const [response, setResponse] = React.useState("")
    const [url, setUrl] = React.useState("http://backend:80");
    const [method, setMethod] = React.useState("GET");
    const [body, setBody] = React.useState("");
    const [reloadCount, setReloadCount] = React.useState(0);

    React.useEffect(() => {
        let mounted = true;
        const worker = async () => {
            const response = await fetch(url, {
                mode: "no-cors",
                method: method,
                body: method === "GET" ? undefined : body,
            });
            if (mounted) {
                setResponse(await response.text());
                // Print response text to console
                console.log(await response.text());
            }
        };
        worker();
        return () => {
            mounted = false;
        }
    }, [body, method, reloadCount, url])

    return (
        <div>
            <h1>Request</h1>
            <div>
                <label>URL</label>
                <input type="text" value={url} onChange={(e) => setUrl(e.target.value)} />
            </div>
            <div>
                <label>Method</label>
                <select value={method} onChange={(e) => setMethod(e.target.value)}>
                    <option>GET</option>
                    <option>POST</option>
                </select>
            </div>
            <div>
                <label>Body</label>
                <textarea value={body} onChange={(e) => setBody(e.target.value)} />
            </div>
            <div>
                <button onClick={() => setReloadCount(reloadCount + 1)}>Send</button>
            </div>
            <div>
                <pre>{response}</pre>
                {reloadCount}
            </div>
        </div>
    );
}
