# Kubernetes Guestbook application example

This is an example containerized Guestbook application originally authored by the Kubernetes community for use in their own tutorial. The application's Kubernetes deployment manifests are contained in the `deploy` directory. 

The Guestbook application consists of a web front end along with primary and secondary Redis containers for storage, all deployed with Kubernetes. For more information about the application, see the [Kubernetes tutorial](https://kubernetes.io/docs/tutorials/stateless-application/guestbook/).