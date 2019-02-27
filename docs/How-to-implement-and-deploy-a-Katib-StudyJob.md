# How to implement and deploy a Katib StudyJob

Katib optimizes black boxes with tuning parameters as inputs
and objectives as output.  Katib searches for the parameter values 
that optimize the objective.  A StudyJob implements this search. 

## Katib Docker
The black box is implemented as Docker.  The parameter inputs are
just command line options, and output objective is just printed to 
stdout in the form "<name>=<value>"

Here is a trivial example katib-test.py that takes a single tuning parameter '--x'
and produces a metric 'z' and an objective 'y'.  The objective is optimized
at x = -0.25

```
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--x",type=float,help="Input X tuning parameter")
args = parser.parse_args()
x = args.x
z = x+0.25
y = 1.0-(z*z)
print("y=%f" % y)
print("z=%f" % z)
```

## Katib YAML

The search is specified by a YAML file.  It lists the parameters,
objective and interesting metrics, as well as information such as 
bounds on parameters and suggested search algorithm.

For complete documentation on Katib YAML files see XXX.

Here is a sample YAML that goes with the above code

```
apiVersion: "kubeflow.org/v1alpha1"
kind: StudyJob
metadata:
  namespace: kubeflow
  labels:
    controller-tools.k8s.io: "1.0"
  name: katib-test
spec:
  studyName: katib-test
  owner: crd
  optimizationtype: maximize
  objectivevaluename: "y"
  optimizationgoal: 1.0
  requestcount: 4
  metricsnames:
    - "z"
  parameterconfigs:
    - name: --x
      parametertype: double
      feasible:
        min: "-1.0"
        max: "1.0"
  workerSpec:
    goTemplate:
        rawTemplate: |-
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: {{.WorkerID}}
            namespace: kubeflow
          spec:
            template:
              spec:
                containers:
                - name: {{.WorkerID}}
                  image: gcr.io/aml-dev/katib/katib-pw6:latest
                  command:
                  - "python"
                  - "katib-test.py"
                  {{- with .HyperParameters}}
                  {{- range .}}
                  - "{{.Name}}={{.Value}}"
                  {{- end}}
                  {{- end}}
                restartPolicy: Never
  suggestionSpec:
    suggestionAlgorithm: "random"
    requestNumber: 3
```

To deploy a Katlib StudyJob build a Docker that implements the API
described above.  Push the Docker to a registry visible to Katib.
If you are running on the Google Cloud, the Google Cloud Registry
is support by default.

[documentation on Kubernetes and Docker images]: https://kubernetes.io/docs/concepts/containers/images/
[documentation on Google Cloud Image Registry]: https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app

Here is some sample commands that build and push the above code
```
export PROJECT_ID="$(gcloud config get-value project -q)"
docker build -t gcr.io/${PROJECT_ID}/katib/katib-test .
docker push gcr.io/${PROJECT_ID}/katib/katib-test
```

## Create the StudyJob

Create the Study using the above YAML file.  The YAML references the Docker image 
created from the above code.  Katib will create Trials using this Docker with 
parameters as directed by the Suggestion algorithms.  It will search for the 
parameters that optimize the objective declared in the YAML and outputed by the code.
```buildoutcfg
kubectl create -f katib-test.yaml
```

## Katib UI

To monitor the study with the Katib UI, port forward the service using ambassador, 
then go to localhost:8080 with your browser and select Katib tab, and then the Study List.  

```buildoutcfg
export NAMESPACE=kubeflow
kubectl port-forward svc/ambassador -n ${NAMESPACE} 8080:80
```

## Katib Log

To get the id of the studyjob controller
```buildoutcfg
kubectl get po -n kubeflow  | grep studyjob
```

To monitor the log of studyjob controller
```buildoutcfg
kubectl logs studyjob-controller-774d45f695-cgqb5 -n kubeflow
```

Note that an issue in 0.3 (fixed in 0.4) will cause mistakes in the YAML to 
kill the studyjob controller.  The solution is to delete all studyjobs
```buildoutcfg
kubectl get studyjob -n kubeflow |awk '{print $1}' | xargs kubectl -n kubeflow delete studyjob
```

