# Kubernetes Guestbook application example

This is an example containerized Guestbook application originally authored by the Kubernetes community for use in their own tutorial. The application's Kubernetes deployment manifests copied over from the Kubernetes source [repo](https://github.com/kubernetes/examples/tree/master/guestbook) are contained in the `deploy` directory. 

The Guestbook application consists of a web front end along with primary and secondary Redis containers for storage, all deployed with Kubernetes. For more information about the application and access its source code, see the [Kubernetes tutorial](https://kubernetes.io/docs/tutorials/stateless-application/guestbook/) and their [examples repo](https://github.com/kubernetes/examples/tree/master/guestbook).