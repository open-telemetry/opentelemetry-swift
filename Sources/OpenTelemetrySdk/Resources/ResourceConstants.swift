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

enum ResourceConstants: String {
    case SERVICE_INSTANCE = "service.instance.id"
    /// The version string of the service API or implementation.
    case SERVICE_VERSION = "service.version"
    /// The name of the telemetry library.
    case LIBRARY_NAME = "library.name"
    /// The language of telemetry library and of the code instrumented with it.
    case LIBRARY_LANGUAGE = "library.language"
    /// The version string of the library.
    case LIBRARY_VERSION = "library.version"
    /// Container name.
    case CONTAINER_NAME = "container.name"
    /// Name of the image the container was built on.
    case CONTAINER_IMAGE_NAME = "container.image.name"
    /// Container image tag.
    case CONTAINER_IMAGE_TAG = "container.image.tag"
    /// The name of the cluster that the pod is running in.
    case K8S_CLUSTER = "k8s.cluster.name"
    /// The name of the namespace that the pod is running in.
    case K8S_NAMESPACE = "k8s.namespace.name"
    /// The name of the pod.
    case K8S_POD = "k8s.pod.name"
    /// The name of the deployment.
    case K8S_DEPLOYMENT = "k8s.deployment.name"
    /// Hostname of the host. It contains what the `hostname` command returns on the host machine.
    case HOST_HOSTNAME = "host.hostname"
    /// Unique host id. For Cloud this must be the instance_id assigned by the cloud provider.
    case HOST_ID = "host.id"
    /// Name of the host. It may contain what `hostname` returns on Unix systems, the fully qualified, or a name specified by the user.
    case HOST_NAME = "host.name"
    /// Type of host. For Cloud this must be the machine type.
    case HOST_TYPE = "host.type"
    /// Name of the VM image or OS install the host was instantiated from.
    case HOST_IMAGE_NAME = "host.image.name"
    /// VM image id. For Cloud, this value is from the provider.
    case HOST_IMAGE_ID = "host.image.id"
    /// The version string of the VM image.
    case HOST_IMAGE_VERSION = "host.image.version"
    /// Name of the cloud provider.
    case CLOUD_PROVIDER = "cloud.provider"
    /// The cloud account id used to identify different entities.
    case CLOUD_ACCOUNT = "cloud.account.id"
    /// A specific geographical location where different entities can run.
    case CLOUD_REGION = "cloud.region"
    /// Zones are a sub set of the region connected through low-latency links.
    case CLOUD_ZONE = "cloud.zone"
}
