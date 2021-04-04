// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

public enum ResourceConstants: String {
    /// Logical name of the service. MUST be the same for all instances of horizontally scaled services.
    case serviceName = "service.name";
    /// A namespace for `service.name`. A string value having a meaning that helps to distinguish a group of services,
    case serviceNamespace = "service.namespace"
    /// The string ID of the service instance. MUST be unique for each instance of the same
    case serviceInstance = "service.instance.id"
    /// The version string of the service API or implementation.
    case serviceVersion = "service.version"
    
    /// The name of the telemetry SDK.
    case telemetrySdkName = "telemetry.sdk.name"
    /// The language of the telemetry SDK.
    case telemetrySdkLanguage = "telemetry.sdk.language"
    /// The version string of the telemetry SDK.
    case telemetrySdkVersion = "telemetry.sdk.version"
    
    /// The name of the telemetry library.
    case libraryName = "library.name"
    /// The language of telemetry library and of the code instrumented with it.
    case libraryLanguage = "library.language"
    /// The version string of the library.
    case libraryVersion = "library.version"
    
    /// Container name.
    case containerName = "container.name"
    /// Name of the image the container was built on.
    case containerImageName = "container.image.name"
    /// Container image tag.
    case containerImageTag = "container.image.tag"
    /// Container ID. Usually a UUID, as for example used to identify Docker containers. The UUID might be abbreviated
    case containerId = "container.id"
    /// The container runtime managing this container
    case containerRuntime = "container.runtime"
    
    /// Name of the deployment environment (aka deployment tier).
    ///
    /// Examples: "staging", "production"
    case deploymentEnvironment = "deployment.environment"
    
    /// Hostname of the host. It contains what the `hostname` command returns on the host machine.
    case hostHostname = "host.hostname"
    /// Unique host id. For Cloud this must be the instance_id assigned by the cloud provider.
    case hostId = "host.id"
    /// Name of the host. It may contain what `hostname` returns on Unix systems, the fully qualified, or a name specified by the user.
    case hostName = "host.name"
    /// Type of host. For Cloud this must be the machine type.
    case hostType = "host.type"
    /// The CPU architecture the host system is running on
    case hostArch = "host.arch"
    /// Name of the VM image or OS install the host was instantiated from.
    case hostImageName = "host.image.name"
    /// VM image id. For Cloud, this value is from the provider.
    case hostImageId = "host.image.id"
    /// The version string of the VM image.
    case hostImageVersion = "host.image.version"
    
    /// The operating system type
    case osType = "os.type"
    /// Human readable (not intended to be parsed) OS version information, like e.g. reported by ver or lsb_release -a commands.
    case osDescription = "os.description"
    
    /// Name of the cloud provider.
    case cloudProvider = "cloud.provider"
    /// The cloud account id used to identify different entities.
    case cloudAccount = "cloud.account.id"
    /// A specific geographical location where different entities can run.
    case cloudRegion = "cloud.region"
    /// Zones are a sub set of the region connected through low-latency links.
    case cloudZone = "cloud.zone"
    /// Cloud regions often have multiple, isolated locations known as zones to increase availability. Availability zone represents the zone where the resource is running.
    case cloudAvailabilityZone = "cloud.availability_zone"
    /// The cloud platform in use
    case cloudPlatform = "cloud.platform"
    
    /// The name of the function being executed
    case faasName = "faas.name"
    /// The unique ID of the function being executed
    case faasId = "faas.id"
    /// The version string of the function being executed as defined in Version Attributes.
    case faasVersion = "faas.version"
    /// The execution environment ID as a string
    case faasInstance = "faas.instance"
    /// The amount of memory available to the serverless function in MiB
    case faasMaxMemory = "faas.max_memory"
    
    /// The name of the cluster that the pod is running in.
    case k8sCluster = "k8s.cluster.name"
    /// The name of the Node
    case k8sNodeName = "k8s.node.name"
    /// The UID of the Node
    case k8sNodeUid = "k8s.node.uid"
    /// The name of the namespace that the pod is running in.
    case k8sNamespace = "k8s.namespace.name"
    /// The name of the pod.
    case k8sPod = "k8s.pod.name"
    /// The UID of the Pod.
    case k8sPodUid = "k8s.pod.uid"
    /// The name of the Container in a Pod template
    case k8sContainerName = "k8s.container.name"
    /// The UID of the ReplicaSet
    case k8sReplicaSetUid = "k8s.replicaset.uid"
    /// The name of the ReplicaSet
    case k8sReplicaSetName = "k8s.replicaset.name"
    /// The UID of the StatefulSet
    case k8sStatefulSetUid = "k8s.statefulset.uid"
    /// The name of the StatefulSet
    case k8sStatefulSetName = "k8s.statefulset.name"
    /// The UID of the DaemonSet
    case k8sDaemonSetUid = "k8s.daemonset.uid"
    /// The name of the DaemonSet
    case k8sDaemonSetName = "k8s.daemonset.name"
    /// The UID of the Job
    case k8sJobUid = "k8s.job.uid"
    /// The name of the Job
    case k8sJobName = "k8s.job.name"
    /// The UID of the CronJob
    case k8sCronJobUid = "k8s.cronjob.uid"
    /// The name of the CronJob
    case k8sCronJobName = "k8s.cronjob.name"
    /// The name of the deployment.
    case k8sDeployment = "k8s.deployment.name"
    /// The UID of the Deployment
    case k8sDeploymentUid = "k8s.deployment.uid"
    
    /// The name of the web engine
    case webengineName = "webengine.name"
    /// The version of the web engine
    case webengineVersion = "webengine.version"
    /// Additional description of the web engine (e.g. detailed version and edition information).
    case webengineDescription = "webengine.description"
}

public func ==(left: ResourceConstants, right: String) -> Bool {
    return left.rawValue == right
}

public func ==(left: String, right: ResourceConstants) -> Bool {
    return left == right.rawValue
}
