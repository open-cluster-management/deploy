# Guest Book

- Create from within this directory, in a terminal window run:
    ```bash
    kubectl create namespace demo-guestbook
    kubectl apply -k .
    ```

- Remove
    ```bash
    kubectl delete -k .
    kubectl delete namespace demo-guestbook
    ```