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
    case serviceNamespace = "service.namespace";
    /// The string ID of the service instance. MUST be unique for each instance of the same
    case serviceInstance = "service.instance.id"
    /// The version string of the service API or implementation.
    case serviceVersion = "service.version"
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
    /// The name of the cluster that the pod is running in.
    case k8sCluster = "k8s.cluster.name"
    /// The name of the namespace that the pod is running in.
    case k8sNamespace = "k8s.namespace.name"
    /// The name of the pod.
    case k8sPod = "k8s.pod.name"
    /// The name of the deployment.
    case k8sDeployment = "k8s.deployment.name"
    /// Hostname of the host. It contains what the `hostname` command returns on the host machine.
    case hostHostname = "host.hostname"
    /// Unique host id. For Cloud this must be the instance_id assigned by the cloud provider.
    case hostId = "host.id"
    /// Name of the host. It may contain what `hostname` returns on Unix systems, the fully qualified, or a name specified by the user.
    case hostName = "host.name"
    /// Type of host. For Cloud this must be the machine type.
    case hostType = "host.type"
    /// Name of the VM image or OS install the host was instantiated from.
    case hostImageName = "host.image.name"
    /// VM image id. For Cloud, this value is from the provider.
    case hostImageId = "host.image.id"
    /// The version string of the VM image.
    case hostImageVersion = "host.image.version"
    /// Name of the cloud provider.
    case cloudProvider = "cloud.provider"
    /// The cloud account id used to identify different entities.
    case cloudAccount = "cloud.account.id"
    /// A specific geographical location where different entities can run.
    case cloudRegion = "cloud.region"
    /// Zones are a sub set of the region connected through low-latency links.
    case cloudZone = "cloud.zone"
}

public func ==(left: ResourceConstants, right: String) -> Bool {
    return left.rawValue == right
}

public func ==(left: String, right: ResourceConstants) -> Bool {
    return left == right.rawValue
}
