import React from 'react';
import ReactDOM from "react-dom/client";
import {
  createBrowserRouter,
  RouterProvider,
} from "react-router-dom";
import "./index.css";
import './index.css';
import Root from './Root';
import ErrorPage from './ErrorPage';
import reportWebVitals from './reportWebVitals';
import { Index, loader as indexLoader } from './routes/Index';
import Todo from './routes/Todo';
import Request from './routes/Request';

const router = createBrowserRouter([
  {
    path: "/",
    element: <Root />,
    errorElement: <ErrorPage />,
    children: [
      {
        path: "/",
        element: <Index />,
        loader: indexLoader,
      },
      {
        path: "/todo",
        element: <Todo />
      },
      {
        path: "/request",
        element: <Request />
      }
    ]
  },
]);

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);

reportWebVitals();
