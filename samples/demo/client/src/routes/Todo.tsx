import React, { ChangeEvent, FormEvent } from "react";

interface Item {
  id: string | undefined
  title: string
  done: boolean
}

interface ItemResponse {
  message: string
  items: Item[]
}

const listItems = async (): Promise<ItemResponse> => {
  try {
    const response = await fetch("/api/todos");
    if (!response.ok) {
      throw new Error(`Server responded with status ${response.status}`);
    }
    return await response.json() as ItemResponse;
  } catch (error: any) {
    console.error("Error fetching todos:", error);
    return { message: `Error: ${error.message || "Failed to connect to server"}`, items: [] };
  }
}

const createItem = async (item: Item) => {
  await fetch("/api/todos", {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(item),
  });
}

const updateItem = async (item: Item) => {
  await fetch(`/api/todos/${item.id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(item),
  });
}

const deleteItem = async (item: Item) => {
  await fetch(`/api/todos/${item.id}`, {
    method: 'DELETE',
  });
}

export default function Todo() {
  const [reloadCount, setReloadCount] = React.useState(0);
  const [response, setResponse] = React.useState<ItemResponse | null>(null)
  const [error, setError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(true);

  const [title, setTitle] = React.useState("");

  React.useEffect(() => {
    let mounted = true;
    setLoading(true);
    const worker = async () => {
      try {
        const response = await listItems();
        if (mounted) {
          setResponse(response);
          setError(null);
        }
      } catch (err: any) {
        if (mounted) {
          setError(err.message || "Failed to load todos");
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };
    worker();
    return () => {
      mounted = false;
    }
  }, [reloadCount])

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    setTitle(e.target.value)
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const item = { title: title, done: false, id: undefined }
    setTitle("");
    createItem(item).then(() => {
      setReloadCount(reloadCount + 1);
    });
  }

  const handleDelete = (item: Item) => {
    deleteItem(item).then(() => setReloadCount(reloadCount + 1));
  }

  const handleComplete = (item: Item) => {
    item.done = true
    updateItem(item).then(() => setReloadCount(reloadCount + 1));
  }

  if (loading) {
    return <p>Loading...</p>;
  }

  return <>
    <div className="row">
      <div className="col-8 p-4">
        <div className="container">
          <h3>Todo list</h3>
          {error && <h6 className="text-danger">{error}</h6>}
          {response?.message !== "" && <h6 className="text-secondary">{response?.message}</h6>}
          {response?.items && response.items.length > 0 ?
            <table className="table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {response.items.map(item => {
                  return <>
                    <tr>
                      <td>{item.title}</td>
                      <td>
                        <span className="material-icons">{item.done ? "done" : "lightbulb"}</span>
                      </td>
                      <td>
                        <button className="btn btn-small btn-outline-success mx-1" onClick={e => handleComplete(item)}>
                          Complete <i className="material-icons ms-4 align-top">done</i>
                        </button>
                        <button className="btn btn-small btn-outline-danger mx-1" onClick={e => handleDelete(item)}>
                          Delete <i className="material-icons ms-4 align-top">delete</i>
                        </button>
                      </td>
                    </tr>
                  </>;
                })}
              </tbody>
            </table> :
            <p>No items yet!</p>
          }
        </div>
      </div>
      <div className="col-4 p-4 bg-gradient bg-secondary bg-opacity-25 edit-sidebar vh-100">
        <h3>Add an item</h3>
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label className="form-label" htmlFor="titleInput">Title</label>
            <input id="titleInput" placeholder="What do you need to do?" type="text" className="form-control" value={title} onChange={handleChange} />
          </div>
          <button className="btn btn-small btn-outline-primary px-3 " type="submit">Add<i className="material-icons ms-4 align-top">send</i></button>
        </form>
      </div>
    </div>
  </>;
}