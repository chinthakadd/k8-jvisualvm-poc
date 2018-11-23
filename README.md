#  How to use JVisualVM and Java Mission Control to monitor JVM of pods in Kubernetes

I thought of writing this as it is useful starting point for any developer who wants to start
monitoring the JVMs of containers running as Kubernetes Pods.
As I experienced during last few months, JVM optimization is one of the biggest challenges that
enterprises face in moving towards Cloud Platforms with Java based microservices.
As often heard from many platform engineers, Java is "hungry" for Resources. It is true to a certain
extent. Specifically if you have not sized your JVM properly using the boundary values for different
segments of your JVM, it is definitely going to become a memory hungry beast and eventually kill
a node or two in your cluster.  So today, I am not intending to solve this entire problem. The
idea is to first get an idea of how a simple java - spring boot based application would consume
in terms of memory.

Though there are many elegant solutions for monitoring tools available out there, I am going to
start with the basics of tools that every java installation would come along with. Something
that works in your local. Something that you can start right away with to understand how your
teeny-tiny microservice is dealing with memory. It is called [JVisualVM](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/jvisualvm.html).
One more tool that Java ships with is [Java Mission Control (JMC)](https://www.oracle.com/technetwork/java/javaseproducts/mission-control/index.html),
which has some more features available if you have the commercial license.
These are standard monitoring tools that rely upon [JMX Technology](https://docs.oracle.com/javase/7/docs/technotes/guides/management/agent.html)
 to connect with JVM based applications that expose their JVM metrics through a JMX endpoint.

If you want to monitor an application that runs in your
localhost, it is extremely simple.
- Run `jvisualvm` command to start jvisualvm or `jmc` commands to start java mission control.
- Then start your application in localhost. Immediately you will see that your application is detected.
Since java 6 SE, it automatically enables java agents running locally to monitor applications that are
started locally. Therefore automatically you would see your java applications like Spring boot ones being
displayed in `jvisualvm`. See below.

![Spring Boot App shown in JVisualVM](https://github.com/chinthakadd/tech-notes/blob/master/kubernetes/images/jvisualvm-local.png)

But our objective today is to monitor a Spring Boot Application deployed kubernetes.
Java by default does not enable remove agents to connect to JVM's JMX attach APIs, obviously for
security reasons.

There are many properties that needs to enabled at the JVM to ensure the remote monitoring and management
can be done. So now, assuming that you have a kubernetes deployment that contains a pod with your
Java based microservice, next step is to understand what are the JVM parameters that you need
to enable to ensure the remote connections to JMX can be made.

Lets first understand those JVM arguments.

- `-Dcom.sun.management.jmxremote` (Enabling JMX Clients to access the JVM.)

- `-Dcom.sun.management.jmxremote.port=9999` (JMX Attach APIs will exposed through port 9999)


- `-Dcom.sun.management.jmxremote.rmi.port=9999` (It is required that we set RMI Port the same port.
  Reason will be more clearer when you realize what we do next. Essentially, we need a single
  port from the POD container that can expose both JMX attach APIs as well as RMI)

- `-Dcom.sun.management.jmxremote.authenticate=false` (We are setting this to false. Yes not a
  good security practice. But we are friends here. Only in our dev cluster right? :) )

- `-Dcom.sun.management.jmxremote.ssl=false` (Again, for now disabling SSL.)

- `-Djava.rmi.server.hostname=127.0.0.1` (This is important. Again, you may wonder
  how localhost IP would work here. Are we running minikube? No this will work even
  for remote clusters. Thats' the funny part)

We will get to the question on server hostname being localhost in a bit.

First thing, how do I easily add these to my pod deployment?
Do I have to change my Dockerfile to include these arguments at the entry point? No.
A simple trick is to offload these to the Kubernetes Deployment resource and inject
them to the container as environment variables. Simple right? Here is a sample
Deployment yaml.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: k8-jvisualvm-poc
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: k8-jvisualvm-poc
  template:
    metadata:
      labels:
        app: k8-jvisualvm-poc
    spec:
      containers:
      - name: k8-jvisualvm-poc
        image: chinthaka316/k8-jvisualvm-poc:latest
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        imagePullPolicy: Always
        env:
          ## This is the environment property which we use to inject all the required JMX related system properties
        - name: JAVA_TOOL_OPTIONS
          value: -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.rmi.port=9999 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1
```

## Finally, connecting to the Remote Host

Now we want to connect to the running pod. My container is running as following.

```
$ kubectl get pods|grep k8-jvisualvm-poc
k8-jvisualvm-poc-b54569c89-k2nld   1/1       Running   0          4m
```

Lets use `kubectl port-forward` to tunnel the container port 9999 JMX endpoint
to localhost's 9999 port.

```
$ kubectl port-forward $(kubectl get pods -n default|grep k8-jvisualvm-poc|awk '{print $1}') 9999:9999
Forwarding from 127.0.0.1:9999 -> 9999
Forwarding from [::1]:9999 -> 9999
```

Now, simply we can add a new connection in JVisualVM as below.

![Adding new connection](https://github.com/chinthakadd/tech-notes/blob/master/kubernetes/images/jvisualvm-k8-connect.png)

Voila.! You should see your application monitored as below.

![Application Deployed in Kubernetes](https://github.com/chinthakadd/tech-notes/blob/master/kubernetes/images/jvisualvm-k8-poc.png)

You can do the same with Java Mission Control as well. Simply add a new jmx connection with same
properties as above.

You can find all resources related to this blogpost in:
https://github.com/chinthakadd/k8-jvisualvm-poc

## What's Next?

Some of the topics that I have been interested in looking into are follows.

- Learn about JVM deeply to understand what are most important boundary parameters
that needs to be set.
- Understand Kubernetes resource limit concept, Specially on CPU and memory
- Learn about Spring Boot with MicroMeter and what metrics that we can expose
- How to effectively use Prometheus and Grafana in combination to extract
useful metrics out of Spring Boot Applications and do pod level monitoring

## References:

https://fedidat.com/250-jvisualvm-openshift-pod/
http://darksideofthedev.com/java-profiling-with-visualvm-in-docker-container/
http://www.adam-bien.com/roller/abien/entry/how_to_establish_jmx_connection
