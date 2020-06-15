
# ping2me

ping2me is a real time monitoring tool made simple. Configure it to show the status of your endpoints and share it with other teams or publicly.

## Dependencies

Make sure you have these dependencies installed and running:

- [MySQL Server](https://dev.mysql.com/downloads/) or [MariaDB](https://downloads.mariadb.org/)
- [Docker](https://docs.docker.com/get-docker/)

## Features
- Different views
  - Main: Shows information about the hosts, response and code graphs. Incident history is shown if database has been configured
  - Monitor: Shows status from your hosts. It should be used on mobiles or large screens
- Pager Duty on-call
  - Trigger incidents (To be implemented)
  - Retrieve information from schedule and show who is currently on-call
- Report
  - Search issues from the database by filtering the category, host or date/time
  - Graph shows information collected from the database
- SMTP
  - Send emails when the application detects a host down
  - SMTP can be configured to be used locally with or without TLS

## Infrastructure
You can run it with or without database. We store information about previous issues so you can be aware of what happened in the past, if you do not want to store old/previous issues, do not install the crawler nor configure the database.

### Docker Overview
![Docker basic infrastructure](https://github.com/leodamasceno/ping2me/blob/master/img/docker_basic.png)

### Kubernetes Overview
![Kubernetesbasic infrastructure](https://github.com/leodamasceno/ping2me/blob/master/img/kubernetes_basic.png)

## Create the database structure

Connect to your Database with the root user (Or a similar user with admin privileges), then create the application
username, set a password and give it access to the ping2me database:
```
CREATE USER 'NEW_USER'@'%' IDENTIFIED BY 'NEW_USER_PASSWORD';
GRANT ALL PRIVILEGES ON ping2me.* TO 'NEW_USER'@'%';
```

**DO NOT** forget to change *NEW_USER* and *NEW_USER* to your respective username and password.

Run the SQL script *database/db.sql* from this repository:
```
mysql -u root -h DB_HOST -p < db.sql
```

**DO NOT** forget to change *DB_HOST* to the IP of your database server.

## Configuration

You can find the config.yaml file for the **API** here. Update it and you should be good to go. Check the example below:
**API**:
```
config:
  database:
    host: "192.168.1.65"
    username: admin
  oncall:
    token: ybEuxrDK-nhtCaPY7X2N
    escalation_id: ELQ9MXQ
  smtp:
    address: smtp.example.com
    port: 587
    tls: false
    username: auth-user@example.com
    receiver: email-to@example.com
  checks:
    General:
      Website:
        url: "https://www.example.com"
        health_path: /
        health_code:
        - 200
    Team1:
      API:
        url: "https://api.example.com"
        health_path: /status
        health_code:
        - 200
    Team2:
      API:
        url: "http://api.example2.com"
        health_path: /test
        health_code:
        - 200
      APIv2:
        url: "http://api-v2.example2.com"
        health_path: /
        health_code:
        - 200
```

Only specify the *oncall* section if you want to enable the [PagerDuty](https://www.pagerduty.com/) integration. You will need to provide an *API Token* and the *Escalation ID*. The smtp section can also be omitted.
Do not specify the *database* section if you do not want to store information about issues. The application will understand that and show you ONLY real time data. Look at the following example:
```
config:
  checks:
    Team1:
      API:
        url: "https://api.example.com"
        health_path: /status
        health_code:
        - 200
    Team2:
      API:
        url: "http://api.example2.com"
        health_path: /test
        health_code:
        - 200
      APIv2:
        url: "http://api-v2.example2.com"
        health_path: /
        health_code:
        - 200
```

## Configure your DNS
Configure a DNS entry to point to the *UI* so you can access the application via web, an example: *status.yourcompany.com*.
If you wish to use SSL certificates, configure the *UI* and the *API*, you will see the [Mixed Content](https://developers.google.com/web/fundamentals/security/prevent-mixed-content/what-is-mixed-content) error otherwise.

## Running ping2me locally
All three components can be run on Docker or Kubernetes. Choose which one you want to run the application on and follow the guide below.

### *Docker*

#### Firewall
Make sure the host/server you are going to use to run the docker containers below do not have firewall rules blocking the outgoing traffic. As an example, this can happen if you install docker on a CentOS, you may need to disable firewalld.

#### API
The **API** should be the first component to be run. It is responsible to receive requests from the **UI** and execute functions to return information, such as host availability.
```
docker run --rm -d -p 4567:4567 \
--env DB_PASSWORD=MY_PW \
-v /tmp/config.yaml:/app/config.yaml \
--name ping2me-api damasceno/ping2me-api:latest
```
**DO NOT** forget to change the password from *MY_PW* to your own database password.
Remove the *DB_PASSWORD* environment variable if you do not want to connect the API to a database.

#### Crawler
This component keeps the checks alive on the server-side. It will populate the database to store issues. Run the command below:
```
docker run --rm -d --name ping2me-crawler \
--env DB_PASSWORD=MY_PW \
--env SMTP_PASSWORD=MY_PW \
--env API_URL=http://MY_API_URL:4567 \
--env INTERVAL=30 \
damasceno/ping2me-crawler:latest
```
**DO NOT** forget to change the password from *MY_PW* to your own database and/or smtp password.

The interval must not be lower than 30 to avoid several connections to the database. If not value is specified, the crawler will have 30 as the default value.

#### UI
The UI will show you all the information gathered by the *Crawler* and the *API*:
```
docker run --rm -d -p 80:80 --name ping2me-ui \
--env API_URL=http://MY_API_URL:4567 \
damasceno/ping2me-ui:latest
```
**DO NOT** forget to change the *API* url from *MY_API_URL* to the IP or domain configured.
Also, the *UI* will be accessible via port 80 (HTTP) in the example above, make sure to change it to 443 (HTTPS) if you intend to configure your SSL certificate or simply add a nginx proxy to redirect requests to it.

### *Kubernetes*
Create a secret to store the database password:
```
kubectl create secret generic ping2me-app --from-literal=db_password=MY_PW --from-literal=smtp_password=MY_PW
```
**DO NOT** forget to change *MY_PW* to your database password.

Create a configmap to store the API configuration, which will include:
- Database host and username
- Checks (Hosts, health path, health code)
- PagerDuty Integration (Show the on-call information)
```
kubectl create configmap ping2me-api-config --from-file=/tmp/config.yaml
```

#### API
Edit the file *kubernetes/deployment-api.yaml* to update values like:
- Namespace
- Docker image version

And execute:
```
kubectl create -f kubernetes/deployment-api.yaml
```

#### Crawler

#### UI
Edit the file *kubernetes/deployment-ui.yaml* to update the *API_URL* environment variable. Then create the deployment:
```
kubectl create -f kubernetes/deployment-api.yaml
```
The deployment of the components is done. Now, expose them:
```
kubectl create -f kubernetes/service-api.yaml
kubectl create -f kubernetes/service-ui.yaml
```
The *Crawler* does not need to be exposed since it is a background service.
Create ingresses for the *API* and the *UI*, but make sure to edit the files to change the host. For instance, if you want to create DNS entries like *status.yourcompany.com* and *api.yourcompany.com*, specify them in the ingresses to make both components accessible. Check the example below:
```
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: ping2me-api
  namespace: tests
spec:
  rules:
  - host: api.yourcompany.com
    http:
      paths:
      - backend:
          serviceName: ping2me-api
          servicePort: 4567
```
**IMPORTANT**: This will create a public endpoint (Load Balancer).
**IMPORTANT**: The example above will allow you to access the endpoints via port 80 (HTTP). You need to configure the SSL certificates in order to have both endpoints over HTTPS. Check the [official documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/) to learn how to configure it.

Once the files are correct, execute the following commands to create both accessible endpoints:
```
kubectl create -f kubernetes/ingress-api.yaml
kubectl create -f kubernetes/ingress-ui.yaml
```
Your cloud provider will provision a Load Balancer with an IP Address attached to it, copy it and create the DNS entries.

## All done

You can now try to access the **UI** via the URL *http://DOCKER_HOST_IP* or *http://LOAD_BALANCER_IP*. Use the name if you have configured a DNS entry to point to the IP Address mentioned before. 

## Copyright

© 2020, [ping2me](https://www.ping2me.io). Monitoring solution made simple to share the status of your endpoints.
